class Api::V1::StudentsController < ApiController
  respond_to :json
  include Historyutilities
  include Calendarutilities
  before_action :set_student, only: [:show, :showsessions, :edit, :update, :destroy]
  before_filter :set_user_for_models
  after_filter :reset_user_for_models

  # GET /students
  # GET /students.json
  def index
    @students = Student
    .order(:pname)
    .page(params[:page])
  end

  # GET /allstudents
  # GET /allstudents.json
  def allstudents
    @students = Student
    .order(:pname)
    respond_with @students
  end


  # GET /students/1
  # GET /students/1.json
  def show
    respond_with @student
  end
  
  # GET /students/history/1
  # GET /students/history/1.json
  def history
    options = Hash.new
    if params.has_key?('startdate')
      options['startdate'] = params['startdate'].to_date
    end
    if params.has_key?('enddate')
      options['enddate'] = params['enddate'].to_date
    end
    logger.debug "options: " + options.inspect
    @student_history =  student_history(params[:id], options)

    respond_to do |format|
      format.html
      # helpful reference for jbuilder is
      # https://devblast.com/b/jbuilder
      format.json { render :history, status: :ok }
    end
  end
=begin
  # GET /students/history/1
  # GET /students/history/1.json
  def history
    @student_history =  student_history(params[:id])
    respond_with @student_history
  end
=end
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
    flagupdate = flagupdatestats = false
    case @domchange['updatefield']
    when 'comment'
      if @student.comment != @domchange['updatevalue']
        @student.comment = @domchange['updatevalue']
        flagupdate = true
      end
    when 'status'
      if @student.status != @domchange['updatevalue']
        @student.status = @domchange['updatevalue']
        flagupdatestats = flagupdate = true
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
        #ActionCable.server.broadcast "calendar_channel", { json: @domchange }
        ably_rest.channels.get('calendar').publish('json', @domchange)
        # Need to get all the slots that these students are in.
        if flagupdatestats
          ##------------------------------- hints ------------------
          ## For includes (and joins):
          ## 1. Names are association names (not the table names!)
          ## 2. to load multiple associations, use an array
          ## 3. to load associations with children, use a hash => 
          ##      key is parent association name, 
          ##      value is description of child association
          ##--------------------------------------------------------
          #this_start_date = Time.now()
          this_start_date = Time.strptime("2018-06-25", "%Y-%m-%d")
          #this_end_date = this_start_date + 3.days
          stats_slots = Slot
                        .select('id', 'timeslot', 'location')
                        .joins({lessons: :roles})
                        .where('student_id = :sid AND
                                timeslot > :sd', {sid: @student.id, sd: this_start_date})
          stats_slot_domids = stats_slots.map do |o| 
            o.location[0,3].upcase + o.timeslot.strftime('%Y%m%d%H%M') +
                                    'l' + o.id.to_s
          end
          logger.debug "=============stats_slot_domids: " + stats_slot_domids.inspect 
          stats_slot_domids.each do |this_domid|
            # need to pass in slot_dom_id, however only extracts slot db id,
            # so do a fudge here so extraction of db_id works.
            get_slot_stats(this_domid)  # need to pass in slot_dom_id
            logger.debug "***************calling get_slot_stats: " + this_domid.inspect
          end
        end
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
