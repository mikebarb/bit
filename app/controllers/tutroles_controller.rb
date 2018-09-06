class TutrolesController < ApplicationController
  before_action :set_tutrole, only: [:show, :edit, :update, :destroy]
  before_filter :authenticate_user!, :set_user_for_models
  after_filter :reset_user_for_models

  # GET /tutroles
  # GET /tutroles.json
  def index
    @tutroles = Tutrole
                .order(:id)
                .page(params[:page])
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
    #@tutrole1 = Tutrole.find(@tutrole.id)
    #logger.debug("found tutrole1: " + @tutrole1.inspect)
    respond_to do |format|
      #if @tutrole1.destroy
      if @tutrole.destroy
        #format.json { render :show, status: :removed, location: @tutrole1 }
        format.json { head :no_content }
      else
        logger.debug("errors.messages: " + @tutrole.errors.messages.inspect)
        format.json { render json: @tutrole.errors.full_messages, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tutormovecopylesson.json
  # this is the ** updated ** function to replace
  # tutormovelesson and tutorcopylesson.
  def tutormovecopylesson
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
    if((result = /^([A-Z]+\d+n(\d+))t(\d+)$/.match(params[:domchange][:object_id])))
      tutor_id = result[3]
      old_lesson_id = result[2]
      @domchange['object_type'] = 'tutor'
      @domchange['from'] = result[1]
    elsif((result = /^t(\d+)/.match(params[:domchange][:object_id])))  #index area
      tutor_id = result[1]
      @domchange['object_type'] = 'tutor'
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

      @tutrole = Tutrole
                  .includes(:tutor)
                  .where(:tutor_id => tutor_id, :lesson_id => old_lesson_id)
                  .first
      @tutrole.lesson_id = new_lesson_id
    else    # copy
      @tutrole = Tutrole.new(:tutor_id => tutor_id, :lesson_id => new_lesson_id)
      # copy relevant info from old tutrole (status & kind)
      if old_lesson_id
        @tutrole_from = Tutrole.where(:tutor_id  => tutor_id,
                                      :lesson_id => old_lesson_id).first
        @tutrole.status = @tutrole_from.status
        @tutrole.kind   = @tutrole_from.kind
      end
    end


    @domchange['html_partial'] = render_to_string("calendar/_schedule_tutor_update.html", :formats => [:html], :layout => false,
                                    :locals => {:thistutrole => @tutrole, 
                                                :slot => new_slot_id, 
                                                :lesson => new_lesson_id
                                               })
    
    # the object_id will now change (for both move and copy as the inbuild
    # lesson number will change.
    @domchange['object_id_old'] = @domchange['object_id']
    @domchange['object_id'] = new_slot_id + "n" + new_lesson_id.to_s.rjust(@sf, "0") +
                    "t" + tutor_id.to_s.rjust(@sf, "0")
            
    # want to hold the name for sorting purposes in the DOM display
    @domchange['name'] = @tutrole.tutor.pname
    
    respond_to do |format|
      if @tutrole.save
        format.json { render json: @domchange, status: :ok }
      else
        format.json { render json: @tutrole.errors.messages, status: :unprocessable_entity }
      end
    end
  end

=begin
  # Copy a tutor from one lesson to another. Actional just a new tutrole entry with current
  # student attached to a new parent.
  # POST /tutorcopylesson.json
  def tutorcopylesson
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    byebug
    result = /^[A-Z]+\d+n(\d+)t(\d+)$/.match(params[:domchange][:object_id])
    if result 
      tutor_id = result[2]
      old_lesson_id = result[1]
      @domchange['object_type'] = 'tutor'
    end
    result = /^[A-Z]+\d+n(\d+)/.match(params[:domchange][:to])
    if result 
      new_lesson_id = result[1]
    end
    logger.debug "tutor_id     : " + tutor_id.inspect
    logger.debug "old_esoon_id : " + old_lesson_id.inspect
    logger.debug "new_lesson_id: " + new_lesson_id.inspect

    @tutrole = Tutrole.new(:tutor_id => tutor_id, :lesson_id => new_lesson_id)
    # copy relevant info from old tutrole (status & kind)
    if old_lesson_id
      @tutrole_from = Tutrole.where(:tutor_id  => tutor_id,
                                    :lesson_id => old_lesson_id).first
      @tutrole.status = @tutrole_from.status
      @tutrole.kind   = @tutrole_from.kind
    end
    
    #@tutrole = Tutrole.new(:tutor_id => params[:tutor_id], :lesson_id => params[:new_lesson_id])
    #if params[:old_lesson_id]
    #  @tutrole_from = Tutrole.where(:tutor_id => params[:tutor_id],
    #                          :lesson_id => params[:old_lesson_id]).first
    #  @tutrole.status = @tutrole_from.status
    #  @tutrole.kind   = @tutrole_from.kind
    #end
    respond_to do |format|
      if @tutrole.save
        #format.json { render :show, status: :created, location: @role }
        format.json { render :show, status: :created }
      else
        logger.debug("errors.messages: " + @tutrole.errors.messages.inspect)
        format.json { render json: @tutrole.errors.full_messages, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tutormovelesson.json
  def tutormovelesson
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    
    # from / source
    result = /^([A-Z]+\d+n(\d+))t(\d+)$/.match(params[:domchange][:object_id])
    if result 
      tutor_id = result[3]
      old_lesson_id = result[2]
      @domchange['object_type'] = 'tutor'
      @domchange['from'] = result[1]
    end
    
    # to / destination
    result = /^(([A-Z]+\d+)n(\d+))/.match(params[:domchange][:to])
    if result 
      new_lesson_id = result[3]
      new_slot_id = result[2]
      @domchange['to'] = result[1]
    end

    #@tutrole = Tutrole.where(:tutor_id => tutor_id, :lesson_id => old_lesson_id).first
    @tutrole = Tutrole
                .includes(:tutor)
                .where(:tutor_id => tutor_id, :lesson_id => old_lesson_id)
                .first
    logger.debug "read    @tutrole: " + @tutrole.inspect

    @tutrole.lesson_id = new_lesson_id
    logger.debug "updated @tutrole: " + @tutrole.inspect
    
    html_partial = render_to_string("calendar/_schedule_tutor_update.html", :formats => [:html], :layout => false,
                                    :locals => {:thistutrole => @tutrole, 
                                                :slot => new_slot_id, 
                                                :lesson => new_lesson_id
                                               })
    
    @domchange['html_partial'] = html_partial

    ## render partial: "schedule_tutor", 
    ## locals: {tutor: tutor, thistutrole: thistutrole, slot: slot, lesson: lesson}

    # the object_id will now change (for both move and copy as the inbuild
    # lesson number will change.
    #<%= slot + "n" + lesson.to_s.rjust(@sf, "0") + "t" + tutor.id.to_s.rjust(@sf, "0") %>
    #byebug
    @domchange['object_id_old'] = @domchange['object_id']
    @domchange['object_id'] = new_slot_id + "n" + new_lesson_id.to_s.rjust(@sf, "0") +
                    "t" + tutor_id.to_s.rjust(@sf, "0")
            
    # want to hold the name for sorting purposes in the DOM display
    @domchange['name'] = @tutrole.tutor.pname
    
    #logger.debug "@domchange: " + @domchange.inspect
    #byebug
                    
    #@tutrole = Tutrole.where(:tutor_id => params[:tutor_id], :lesson_id => params[:old_lesson_id]).first
    #@tutrole.lesson_id = params[:new_lesson_id]
    respond_to do |format|
      if @tutrole.save
        #format.html { redirect_to @student, notice: 'Student was successfully updated.' }
        ###format.json { render :show, status: :ok, location: @tutrole }
        #format.json { render :domchange, status: :ok, location: @domchange }
        format.json { render json: @domchange, status: :ok }
      else
        logger.debug("errors.messages: " + @tutrole.errors.messages.inspect)
        format.json { render json: @tutrole.errors.messages, status: :unprocessable_entity }
      end
    end
  end
=end

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
    #Thread.current[:current_user_id] = current_user.id
    @updateValues = "test"
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
    
    def set_user_for_models
      Thread.current[:current_user_id] = current_user.id
    end
    
    def reset_user_for_models
      Thread.current[:current_user_id] = nil
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
