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
      else
        format.json { render json: @role.errors.messages, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /studentupdateskc.json
  # ajax updates skc = status kind comment
  def studentupdateskc
    @role = Role.where(:student_id => params[:student_id], 
                             :lesson_id => params[:lesson_id]).first
    flagupdate = false
    if params[:status]
      if @role.status != params[:status]
        @role.status = params[:status]
        flagupdate = true
      end
    end
    if params[:kind]
      if @role.kind != params[:kind]
        @role.kind = params[:kind]
        flagupdate = true
      end
    end
    if params[:comment]
      if @role.comment != params[:comment]
        @role.comment = params[:comment]
        flagupdate = true
      end
    end
    respond_to do |format|
      if @role.save
        logger.debug "studentupdateskc @role saved: " + @role.inspect
        ActionCable.server.broadcast("calendar_channel", message: [@role])

        #format.html { redirect_to @student, notice: 'Student was successfully updated.' }
        format.json { render :show, status: :ok, location: @role }
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