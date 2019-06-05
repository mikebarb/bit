class TutorsController < ApplicationController
  include Historyutilities
  
  before_action :set_tutor, only: [:show, :edit, :update, :destroy, :history]
  #before_filter :authenticate_user!, :set_user_for_models
  #after_filter :reset_user_for_models
  before_action :authenticate_user!, :set_user_for_models
  after_action :reset_user_for_models

  # GET /tutors
  # GET /tutors.json
  def index
    @tutors = Tutor
              .order(:pname)
              .page(params[:page])
    @listtutortitle = "Listing All Tutors"
  end

  # GET /activetutors
  # GET /activetutors.json
  def activetutors
    @tutors = Tutor
              .where.not(status: 'inactive')
              .order(:pname)
              .page(params[:page])
    @listtutortitle = "Listing Active Tutors"
    render 'index' and return
  end

  # GET /alltutors
  # GET /alltutors.json
  def alltutors
    @tutors = Tutor.order(:pname)
    @listtutortitle = "Listing All Tutors"
  end

  # GET /alltutors
  # GET /alltutors.json
  def allactivetutors
    @tutors = Tutor
              .where.not(status: 'inactive')
              .order(:pname)
    @listtutortitle = "Listing All Active Tutors"
    render 'alltutors' and return
  end

  # GET /tutors/1
  # GET /tutors/1.json
  def show
  end

  # GET /tutors/history
  # GET /tutors/history.json
  def allhistory
    @tutors_history = Array.new
    tutors = Tutor.all.order("pname")
    tutors.each do |thistutor|
      @tutors_history.push(tutor_history(thistutor.id, {}))
    end
  end

  # GET /tutors/history/1
  # GET /tutors/history/1.json
  def history
    options = Hash.new
    options['action'] = 'history'
    if params.has_key?('startdate')
      options['startdate'] = params['startdate'].to_date
    end
    if params.has_key?('enddate')
      options['startdate'] = params['enddate'].to_date
    end
    @tutor_history =  tutor_history(params[:id], options)
    respond_to do |format|
      format.html
      # helpful reference for jbuilder is
      # https://devblast.com/b/jbuilder
      format.json { render :history, status: :ok }
    end
  end

  # GET /tutors/term/1
  # GET /tutors/term/1.json
  def term
    options = Hash.new
    options['action'] = 'term'
    options['startdate'] = current_user.termstart
    options['enddate'] = current_user.termstart + current_user.termweeks.weeks
    @tutor_history =  tutor_history(params[:id], options)
    respond_to do |format|
      #format.html
      # helpful reference for jbuilder is
      # https://devblast.com/b/jbuilder
      format.json { render :history, status: :ok }
    end
  end


  # GET /tutors/history/1
  # GET /tutors/history/1.json
  def chain
    @tutor_history =  tutor_chain(params[:id], params[:lesson_id], {})
  end

  # GET /tutors/change/1
  # GET /tutors/change/1.json
  def change
    @tutor_change =  tutor_change(params[:id])
    respond_to do |format|
      format.html
      format.json { render :change, status: :ok }
    end
  end



  # GET /tutors/new
  def new
    @tutor = Tutor.new
  end

  # GET /tutors/1/edit
  def edit
  end

  # POST /tutors
  # POST /tutors.json
  def create
    @tutor = Tutor.new(tutor_params)

    respond_to do |format|
      if @tutor.save
        format.html { redirect_to @tutor, notice: 'Tutor was successfully created.' }
        format.json { render :show, status: :created, location: @tutor }
      else
        format.html { render :new }
        format.json { render json: @tutor.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /tutordetailupdateskc
  # POST /tutordetailupdateskc.json
  def tutordetailupdateskc
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    
    # extract the tutor id independant of 'index' or 'schedule' area
    # id = t11111           ->  index
    # id = GUN2018...t11111 -> schedule
    if((result = /(t(\d+))$/.match(params[:domchange][:object_id])))
      tutor_dbId = result[2].to_i
      @domchange['object_type'] = 'tutor'
      @domchange['object_id_old'] = @domchange['object_id']
      @domchange['object_id'] = result[1]
    end
    logger.debug "@domchange: " + @domchange.inspect

    @tutor = Tutor.find(tutor_dbId)
    flagupdate = false
    case @domchange['updatefield']
    when 'comment'
      if @tutor.comment != @domchange['updatevalue']
        @tutor.comment = @domchange['updatevalue']
        flagupdate = true
      end
    when 'subjects'
      if @tutor.subjects != @domchange['updatevalue']
        @tutor.subjects = @domchange['updatevalue']
        flagupdate = true
      end
    end

    respond_to do |format|
      if @tutor.save
        format.json { render json: @domchange, status: :ok }
        #ActionCable.server.broadcast "calendar_channel", { json: @domchange }
        ably_rest.channels.get('calendar').publish('json', @domchange)
      else
        logger.debug("errors.messages: " + @tutor.errors.messages.inspect)
        format.json { render json: @tutor.errors.messages, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tutors/1
  # PATCH/PUT /tutors/1.json
  def update
    respond_to do |format|
      if @tutor.update(tutor_params)
        format.html { redirect_to @tutor, notice: 'Tutor was successfully updated.' }
        format.json { render :show, status: :ok, location: @tutor }
      else
        format.html { render :edit }
        format.json { render json: @tutor.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tutors/1
  # DELETE /tutors/1.json
  def destroy
    if @tutor.destroy
      respond_to do |format|
        format.html { redirect_to tutors_url, notice: 'Tutor was successfully destroyed.' }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to tutors_url, 
          notice: "#{@tutor.errors.messages[:base].reduce { |memo, m| memo + m } }" +
                  " Tutor was NOT destroyed." 
        }
        format.json { render json: @tutor.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tutor
      @tutor = Tutor.find(params[:id])
    end

    def set_user_for_models
      Thread.current[:current_user_id] = current_user.id
    end
    
    def reset_user_for_models
      Thread.current[:current_user_id] = nil
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def tutor_params
      params.require(:tutor).permit(:gname, :sname, :pname, :initials, :sex,
                                    :subjects, :comment, :status, :kind, 
                                    :email, :phone, :firstaid, :firstlesson,
                                    :bfl
                                   )
    end

end
