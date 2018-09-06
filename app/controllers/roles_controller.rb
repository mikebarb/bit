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



  # DELETE /roles/1
  # DELETE /roles/1.json
  ###def destroy
  ###  @role.destroy
  ###  respond_to do |format|
  ###    format.html { redirect_to roles_url, notice: 'Role was successfully destroyed.' }
  ###    format.json { head :no_content }
  ###  end
  ###end
  ###    @role = Role.find(params[:id])

 # POST /removestudentfromlesson.json
  def removestudentfromlesson
    @role = Role.where(:student_id => params[:student_id], :lesson_id => params[:old_lesson_id]).first
    #logger.debug("found role: " + @role.inspect)
    #myid = @role.id
    #logger.debug("myroleid: " + myid.inspect)
    #@role1 = Role.find(@role.id)
    #logger.debug("@role1: " + @role1.inspect)
    respond_to do |format|
      #if @role1.destroy
      if @role.destroy
        format.json { head :no_content }
        #format.json { render :show, status: :created, location: @role }
      else
        logger.debug("errors.messages: " + @role.errors.messages.inspect)
        format.json { render json: @role.errors.full_messages, status: :unprocessable_entity }
      end
    end
  end

  # POST /studentcopylesson.json
  def studentcopylesson
    #byebug
    result = /^[A-Z]+\d+n(\d+)s(\d+)$/.match(params[:domchange][:object_id])
    if result 
      student_id = result[2]
      old_lesson_id = result[1]
      @domchange['object_type'] = 'student'
    end
    result = /^[A-Z]+\d+n(\d+)/.match(params[:domchange][:to])
    if result 
      new_lesson_id = result[1]
    end
    logger.debug "student_id     : " + student_id.inspect
    logger.debug "old_esoon_id : " + old_lesson_id.inspect
    logger.debug "new_lesson_id: " + new_lesson_id.inspect

    @role = Role.new(:student_id => student_id, :lesson_id => new_lesson_id)
    # copy relevant info from old tutrole (status & kind)
    if old_lesson_id
      @role_from = Role.where(:student_id  => student_id,
                                    :lesson_id => old_lesson_id).first
      @role.status = @role_from.status
      @role.kind   = @role_from.kind
    end
    
    
    #@role = Role.new(:student_id => params[:student_id],
    #                 :lesson_id => params[:new_lesson_id])
    #if params[:old_lesson_id]
    #  @role_from = Role.where(:student_id => params[:student_id],
    #                          :lesson_id => params[:old_lesson_id]).first
    #  @role.status = @role_from.status
    #  @role.kind   = @role_from.kind
    #end
    logger.debug("new_role: " + @role.inspect)
    respond_to do |format|
      if @role.save
        format.json { render :show, status: :created, location: @role }
      else
        logger.debug("errors.messages: " + @role.errors.messages.inspect)
        format.json { render json: @role.errors.full_messages, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /studentmovelesson.json
  def studentmovelesson
    #byebug
    result = /^[A-Z]+\d+n(\d+)s(\d+)$/.match(params[:domchange][:object_id])
    if result 
      student_id = result[2]
      old_lesson_id = result[1]
      @domchange['object_type'] = 'student'
    end
    result = /^[A-Z]+\d+n(\d+)/.match(params[:domchange][:to])
    if result 
      new_lesson_id = result[1]
    end
    logger.debug "student_id     : " + student_id.inspect
    logger.debug "old_lesson_id : " + old_lesson_id.inspect
    logger.debug "new_lesson_id: " + new_lesson_id.inspect
    @role = Role.where(:student_id => student_id, :lesson_id => old_lesson_id).first
    logger.debug "read    @role: " + @role.inspect
    @role.lesson_id = new_lesson_id
    logger.debug "updated @role: " + @role.inspect
    #byebug
    
    #@role = Role.where(:student_id => params[:student_id], :lesson_id => params[:old_lesson_id]).first
    #@role.lesson_id = params[:new_lesson_id]
    respond_to do |format|
      if @role.save
        format.json { render :show, status: :ok, location: @role }
      else
        logger.debug("errors.messages: " + @role.errors.messages.inspect)
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