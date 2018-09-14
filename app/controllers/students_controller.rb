class StudentsController < ApplicationController
  include Historyutilities
  before_action :set_student, only: [:show, :showsessions, :edit, :update, :destroy]
  before_filter :authenticate_user!, :set_user_for_models
  after_filter :reset_user_for_models

  # GET /students
  # GET /students.json
  def index
    @students = Student
    .order(:pname)
    .page(params[:page])
  end

  # GET /students/1
  # GET /students/1.json
  def show
  end
  
  # GET /students/history
  # GET /students/history.json
  def allhistory
    @students_history = Array.new
    students = Student.all.order("pname")
    students.each do |thisstudent|
      @students_history.push(student_history(thisstudent.id))
    end
  end

  # GET /students/history/1
  # GET /students/history/1.json
  def history
    @student_history =  student_history(params[:id])
  end

  # GET /students/change/1
  # GET /students/change/1.json
  def change
    @student_change =  student_change(params[:id])
    respond_to do |format|
      format.html
      format.json { render :change, status: :ok }
    end
  end


  
  # GET /studentsessions/1
  # GET /studentsessions/1.json
  def showsessions
    #@sessions = Student.sessions
    #logger.debug "student_controller - showsessions - " + @sessions.inspect
  end

  # GET /students/new
  def new
    @student = Student.new
  end

  # GET /students/1/edit
  def edit
  end

  # POST /students
  # POST /students.json
  def create
    @student = Student.new(student_params)

    respond_to do |format|
      if @student.save
        format.html { redirect_to @student, notice: 'Student was successfully created.' }
        format.json { render :show, status: :created, location: @student }
      else
        format.html { render :new }
        format.json { render json: @student.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /studentdetailupdateskc
  # POST /studentdetailupdateskc.json
  def studentdetailupdateskc
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
    if((result = /(s(\d+))$/.match(params[:domchange][:object_id])))
      student_dbId = result[2].to_i
      @domchange['object_type'] = 'student'
      @domchange['object_id_old'] = @domchange['object_id']
      @domchange['object_id'] = result[1]
    end

    @student = Student.find(student_dbId)
    flagupdate = false
    case @domchange['updatefield']
    when 'comment'
      if @student.comment != @domchange['updatevalue']
        @student.comment = @domchange['updatevalue']
        flagupdate = true
      end
    when 'status'
      if @student.status != @domchange['updatevalue']
        @student.status = @domchange['updatevalue']
        flagupdate = true
      end
    when 'study'
      if @student.study != @domchange['updatevalue']
        @student.study = @domchange['updatevalue']
        flagupdate = true
      end
    end
    respond_to do |format|
      if @student.save
        format.json { render json: @domchange, status: :ok }
        ActionCable.server.broadcast "calendar_channel", { json: @domchange }
      else
        logger.debug("errors.messages: " + @student.errors.messages.inspect)
        format.json { render json: @student.errors.messages, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /students/1
  # PATCH/PUT /students/1.json
  def update
    respond_to do |format|
      if @student.update(student_params)
        format.html { redirect_to @student, notice: 'Student was successfully updated.' }
        format.json { render :show, status: :ok, location: @student }
      else
        format.html { render :edit }
        format.json { render json: @student.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /students/1
  # DELETE /students/1.json
  def destroy
    if @student.destroy
      respond_to do |format|
        format.html { redirect_to students_url, notice: 'Student was successfully destroyed.' }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to students_url, 
          notice: "#{@student.errors.messages[:base].reduce { |memo, m| memo + m } }" +
                  " Student was NOT destroyed." 
        }
        format.json { render json: @student.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_student
      @student = Student.find(params[:id])
    end

    def set_user_for_models
      Thread.current[:current_user_id] = current_user.id
    end
    
    def reset_user_for_models
      Thread.current[:current_user_id] = nil
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def student_params
      params.require(:student).permit(:gname, :sname, :pname, :initials, :sex, :comment,
                                      :status, :kind, :year, :study, :email, :phone,
                                      :invcode, :daycode, :preferences)
    end
end
