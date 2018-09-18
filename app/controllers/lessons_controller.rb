class LessonsController < ApplicationController
  before_action :set_lesson, only: [:show, :edit, :update, :destroy, :move]
  before_filter :authenticate_user!, :set_user_for_models
  after_filter :reset_user_for_models
  
  # GET /lessons
  # GET /lessons.json
  def index
    @lessons = Lesson
               .order(id: :desc)
               .page(params[:page])
               .includes(:tutors, :students, :slot)
  end

  # GET /lessons/1
  # GET /lessons/1.json
  def show
  end

  # GET /lessons/new
  def new
    @lesson = Lesson.new
    @student = Student.new
  end

  # GET /lessons/1/edit
  def edit
    @testStudents = Student.all
    logger.debug "testStudents: " + @testStudents.inspect
    @testTutors = Tutor.all
    logger.debug "testTutors: " + @testTutors.inspect
  end

  # GET /lessons/1/move
  def move
  end

  # POST /lessons
  # POST /lessons.json
  def create
    @lesson = Lesson.new(lesson_params)
    logger.debug "lesson created - " + @lesson.inspect
    # default to standard lesson
    #@lesson.status = "standard"
    respond_to do |format|
      if @lesson.save
        format.html { redirect_to @lesson, notice: 'Lesson was successfully created.' }
        format.js {}
        format.json { render :show, status: :created, location: @lesson }
      else
        format.html { render :new }
        format.js {}
        format.json { render json: @lesson.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /lessonremove.json
  def lessonremove
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    @domchange['object_type'] = 'lesson'
    # need to ensure object passed is just the lesson dom id 
    result = /^(([A-Z]+\d+)n(\d+))/.match(@domchange['object_id'])
    if result
      @domchange['object_id'] = result[1]  # slot_dom_id where lesson is to be placed
      @domchange['object_type'] = 'session'
      @lesson = Lesson.find(result[3])
    end
    if @lesson.destroy
      logger.debug "Lesson destroyed"
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

  # POST /lessonadd.json
  def lessonadd
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    
    @domchange['object_type'] = 'lesson'
    # object passed which determines the slot the new session is to be placed in.
    result = /^(([A-Z]+)(\d{4})(\d{2})(\d{2})(\d{2})(\d{2}))/.match(@domchange['object_id'])
    if result
      @domchange['to'] = slot_id_basepart = result[1]  # slot_dom_id where lesson is to be placed
      slot_location = result[2]
      slot_time = DateTime.new(result[3].to_i, result[4].to_i, result[5].to_i,
                                   result[6].to_i, result[7].to_i)
      # need to find the slot record to match.
      @slot = Slot.where("timeslot = :thisdate AND
                            location like :thislocation", 
                            {thisdate: slot_time,
                             thislocation: slot_location + '%'
                            }).first  
    end
    @domchange['to'] = slot_id_basepart + 'l' + @slot.id.to_s.rjust(@sf, "0")
    @lesson = Lesson.new
    @lesson.slot_id = @slot.id
    @lesson.status = @domchange['status']
    respond_to do |format|
      if @lesson.save
        @domchange['object_id'] = slot_id_basepart + 'n' + @lesson.id.to_s.rjust(@sf, "0")
        
        #@domchange['html_partial'] = render_to_string("calendar/_schedule_lesson_update.html", 
        #@domchange['html_partial'] = render_to_string("calendar/_schedule_lesson.html", 
        @domchange['html_partial'] = render_to_string("calendar/_schedule_lesson_ajax.html", 
                                    :formats => [:html], :layout => false,
                                    :locals => {:slot => slot_id_basepart,
                                                :lesson => @lesson,
                                                :thistutroles => [],
                                                :thisroles => []
                                               })

        format.json { render json: @domchange, status: :ok }
        ActionCable.server.broadcast "calendar_channel", { json: @domchange }
      else
        format.json { render json: @lesson.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /lessonupdateskc.json
  # ajax updates skc = status comment (kind not valid for sessions)
  def lessonupdateskc
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end

    # from / source
    if((result = /^([A-Z]+\d+)n(\d+)$/.match(params[:domchange][:object_id])))
      #slot_id = result[1]
      lesson_dbId   = result[2].to_i
      @domchange['object_type'] = 'lesson'
      @domchange['from'] = result[1]    # old_slot_dom_id
    end
    logger.debug "@domchange: " + @domchange.inspect

    @lesson = Lesson.find(lesson_dbId)
    logger.debug "@lesson: " + @lesson.inspect

    flagupdate = false
    case @domchange['updatefield']
    when 'status'
      if @lesson.status != @domchange['updatevalue']
        @lesson.status = @domchange['updatevalue']
        flagupdate = true
      end
    when 'comments'
      if @lesson.comments != @domchange['updatevalue']
        @lesson.comments = @domchange['updatevalue']
        flagupdate = true
      end
    end

    respond_to do |format|
      if @lesson.save
        #format.html { redirect_to @student, notice: 'Student was successfully updated.' }
        #format.json { render :show, status: :ok, location: @lesson }
        format.json { render json: @domchange, status: :ok }
        ActionCable.server.broadcast "calendar_channel", { json: @domchange }
      else
        logger.debug("errors.messages: " + @lesson.errors.messages.inspect)
        format.json { render json: @lesson.errors.messages, status: :unprocessable_entity }
      end
    end
  end  
  
  
  # POST /lessonmoveslot.json
  def lessonmoveslot
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    
    # from / source
    if((result = /^([A-Z]+\d+)n(\d+)$/.match(params[:domchange][:object_id])))
      lesson_id   = result[2]
      @domchange['object_type'] = 'lesson'
      @domchange['from'] = result[1]    # old_slot_dom_id
    end

    # to / destination
    result = /^(([A-Z]+)(\d{4})(\d{2})(\d{2})(\d{2})(\d{2}))/.match(params[:domchange][:to])
    if result 
      @domchange['to'] = new_slot_id = result[1]      # slot_dom_id
      new_slot_location = result[2]
      new_slot_time = DateTime.new(result[3].to_i, result[4].to_i, result[5].to_i,
                                   result[6].to_i, result[7].to_i)
      # need to find the slot record to match.
      @slot = Slot.where("timeslot = :thisdate AND
                            location like :thislocation", 
                            {thisdate: new_slot_time,
                             thislocation: new_slot_location + '%'
                            }).first  
      @domchange['to'] = @domchange['to'] + 'l' + @slot.id.to_s.rjust(@sf, "0")
    end
    @lesson = Lesson.find(lesson_id)
    @lesson.slot_id = @slot.id
    #### saved later #### @lesson.save

    # the object_id will now change (for both move and copy as the inbuild
    # slot number will change.
    @domchange['object_id_old'] = @domchange['object_id']
    @domchange['object_id'] = new_slot_id + "n" + lesson_id.to_s.rjust(@sf, "0")

    
    # Need to generate the html partial for this session.
    @tutroles = Tutrole
                .includes(:tutor)
                .where(:lesson_id => lesson_id)
                .order('tutors.pname')

    @roles    = Role
                .includes(:student)
                .where(:lesson_id => lesson_id)
                .order('students.pname')
    
    # parameters used for sorting lessons on the page.
    @domchange['status'] = @lesson.status
    #not needed- extracted in js# @domchange['name'] = @tutroles.first.tutor.pname

    #@domchange['html_partial'] = render_to_string("calendar/_schedule_lesson_update.html", 
    @domchange['html_partial'] = render_to_string("calendar/_schedule_lesson_ajax.html", 
                                    :formats => [:html], :layout => false,
                                    :locals => {:slot => new_slot_id,
                                                :lesson => @lesson,
                                                :thistutroles => @tutroles,
                                                :thisroles => @roles
                                               })

    respond_to do |format|
      if @lesson.save
        format.json { render json: @domchange, status: :ok }
        ActionCable.server.broadcast "calendar_channel", { json: @domchange }
      else
        format.json { render json: @lesson.errors.messages, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /lessons/1
  # PATCH/PUT /lessons/1.json
  def update
    respond_to do |format|
      logger.debug "lesson_params: " + lesson_params.inspect
      
      if @lesson.update(lesson_params)
        format.html { redirect_to @lesson, notice: 'Lesson was successfully updated.' }
        format.json { render :show, status: :ok, location: @lesson }
      else
        format.html { render :edit }
        format.json { render json: @lesson.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /lessons/1
  # DELETE /lessons/1.json
  def destroy
    if @lesson.destroy
      logger.debug "Lesson destroyed"
      respond_to do |format|
        format.html { redirect_to lessons_url, notice: 'Lesson was successfully destroyed.' }
        #format.json { head :no_content }
        format.json { render :show, status: :ok}
      end
    else
      logger.debug "Errors during destroy"
      logger.debug @lesson.errors.inspect
      respond_to do |format|
        format.html { redirect_to lessons_url, notice: 'Lession was NOT destroyed.' }
        format.json { render json: @lesson.errors, status: :unprocessable_entity  }
      end
    end
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_lesson
      @lesson = Lesson.find(params[:id])
    end
    
    def set_user_for_models
      Thread.current[:current_user_id] = current_user.id
    end
    
    def reset_user_for_models
      Thread.current[:current_user_id] = nil
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def lesson_params
      params.require(:lesson).permit( :slot_id, :comments, :status, :page,
                                      :students_attributes => [:id, :pname],
                                      :roles_attributes => [:id, :student_id, :lesson_id, :comment, :_destroy],
                                      :tutors_attributes => [:id, :pname],
                                      :tutroles_attributes => [:id, :tutor_id, :lesson_id, :comment, :_destroy],
                                      :domchange => [:action, :ele_new_parent_id, :ele_old_parent_id,
                                                    :move_ele_id, :element_type, :status, :new_value]
                                     )
    end
end
