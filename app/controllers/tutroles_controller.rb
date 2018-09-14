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
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    # need to ensure object passed is just the student dom id 
    result = /^(([A-Z]+\d+)n(\d+)t(\d+))$/.match(@domchange['object_id'])
    if result
      @domchange['object_id'] = result[1]  # student_dom_id where lesson is to be placed
      @domchange['object_type'] = 'tutor'
      tutor_id = result[4]
      lesson_id = result[3]
      @tutrole = Tutrole.where(:tutor_id => tutor_id, :lesson_id => lesson_id).first
    end
    if @tutrole.destroy
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
      # ONLY a copy allowed when source is in index index area.
      @domchange['action'] = 'copy' if  @domchange['action'] == 'move'   
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

    if( @domchange['action'] == 'move')    # move
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

    @domchange['html_partial'] = render_to_string("calendar/_schedule_tutor.html",
                                    :formats => [:html], :layout => false,
                                    :locals => {:tutor => @tutrole.tutor, 
                                                :thistutrole => @tutrole, 
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
        ActionCable.server.broadcast "calendar_channel", { json: @domchange }
      else
        format.json { render json: @tutrole.errors.messages, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tutorupdateskc.json
  # ajax updates skc = status kind comment
  def tutorupdateskc
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
    if((result = /^(([A-Z]+\d+)n(\d+))t(\d+)$/.match(params[:domchange][:object_id])))
      slot_id = result[2]
      tutor_dbId = result[4].to_i
      lesson_dbId = result[3].to_i
      @domchange['object_type'] = 'tutor'
      @domchange['from'] = result[1]
    end

    @tutrole = Tutrole.includes(:tutor)
                      .where(:tutor_id => tutor_dbId, :lesson_id => lesson_dbId)
                      .first
                      
    flagupdate = false
    case @domchange['updatefield']
    when 'status'
      if @tutrole.status != @domchange['updatevalue']
        @tutrole.status = @domchange['updatevalue']
        flagupdate = true
      end
    when 'kind'
      if @tutrole.kind != @domchange['updatevalue']
        @tutrole.kind = @domchange['updatevalue']
        flagupdate = true
      end
    when 'comment'
      if @tutrole.comment != @domchange['updatevalue']
        @tutrole.comment = @domchange['updatevalue']
        flagupdate = true
      end
    end
    
    @domchange['html_partial'] = render_to_string("calendar/_schedule_tutor.html",
                                :formats => [:html], :layout => false,
                                :locals => {:tutor => @tutrole.tutor, 
                                            :thistutrole => @tutrole, 
                                            :slot => slot_id, 
                                            :lesson => lesson_dbId
                                           })
    
    #Thread.current[:current_user_id] = current_user.id
    @updateValues = "test"
    respond_to do |format|
      if @tutrole.save
        format.json { render json: @domchange, status: :ok }
        ActionCable.server.broadcast "calendar_channel", { json: @domchange }
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
                                    :element_type, :new_value, 
                                    :object_id, :object_type, :to,
                                    :updatefield, :updatevalue]
      )
    end



end
