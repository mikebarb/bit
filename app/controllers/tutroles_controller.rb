class TutrolesController < ApplicationController
  before_action :set_tutrole, only: [:show, :edit, :update, :destroy]

  # GET /tutroles
  # GET /tutroles.json
  def index
    @tutroles = Tutrole.all
  end

  # GET /tutroles/1
  # GET /tutroles/1.json
  def show
  end

  # GET /tutroles/new
  def new
    @tutrole = Tutrole.new
  end

  # GET /tutroles/1/edit
  def edit
  end

  # POST /tutroles
  # POST /tutroles.json
  def create
    @tutrole = Tutrole.new(tutrole_params)

    respond_to do |format|
      if @tutrole.save
        format.html { redirect_to @tutrole, notice: 'Tutrole was successfully created.' }
        format.json { render :show, status: :created, location: @tutrole }
      else
        format.html { render :new }
        format.json { render json: @tutrole.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /removetutorfromlesson.json
  def removetutorfromlesson
    logger.debug("removetutorfromlesson")
    @tutrole = Tutrole.where(:tutor_id => params[:tutor_id], :lesson_id => params[:old_lesson_id]).first
    logger.debug("found tutrole: " + @tutrole.inspect)
    @tutrole1 = Tutrole.find(@tutrole.id)
    logger.debug("found tutrole1: " + @tutrole1.inspect)
    respond_to do |format|
      if @tutrole1.destroy
        #format.json { render :show, status: :removed, location: @tutrole1 }
        format.json { head :no_content }
      else
        logger.debug("errors.messages: " + @tutrole1.errors.messages.inspect)
        format.json { render json: @tutrole1.errors.full_messages, status: :unprocessable_entity }
      end
    end
  end


  # Copy a tutor from one lesson to another. Actional just a new tutrole entry with current
  # student attached to a new parent.
  # POST /tutorcopylesson.json
  def tutorcopylesson
    @tutrole = Tutrole.new(:tutor_id => params[:tutor_id], :lesson_id => params[:new_lesson_id])
    respond_to do |format|
      if @tutrole.save
        format.json { render :show, status: :created, location: @role }
      else
        logger.debug("errors.messages: " + @tutrole.errors.messages.inspect)
        format.json { render json: @tutrole.errors.full_messages, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tutormovelesson.json
  def tutormovelesson
    @tutrole = Tutrole.where(:tutor_id => params[:tutor_id], :lesson_id => params[:old_lesson_id]).first
    @tutrole.lesson_id = params[:new_lesson_id]
    respond_to do |format|
      if @tutrole.save
        #format.html { redirect_to @student, notice: 'Student was successfully updated.' }
        format.json { render :show, status: :ok, location: @tutrole }
      else
        logger.debug("errors.messages: " + @tutrole.errors.messages.inspect)
        format.json { render json: @tutrole.errors.messages, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tutorupdateskc.json
  # ajax updates skc = status kind comment
  def tutorupdateskc
    @tutrole = Tutrole.where(:tutor_id => params[:tutor_id], 
                             :lesson_id => params[:lesson_id]).first
    flagupdate = false
    if params[:status]
      if @tutrole.status != params[:status]
        @tutrole.status = params[:status]
        flagupdate = true
      end
    end
    if params[:kind]
      if @tutrole.kind != params[:kind]
        @tutrole.kind = params[:kind]
        flagupdate = true
      end
    end
    if params[:comment]
      if @tutrole.comment != params[:comment]
        @tutrole.comment = params[:comment]
        flagupdate = true
      end
    end
    respond_to do |format|
      if @tutrole.save
        #format.html { redirect_to @tutor, notice: 'Tutor was successfully updated.' }
        format.json { render :show, status: :ok, location: @tutrole }
      else
        logger.debug("errors.messages: " + @tutrole.errors.messages.inspect)
        format.json { render json: @tutrole.errors.messages, status: :unprocessable_entity }
      end
    end
  end


  # PATCH/PUT /tutroles/1
  # PATCH/PUT /tutroles/1.json
  def update
    respond_to do |format|
      if @tutrole.update(tutrole_params)
        format.html { redirect_to @tutrole, notice: 'Tutrole was successfully updated.' }
        format.html { redirect_to @tutrole, notice: 'Tutrole was successfully updated.' }
        format.json { render :show, status: :ok, location: @tutrole }
      else
        format.html { render :edit }
        format.json { render json: @tutrole.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tutroles/1
  # DELETE /tutroles/1.json
  def destroy
    @tutrole.destroy
    respond_to do |format|
      format.html { redirect_to tutroles_url, notice: 'Tutrole was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tutrole
      @tutrole = Tutrole.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def tutrole_params
      params.require(:tutrole).permit(:lesson_id, :tutor_id, :new_lesson_id,
                     :old_lesson_id, :status, :kind, :comment,
                     :domchange => [:action, :ele_new_parent_id, 
                                    :ele_old_parent_id, :move_ele_id, 
                                    :element_type, :new_value]
      )
    end
end
