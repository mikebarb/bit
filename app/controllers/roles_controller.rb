class RolesController < ApplicationController
  before_action :set_role, only: [:show, :edit, :update, :destroy]

  # GET /roles
  # GET /roles.json
  def index
    @roles = Role.all
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

 # POST /removestudentfromsession.json
  def removestudentfromsession
    logger.debug("removestudentfromsession")
    @role = Role.where(:student_id => params[:student_id], :session_id => params[:old_session_id]).first
    #logger.debug("found role: " + @role.inspect)
    #myid = @role.id
    #logger.debug("myroleid: " + myid.inspect)
    @role1 = Role.find(@role.id)
    logger.debug("@role1: " + @role1.inspect)
    @role1.destroy
    respond_to do |format|
      format.json { head :no_content }
      #format.json { render :show, status: :created, location: @role }
    end
  end

  # POST /studentcopysession.json
  def studentcopysession
    @role = Role.new(:student_id => params[:student_id],
                     :session_id => params[:new_session_id])
    logger.debug("new_role: " + @role.inspect)
    respond_to do |format|
      if @role.save
        #format.json { render :show, status: :created, location: @role }
        format.json { render json: :show, status: :created, location: @role }
      else
        logger.debug("errors.messages: " + @role.errors.messages.inspect)
        format.json { render json: @role.errors.full_messages, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /studentmovesession.json
  def studentmovesession
    @role = Role.where(:student_id => params[:student_id], :session_id => params[:old_session_id]).first
    @role.session_id = params[:new_session_id]
    logger.debug("after_role: " + @role.inspect)
    respond_to do |format|
      if @role.save
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

    # Never trust parameters from the scary internet, only allow the white list through.
    def role_params
      params.require(:role).permit(:session_id, :student_id, :new_sesson_id, :old_session_id,
        :domchange => [:action, :ele_new_parent_id, :ele_old_parent_id, :move_ele_id, :element_type]
      )
    end
end
