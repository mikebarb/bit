class TutrolesController < ApplicationController
  include ChainUtilities
  
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
    result = /^(([A-Z]+\d+l\d+)n(\d+)t(\d+))$/.match(@domchange['object_id'])
    if result
      @domchange['object_id'] = result[1]  # student_dom_id where lesson is to be placed
      @domchange['object_type'] = 'tutor'
      tutor_id = result[4]
      lesson_id = result[3]
      @tutrole = Tutrole.where(:tutor_id => tutor_id, :lesson_id => lesson_id).first
    end
    if( @domchange['action'] == 'removerun')   # multiple deletions.
      # Processing the chain.
      this_error = runremovepersonfromlesson(@tutrole)
      if this_error.length > 0
        respond_to do |format|
          format.json { render json: this_error, status: :unprocessable_entity }
        end
        logger.debug "unprocessable entity(line 78): " + this_error 
        return
      end
      return
    else  # single deletion
      # prevent mistakes - front end should never let you get to here.
      if @tutrole.first != nil   # a chain element
        this_error = "You cannot do a single element deletion on a chain element!!"
        respond_to do |format|
          format.json { render json: this_error, status: :unprocessable_entity }
        end
        logger.debug "unprocessable entity(line 82): " + this_error 
        return
      end        
    end
    if @tutrole.destroy
      respond_to do |format|
        format.json { render json: @domchange, status: :ok }
        #ActionCable.server.broadcast "calendar_channel", { json: @domchange }
        ably_rest.channels.get('calendar').publish('json', @domchange)
      end
    else
      respond_to do |format|
        format.json { render json: @lesson.errors, status: :unprocessable_entity  }
      end
    end
  end

  #*******************************tutorupdateskc*****************************
  #                                  
  def tutormovecopylesson
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    this_error = ""
    # from / source
    # need to check if is from index area or schedule area
    # identified by the id
    # id = t11111     ->  index
    # id = GUN2018... -> schedule
    if((result = /^([A-Z]+\d+l\d+n(\d+))t(\d+)$/.match(params[:domchange][:object_id])))
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
    #------------------------------------------------------------------------
    # Handle the different destination scenarios.
    #------------------------------------------------------------------------
    # to / destination
    #
    # 'extendrun' has no parent 'to' destingation
    # it simply continues the run to the end of the block
    # as defined by the parent.
    if(@domchange['action'] == "extendrun")
      # Nothing to do here - must ignore.
      #logger.debug "in extend run - no destination sought."
    else  # the normal to destination
      result = /^(([A-Z]+\d+l\d+)n(\d+))/.match(@domchange['to'])
      if result 
        new_lesson_id = result[3].to_i
        new_slot_id = result[2]
        @domchange['to'] = result[1]
      end
    end
    #------------------------------------------------------------------------
    # Now handle the different types of moves or copies.
    #------------------------------------------------------------------------
    #---------------------------- start of extendrun ------------------------
    if( @domchange['action'] == 'extendrun')
      # offload extend run to it's own function
      # we must handle any errors here
      this_error = doExtendRun(@domchange['object_id'])
    #---------------------------- start of moverun --------------------------
    elsif( @domchange['action'] == 'moverun')
      this_error = doMoveRun(@domchange['object_id'], @domchange['to'], {})      # element dom_id to be moved, destination dom_id

    #----------------------- start of moverunsingle --------------------------
    # moves a single element in the chain - able to break chain at both sides of element 
    elsif( @domchange['action'] == 'moverunsingle')
      this_error = doMoveRun(@domchange['object_id'], @domchange['to'], {'single' => true})      # element dom_id to be moved, destination dom_id
    #------------------------ Single Element operation ----------------------
    elsif(@domchange['action'] == 'move' ||
          @domchange['action'] == 'copy')
      this_error = doSingleMoveCopy(@domchange['action'],     # action - move or copy 
                                    @domchange['object_id'],  # source element
                                    @domchange['to'])         # destination element
    end
    # If an error, simply report it and end
    if this_error.length > 0
      respond_to do |format|
        format.json { render json: this_error, status: :unprocessable_entity }
      end
      logger.debug "unprocessable entity(line 478): " + this_error.inspect 
      return
    end
    # All OK if you get to here.
    respond_to do |format|
      format.json { render json: @domchange, status: :ok }
    end
    
=begin    
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
        #ActionCable.server.broadcast "calendar_channel", { json: @domchange }
        ably_rest.channels.get('calendar').publish('json', @domchange)
      else
        format.json { render json: @tutrole.errors.messages, status: :unprocessable_entity }
      end
    end
=end
  end

  #*******************************tutorupdateskc*****************************
  #                                  OLD Version
  def tutormovecopylesson_old
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    this_error = ""
    # from / source
    # need to check if is from index area or schedule area
    # identified by the id
    # id = t11111     ->  index
    # id = GUN2018... -> schedule
    if((result = /^([A-Z]+\d+l\d+n(\d+))t(\d+)$/.match(params[:domchange][:object_id])))
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
    #------------------------------------------------------------------------
    # Handle the different destination scenarios.
    #------------------------------------------------------------------------
    # to / destination
    #
    # 'extendrun' has no parent 'to' destingation
    # it simply continues the run to the end of the block
    # as defined by the parent.
    result = /^(([A-Z]+\d+l\d+)n(\d+))/.match(params[:domchange][:to])
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
        #ActionCable.server.broadcast "calendar_channel", { json: @domchange }
        ably_rest.channels.get('calendar').publish('json', @domchange)
      else
        format.json { render json: @tutrole.errors.messages, status: :unprocessable_entity }
      end
    end
  end







  #*******************************tutorupdateskc*****************************
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
    if((result = /^(([A-Z]+\d+l\d+)n(\d+))t(\d+)$/.match(params[:domchange][:object_id])))
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
        #ActionCable.server.broadcast "calendar_channel", { json: @domchange }
        ably_rest.channels.get('calendar').publish('json', @domchange)
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
