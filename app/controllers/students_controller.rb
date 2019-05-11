class StudentsController < ApplicationController
  include Historyutilities
  include Calendarutilities
  before_action :set_student, only: [:show, :showsessions, :edit, :update, :destroy]
  before_filter :authenticate_user!, :set_user_for_models
  after_filter :reset_user_for_models

  # GET /students
  # GET /students.json
  def index
    @students = Student
    .order(:pname)
    .page(params[:page])
    @liststudenttitle = "Listing Students"
  end

  # GET /activestudents
  # GET /activestudents.json
  def activestudents
    @students = Student
    .where.not(status: 'inactive')
    .order(:pname)
    .page(params[:page])
    @liststudenttitle = "Listing Active Students"
    render 'index' and return
  end

  # GET /allstudents
  # GET /allstudents.json
  def allstudents
    @students = Student
    .order(:pname)
    @liststudenttitle = "Listing All Students"
  end

  # GET /allactivestudents
  # GET /allactivestudents.json
  def allactivestudents
    @students = Student
    .where.not(status: 'inactive')
    .order(:pname)
    @liststudenttitle = "Listing All Active Students"
    render 'allstudents' and return
  end


  # GET /students/1
  # GET /students/1.json
  def show
  end
  
  # GET /students/history
  # GET /students/history.json
  def allhistory
    @students_history = Array.new
    students = Student
              .where.not(status: 'inactive')
              .order("pname")
    students.each do |thisstudent|
      @students_history.push(student_history(thisstudent.id, {}))
    end
  end

  # GET /students/history/1
  # GET /students/history/1.json
  def history
    options = Hash.new
    options['action'] = 'history'
    if params.has_key?('startdate')
      options['startdate'] = params['startdate'].to_date
    end
    if params.has_key?('enddate')
      options['enddate'] = params['enddate'].to_date
    end
    @student_history =  student_history(params[:id], options)
    respond_to do |format|
      format.html
      # helpful reference for jbuilder is
      # https://devblast.com/b/jbuilder
      format.json { render :history, status: :ok }
    end
  end

  # GET /students/feedback
  def allfeedback
    @students_feedback = Array.new
    students = Student
               .where.not(status: 'inactive')
               .order("pname")
    students.each do |thisstudent|
      @students_feedback.push(student_feedback(thisstudent.id, {}))
    end
  end

  # GET /students/feedback/1
  def feedback
    options = Hash.new
    options['action'] = 'feedback'
    # By default,use the dates from the users preference display dates
    options['startdate'] = current_user.daystart
    mydaydur = current_user.daydur
    mydaydur < 1  || mydaydur > 180   ? mydaydur : 1 # limit range of days allowed!!!
    options['enddate'] = options['startdate'] + mydaydur.days
    if params.has_key?('startdate')
      options['startdate'] = params['startdate'].to_date
    end
    if params.has_key?('enddate')
      options['enddate'] = params['enddate'].to_date
    end
    @student_feedback =  student_feedback(params[:id], options)
    respond_to do |format|
      format.html
    end
  end

  # GET /students/term/1
  # GET /students/term/1.json
  def term
    options = Hash.new
    options['action'] = 'term'
    options['startdate'] = current_user.termstart
    options['enddate'] = current_user.termstart + current_user.termweeks.weeks
    @student_history =  student_history(params[:id], options)
    respond_to do |format|
      #format.html
      format.json { render :history, status: :ok }
    end
  end

  # GET /students/chain/1
  # GET /students/chain/1.json
  def chain
    @student_history =  student_chain(params[:id], params[:lesson_id], {})
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
          this_start_date = Time.now()
##########################################################################
#
#       WARNING - next line is for testing with development data
#
##########################################################################
          if Rails.env.development?
            this_start_date = Time.strptime("2018-06-18", "%Y-%m-%d")
            #this_end_date = this_start_date + 3.days
          end
          stats_slots = Slot
                        .select('id', 'timeslot', 'location')
                        .joins({lessons: :roles})
                        .where('student_id = :sid AND
                                timeslot > :sd', {sid: @student.id, sd: this_start_date})
          stats_slot_domids = stats_slots.map do |o| 
            o.location[0,3].upcase + o.timeslot.strftime('%Y%m%d%H%M') +
                                    'l' + o.id.to_s.rjust(@sf, "0")
          end
          #logger.debug "=============stats_slot_domids: " + stats_slot_domids.inspect 
          # Now to get all the slot stats and then send the set
          statschanges = Array.new
          stats_slot_domids.each do |this_domid|
            # need to pass in slot_dom_id, however only extracts slot db id,
            # so do a fudge here so extraction of db_id works.
            statschanges.push(get_slot_stats(this_domid))  # need to pass in slot_dom_id
          end
          ably_rest.channels.get('stats').publish('json', statschanges)
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
