class LessonsController < ApplicationController
  before_action :set_lesson, only: [:show, :edit, :update, :destroy, :move]
  before_filter :authenticate_user!, :set_user_for_models
  after_filter :reset_user_for_models
  
  # GET /lessons
  # GET /lessons.json
  def index
    @lessons = Lesson.all
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

  # PATCH/PUT /lessonupdateskc.json
  # ajax updates skc = status comment (kind not valid for sessions)
  def lessonupdateskc
    @lesson = Lesson.find(params[:lesson_id])
    logger.debug "@lesson: " + @lesson.inspect
    flagupdate = false
    if params[:status]
      if @lesson.status != params[:status]
        @lesson.status = params[:status]
        flagupdate = true
      end
    end
    if params[:comments]
      if @lesson.comments != params[:comments]
        @lesson.comments = params[:comments]
        flagupdate = true
      end
    end
    respond_to do |format|
      if @lesson.save
        #format.html { redirect_to @student, notice: 'Student was successfully updated.' }
        format.json { render :show, status: :ok, location: @lesson }
      else
        logger.debug("errors.messages: " + @lesson.errors.messages.inspect)
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
      params.require(:lesson).permit( :slot_id, :comments, :status,
                                      :students_attributes => [:id, :pname],
                                      :roles_attributes => [:id, :student_id, :lesson_id, :comment, :_destroy],
                                      :tutors_attributes => [:id, :pname],
                                      :tutroles_attributes => [:id, :tutor_id, :lesson_id, :comment, :_destroy],
                                      :domchange => [:action, :ele_new_parent_id, :ele_old_parent_id,
                                                    :move_ele_id, :element_type, :status, :new_value]
                                     )
    end
end
