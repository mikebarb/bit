class CalendarController < ApplicationController
  include Calendarutilities

  #=============================================================================================
  # ********************************************************************************************
  # * the workdesk - flexible display with multiple options.                                   *
  # ********************************************************************************************
  #=============================================================================================
  def displayoptions
    logger.debug "called calendar conroller - preferences"
  end
  
  def flexibledisplay
    @sf = 5   # number of significant figures in dom ids for lesson,tutor, etc.
    @options = Hash.new  # options to be passed into calendar read utility.
    # dates can come from user preferences or be overridden by settings
    # in the flexible display options or passed parameter options.
    params[:daystart].blank? ? mystartdate = current_user.daystart :
                                       mystartdate = params[:daystart].to_date
    params[:daydur].blank?   ? mydaydur = current_user.daydur :
                                       mydaydur = params[:daydur].to_i  
    mydaydur < 1  || mydaydur > 21   ? mydaydur : 1 # limit range of days allowed!!!
    myenddate = mystartdate + mydaydur.days
    @options[:startdate] = mystartdate
    @options[:enddate] = myenddate

    @displayHeader = 'Flexible Display of Calendar Workbench - no filtering'


    # @tutors and @students are used by the cal
    @tutors = Tutor
              .where.not(status: "inactive")
              .order('pname')
    @students = Student
                .where.not(status: "inactive")
                .order('pname')

    #byebug
    # ------------------ Roster or Ratio display (Flexible Display) ----------------------
    # There is a choice of many paramters that can be passed.
    

    if params[:bench] == "roster"
      @options[:roster] = true
      @displayHeader = 'Roster'
    end
    if params[:bench] == "ratio"
      @options[:ratio] = true
      @displayHeader = 'Display Ratios between Tutors and Students'
    end
    # if roster or ratio is selected without any user settings selected,
    # then we run a standard roster configuration - used for publishing rosters.
    if @options[:roster] || @options[:ratio]
      # set default roster options, if not selected by user
      if((params.has_key?(:select_roster_default)) && (params[:select_roster_default] == '1'))
        @options[:select_tutor_statuses]   = true
        @options[:tutor_statuses]    = ['attended', 'notified', 'scheduled']
        if params[:bench] == "ratio"
          @options[:select_tutor_kinds_exclude]   = true
          @options[:tutor_kinds]    = ['onSetup', 'onCall']
        end
        @options[:select_student_statuses]   = true
        @options[:student_statuses]  = ['attended', 'scheduled']
        @displayHeader = 'Roster - default roster filtering' if @options[:roster]
        @displayHeader = 'Display Ratios - using default roster filtering' if @options[:ratio]
      else 
        # Check = does user want to display NO tutors
        if((params.has_key?(:select_tutor_none)) && (params[:select_tutor_none] == '1'))
          # To not display tutors, trick is to select tutors with empty ids
          @options[:select_tutors] = true
          @options[:tutor_ids] = []
        else   # Normal user selection for tutors
          #
          # detect if we want to show tutors with first aid certification
          if((params.has_key?(:select_tutor_firstaid)) && (params[:select_tutor_firstaid] == '1'))
            @options[:select_tutor_firstaid] = true
          end
          # detect if selection by statues is requested
          # if so, then load the requested statues - else do not create the option
          # For tutors.
          if((params.has_key?(:select_tutor_statuses)) && (params[:select_tutor_statuses] == '1'))
            @options[:select_tutor_statuses] = true
            if params.has_key?(:tutor_statuses)
              @options[:tutor_statuses] = params[:tutor_statuses]
            end
          end
          
          # detect if selection by kinds is requested
          # if so, then load the requested kinds - else do not create the option
          # For tutors
          if((params.has_key?(:select_tutor_kinds)) && (params[:select_tutor_kinds] == '1'))
            @options[:select_tutor_kinds] = true
            if params.has_key?(:tutor_kinds)
              @options[:tutor_kinds] = params[:tutor_kinds]
            end
          end
          
          # detect if selection by tutors (names, email, ids) is requested
          # if so, then load the requested tutors - else do not create this option
          # One of three ways to identify tutors - names, emails or record ids
          if((params.has_key?(:select_tutors)) && (params[:select_tutors] == '1'))
            @options[:select_tutors] = true
            if params.has_key?(:tutor_identifiers)
              # first clean up the input - is a user inputed text field!
              t = params[:tutor_identifiers].split(',').map {|o| o.downcase.strip}
              t = t.reduce([]) { |a, o|   
                a << o if o != "" 
                a
              }
              # we only pass into the display utility the [record ids, ...]
              if params[:t_type] == 'name'   # tutors will be identified by name
                desiredtutors = @tutors.reduce([]){ |a, o|
                  t.each do |u|
                    if o.pname.downcase.include? u
                      a << o.id
                      break
                    end
                  end
                  a
                }
              end
              if params[:t_type] == 'email'   # tutors will be identified by email
                desiredtutors = @tutors.reduce([]){ |a, o|
                  t.each do |u|
                    logger.debug "checking tutor " + o.inspect
                    if ((o.email != nil) && (o.email.downcase.include? u))
                      a << o.id
                      break
                    end
                  end
                  a
                }
              end
              if params[:t_type] == 'id'   # clean up tutors will be identified by id
                desiredtutors = @tutors.reduce([]){ |a, o|
                  t.each do |u|
                    if(/(\D+)/.match(u).nil? && (o.id == u.to_i))
                      a << o.id
                    end
                  end
                  a
                }
              end
              @options[:tutor_ids] = desiredtutors
            end   # end of tutor identifere present
          end     # end of select tutors - user selectible options
        end       # of display tutors ( none or user selectable)

        if((params.has_key?(:select_student_none)) && (params[:select_student_none] == '1'))
          # To not display students, trick is to select students with empty ids
          @options[:select_students] = true
          @options[:student_ids] = []
        else   # Normal user selection for students
          # detect if selection by statues is requested
          # if so, then load the requested statues - else do not create the option
          # For students.
          if((params.has_key?(:select_student_statuses)) && (params[:select_student_statuses] == '1'))
            @options[:select_student_statuses] = true
            if params.has_key?(:student_statuses)
              @options[:student_statuses] = params[:student_statuses]
            end
          end
          
          # detect if selection by kinds is requested
          # if so, then load the requested kinds - else do not create the option
          # For tutors
          if((params.has_key?(:select_student_kinds)) && (params[:select_student_kinds] == '1'))
            @options[:select_student_kinds] = true
            if params.has_key?(:student_kinds)
              @options[:student_kinds] = params[:student_kinds]
            end
          end
          
          # detect if selection by students is requested
          # if so, then load the requested students - else do not create the option
          # One of three ways to identify students - names, emails or record ids
          if((params.has_key?(:select_students)) && (params[:select_students] == '1'))
            @options[:select_students] = true
            if params.has_key?(:student_identifiers)
              # first clean up the input - is a user inputed text field!
              t = params[:student_identifiers].split(',').map {|o| o.downcase.strip}
              t = t.reduce([]) { |a, o|   
                a << o if o != "" 
                a
              }
              # we only pass into the display utility the [record ids, ...]
              if params[:t_type] == 'name'   # students will be identified by name
                desiredstudents = @students.reduce([]){ |a, o|
                  t.each do |u|
                    if o.pname.downcase.include? u
                      a << o.id
                      break
                    end
                  end
                  a
                }
              end
              if params[:t_type] == 'email'   # students will be identified by email
                desiredstudents = @students.reduce([]){ |a, o|
                  t.each do |u|
                    logger.debug "checking student " + o.inspect
                    if ((o.email != nil) && (o.email.downcase.include? u))
                      a << o.id
                      break
                    end
                  end
                  a
                }
              end
              if params[:t_type] == 'id'   # clean up students will be identified by id
                desiredstudents = @students.reduce([]){ |a, o|
                  t.each do |u|
                    if(/(\D+)/.match(u).nil? && (o.id == u.to_i))
                      a << o.id
                    end
                  end
                  a
                }
              end
              @options[:student_ids] = desiredstudents
            end   # end of student identifere present
          end     # end of select students ...
        end       # end of none or user selection 
      end         # end of default roster & ratio settings
    end           # end of roster display - setting up parameters
    # ------- END ------ Roster display (Flexible Display) ----------------------
    logger.debug "pass these options: " + @options.inspect
    #byebug
    # @compress is used in rendering the display.
    @compress = params.has_key?(:compress) ? true : false
    
    # call the library in controllers/concerns/calendarutilities.rb
    #@cal = calendar_read_display1f(@sf, mystartdate, myenddate, @options)
    @cal = calendar_read_display1f(@sf, @options)
    
    if @options[:ratio]
      generate_ratios()
      render 'flexibledisplayratios' and return
    end

  end

end
