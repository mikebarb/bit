class SessionsController < ApplicationController
  before_action :set_session, only: [:show, :edit, :update, :destroy, :move]

  # GET /sessions
  # GET /sessions.json
  def index
    @sessions = Session.all
  end

  # GET /sessions/1
  # GET /sessions/1.json
  def show
  end

  # GET /sessions/new
  def new
    @session = Session.new
    @student = Student.new
  end

  # GET /sessions/1/edit
  def edit
    @testStudents = Student.all
    logger.debug "testStudents: " + @testStudents.inspect
    @testTutors = Tutor.all
    logger.debug "testTutors: " + @testTutors.inspect
  end

  # GET /sessions/1/move
  def move
  end

  # POST /sessions
  # POST /sessions.json
  def create
    @session = Session.new(session_params)
    logger.debug "session created - " + @session.inspect

    respond_to do |format|
      if @session.save
        format.html { redirect_to @session, notice: 'Session was successfully created.' }
        format.js {}
        format.json { render :show, status: :created, location: @session }
      else
        format.html { render :new }
        format.js {}
        format.json { render json: @session.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /sessions/1
  # PATCH/PUT /sessions/1.json
  def update
    respond_to do |format|
      logger.debug "session_params: " + session_params.inspect
      
      if @session.update(session_params)
        format.html { redirect_to @session, notice: 'Session was successfully updated.' }
        format.json { render :show, status: :ok, location: @session }
      else
        format.html { render :edit }
        format.json { render json: @session.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sessions/1
  # DELETE /sessions/1.json
  def destroy
    if @session.destroy
      logger.debug "Session destroyed"
      respond_to do |format|
        format.html { redirect_to sessions_url, notice: 'Session was successfully destroyed.' }
        #format.json { head :no_content }
        format.json { render :show, status: :ok}
      end
    else
      logger.debug "Errors during destroy"
      logger.debug @session.errors.inspect
      respond_to do |format|
        format.html { redirect_to sessions_url, notice: 'Session was NOT destroy.' }
        format.json { render json: @session.errors, status: :unprocessable_entity  }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_session
      @session = Session.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def session_params
      params.require(:session).permit( :slot_id, :comments, 
                                      :students_attributes => [:id, :pname],
                                      :roles_attributes => [:id, :student_id, :session_id, :comment, :_destroy],
                                      :tutors_attributes => [:id, :pname],
                                      :tutroles_attributes => [:id, :tutor_id, :session_id, :comment, :_destroy],
                                      :domchange => [:action, :ele_new_parent_id, :ele_old_parent_id, :move_ele_id, :element_type]
                                     )
    end
end
