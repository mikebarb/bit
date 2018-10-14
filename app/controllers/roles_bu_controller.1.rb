class RolesController < ApplicationController
  before_action :set_role, only: [:show, :edit, :update, :destroy]
  before_filter :authenticate_user!, :set_user_for_models
  after_filter :reset_user_for_models

  # GET /roles
  # GET /roles.json
  def index
    @roles = Role
             .order(:id)
             .page(params[:page])
  end

  # GET /roles/1
  # GET /roles/1.json
  def show
  end

  # GET /roles/new
  def new
    @role = Role.new
  end

  # GET /roles/1/edit
  def edit
  end



  # POST /roles
  # POST /roles.json
  def create
    @role = Role.new(role_params)

    respond_to do |format|
      if @role.save
        format.html { redirect_to @role, notice: 'Role was successfully created.' }
        format.json { render :show, status: :created, location: @role }
      else
        format.html { render :new }
        format.json { render json: @role.errors.full_messages, status: :unprocessable_entity }
      end
    end
  end

 # POST /removestudentfromlesson.json
  def removestudentfromlesson
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    # need to ensure object passed is just the student dom id 
    result = /^(([A-Z]+\d+)n(\d+)s(\d+))$/.match(@domchange['object_id'])
    if result
      @domchange['object_id'] = result[1]  # student_dom_id where lesson is to be placed
      @domchange['object_type'] = 'student'
      student_id = result[4]
      lesson_id = result[3]
      @role = Role.where(:student_id => student_id, :lesson_id => lesson_id).first
    end
    if @role.destroy
      respond_to do |format|
        format.json { render json: @domchange, status: :ok }
        ActionCable.server.broadcast "calendar_channel", { json: @domchange }
      end
    else
      respond_to do |format|
        format.json { render json: @lesson.errors, status: :unprocessable_entity  }
      end
    end
  end

  # PATCH/PUT /studentmovecopylesson.json
  # this is the ** updated ** function to replace
  # studentmovelesson and studentcopylesson.
  def studentmovecopylesson
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    
    # from / source
    # need to check if is from index area or schedule area
    # identified by the id
    # id = t11111     ->  index
    # id = GUN2018... -> schedule
    if((result = /^([A-Z]+\d+n(\d+))s(\d+)$/.match(params[:domchange][:object_id])))
      student_id = result[3]
      old_lesson_id = result[2]
      @domchange['object_type'] = 'student'
      @domchange['from'] = result[1]
    elsif((result = /^s(\d+)/.match(params[:domchange][:object_id])))  #index area
      student_id = result[1]
      @domchange['object_type'] = 'student'
      @domchange['action'] = 'copy'    # ONLY a copy allowed from index area.
    else
      return
    end
    logger.debug "@domchange: " + @domchange.inspect
    
    # to / destination
    result = /^(([A-Z]+\d+)n(\d+))/.match(params[:domchange][:to])
    if result 
      new_lesson_id = result[3]
      new_slot_id = result[2]
      @domchange['to'] = result[1]
    end

    if( @domchange['action'] == 'move')

      @role = Role
                  .includes(:student)
                  .where(:student_id => student_id, :lesson_id => old_lesson_id)
                  .first
      @role.lesson_id = new_lesson_id
    else    # copy
      @role = Role.new(:student_id => student_id, :lesson_id => new_lesson_id)
      # copy relevant info from old role (status & kind)
      if old_lesson_id
        @role_from = Role.where(:student_id  => student_id,
                                      :lesson_id => old_lesson_id).first
        @role.status = @role_from.status
        @role.kind   = @role_from.kind
      end
    end

    @domchange['html_partial'] = render_to_string("calendar/_schedule_student.html",
                                    :formats => [:html], :layout => false,
                                    :locals => {:student => @role.student, 
                                                :thisrole => @role, 
                                                :slot => new_slot_id, 
                                                :lesson => new_lesson_id
                                               })
    # the object_id will now change (for both move and copy as the inbuild
    # lesson number will change.
    @domchange['object_id_old'] = @domchange['object_id']
    @domchange['object_id'] = new_slot_id + "n" + new_lesson_id.to_s.rjust(@sf, "0") +
                    "t" + student_id.to_s.rjust(@sf, "0")
            
    # want to hold the name for sorting purposes in the DOM display
    @domchange['name'] = @role.student.pname
    
    respond_to do |format|
      if @role.save
        format.json { render json: @domchange, status: :ok }
        ActionCable.server.broadcast "calendar_channel", { json: @domchange }
      else
        format.json { render json: @role.errors.messages, status: :unprocessable_entity }
      end
    end
  end


  # PATCH/PUT /studentupdateskc.json
  # ajax updates skc = status kind comment
  def studentupdateskc
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end

    # from / source
    # need to check if is from index area or schedule area
    # identified by the id
    # id = t11111     ->  index
    # id = GUN2018... -> schedule
    if((result = /^(([A-Z]+\d+)n(\d+))s(\d+)$/.match(params[:domchange][:object_id])))
      slot_id = result[2]
      student_dbId = result[4].to_i
      lesson_dbId = result[3].to_i
      @domchange['object_type'] = 'student'
      @domchange['from'] = result[1]
    end

    @role = Role  .includes(:student)
                  .where(:student_id => student_dbId, :lesson_id => lesson_dbId)
                  .first

    flagupdate = false
    case @domchange['updatefield']
    when 'status'
      if @role.status != @domchange['updatevalue']
        @role.status = @domchange['updatevalue']
        flagupdate = true
      end
    when 'kind'
      if @role.kind != @domchange['updatevalue']
        @role.kind = @domchange['updatevalue']
        flagupdate = true
      end
    when 'comment'
      if @role.comment != @domchange['updatevalue']
        @role.comment = @domchange['updatevalue']
        flagupdate = true
      end
    end
    
    @domchange['html_partial'] = render_to_string("calendar/_schedule_student.html",
                                :formats => [:html], :layout => false,
                                :locals => {:student => @role.student, 
                                            :thisrole => @role, 
                                            :slot => slot_id, 
                                            :lesson => lesson_dbId
                                           })

    #Thread.current[:current_user_id] = current_user.id
    @updateValues = "test"
    

    #Process if student/lesson status is set to 'away'
    if @role.status_changed? && @role.status == 'away'
      action_to_away_controller(@role)
    end
    
    respond_to do |format|
      if @role.save
        #format.json { render :show, status: :ok, location: @role }
        format.json { render json: @domchange, status: :ok }
        ActionCable.server.broadcast "calendar_channel", { json: @domchange }
      else
        logger.debug("errors.messages: " + @role.errors.messages.inspect)
        format.json { render json: @role.errors.messages, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /roles/1
  # PATCH/PUT /roles/1.json
  def update
    respond_to do |format|
      if @role.update(role_params)
        format.html { redirect_to @role, notice: 'Role was successfully updated.' }
        format.json { render :show, status: :ok, location: @role }
      else
        format.html { render :edit }
        format.json { render json: @role.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /roles/1
  # DELETE /roles/1.json
  def destroy
    @role.destroy
    respond_to do |format|
      format.html { redirect_to roles_url, notice: 'Role was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
  def action_to_away_controller(thisrole)
    logger.debug("+++++++++++++++++++role status has changed" )
    thisrole_lesson = Lesson.includes(:slot).find(thisrole.lesson_id)
    #new_slot_time = @self_lesson.slot.datetime
    #new_slot_location = @self_lesson.slot.location
    slot_dom_id_base  = thisrole_lesson.slot.location[0,3].upcase + 
                           thisrole_lesson.slot.timeslot.strftime("%Y%m%d%H%M")            
    slot_dom_id = slot_dom_id_base + 'l' + thisrole_lesson.slot.id.to_s.rjust(@sf, "0") 
    @global_lessons = Lesson.where(slot_id: thisrole_lesson.slot_id, status: 'global')
    unless(@global_lesson = Lesson.where(slot_id: thisrole_lesson.slot_id, status: 'global').first)
      # No Global Lesson present - so need to create one.
      @global_lesson = Lesson.new(slot_id: thisrole_lesson.slot_id, status: 'global')
      if @global_lesson.save
        # {"action"=>"addLesson", "object_id"=>"GUN201805281530n29174",
        #  "object_type"=>"lesson", "status"=>"flexible"}
        #byebug
        
        @global_lesson_domchange = {
          'action' => 'addLesson',
          'object_id' => slot_dom_id_base + 'n' + @global_lesson.id.to_s.rjust(@sf, "0"),
          "object_type"=>"lesson", 
          "status"=>"global",
          'to' => slot_dom_id
        }
        
        #byebug
  
        @global_lesson_domchange['html_partial'] = render_to_string("calendar/_schedule_lesson_ajax.html", 
                                    :formats => [:html], :layout => false,
                                    :locals => {:slot => slot_dom_id_base,
                                                :lesson => @global_lesson,
                                                :thistutroles => [],
                                                :thisroles => []
                                               })
  
        
        ActionCable.server.broadcast "calendar_channel", { json: @global_lesson_domchange }
        #byebug
      else
        return      # if no global, then no point continuing.
      end
    end
    #byebug
    @copied_role = @role.dup
    @copied_role.lesson_id = @global_lesson.id
    #@copied_role.copied = @role.id               # remember where copied from.
    if @copied_role.save
        @global_lesson_domchange = {
          'action' => 'addStudent',
          'object_id' => slot_dom_id_base + 'n' + @global_lesson.id.to_s.rjust(@sf, "0"),
          "object_type"=>"lesson", 
          "status"=>"global",
          'to' => slot_dom_id
        }
        
        #byebug
  
        @global_lesson_domchange['html_partial'] = render_to_string("calendar/_schedule_lesson_ajax.html", 
                                    :formats => [:html], :layout => false,
                                    :locals => {:slot => slot_dom_id_base,
                                                :lesson => @global_lesson,
                                                :thistutroles => [],
                                                :thisroles => []
                                               })
  
        
        ActionCable.server.broadcast "calendar_channel", { json: @global_lesson_domchange }
        #byebug
    
    
    
    
    
    end
    
  end


    # Use callbacks to share common setup or constraints between actions.
    def set_role
      @role = Role.find(params[:id])
    end

    def set_user_for_models
      Thread.current[:current_user_id] = current_user.id
    end
    
    def reset_user_for_models
      Thread.current[:current_user_id] = nil
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def role_params
      params.require(:role).permit(:lesson_id, :student_id, :new_sesson_id, :old_lesson_id, :status, :kind,
        :domchange => [:action, :ele_new_parent_id, :ele_old_parent_id, :move_ele_id, :element_type]
      )
    end
end