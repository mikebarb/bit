class LessonsController < ApplicationController
  before_action :set_lesson, only: [:show, :edit, :update, :destroy, :move]

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

    # Never trust parameters from the scary internet, only allow the white list through.
    def lesson_params
      params.require(:lesson).permit( :slot_id, :comments, 
                                      :students_attributes => [:id, :pname],
                                      :roles_attributes => [:id, :student_id, :lesson_id, :comment, :_destroy],
                                      :tutors_attributes => [:id, :pname],
                                      :tutroles_attributes => [:id, :tutor_id, :lesson_id, :comment, :_destroy],
                                      :domchange => [:action, :ele_new_parent_id, :ele_old_parent_id, :move_ele_id, :element_type]
                                     )
    end
end