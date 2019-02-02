class CalendarController < ApplicationController
  include Calendarutilities

  #=============================================================================================
  # ********************************************************************************************
  # * the workdesk - flexible display with multiple options.                                   *
  # ********************************************************************************************
  #=============================================================================================

  def globalstudents
    logger.debug "called calendar conroller - update_stats_students"
    student_stats()
    @domchange = Hash.new
    @domchange['html_partial'] = render_to_string("calendar/_stats_students.html",
                        :formats => [:html], :layout => false)
    respond_to do |format|
      format.json { render json: @domchange, status: :ok }
    end
  end

  def displayoptions
    logger.debug "called calendar conroller - preferences"
  end
  
  def flexibledisplay
    #@sf = 5   # number of significant figures in dom ids for lesson,tutor, etc.
    @options = Hash.new  # options to be passed into calendar read utility.
    # dates can come from user preferences or be overridden by settings
    # in the flexible display options or passed parameter options.
    
    @displayHeader = 'Flexible Display of Calendar Workbench - no filtering'

    #Refresh here is a button onthe flexible calendar display that 
    # lets a user refresh their page and maintain all their setting.
    # This includes the checkboxes on the page - makes it deeper 
    # than a normal refresh.
    flagRefresh = false
    if params.has_key?(:refresh)
      logger.debug "we do have refresh parameters passed - they will take precedence"
      flagRefresh = true
      passedParams = params.dup
      passedParams.delete(:refresh)
      passedParams.delete(:controller)
      passedParams.delete(:action)
      if params.has_key?(:displayheader)
        @displayHeader  =  params[:displayheader] 
        passedParams.delete(:displayheader)
      end
    end
    
    if flagRefresh && params.has_key?(:startdate) 
      @options[:startdate] = params[:startdate].to_date
      passedParams.delete(:startdate)
    else
      params[:daystart].blank? ? mystartdate = current_user.daystart :
                                 mystartdate = params[:daystart].to_date
      @options[:startdate] = mystartdate
    end
    if flagRefresh && params.has_key?(:enddate) 
      @options[:enddate] = params[:enddate].to_date
      passedParams.delete(:enddate)
    else
      params[:daydur].blank?   ? mydaydur = current_user.daydur :
                                 mydaydur = params[:daydur].to_i  
      mydaydur < 1  || mydaydur > 21   ? mydaydur : 1 # limit range of days allowed!!!
      myenddate = @options[:startdate] + mydaydur.days
      @options[:enddate] = myenddate
    end


    # @tutors and @students are used by the cal
    @tutors = Tutor
              .where.not(status: "inactive")
              .order('pname')
    @students = Student
                .where.not(status: "inactive")
                .order('pname')

    # ------------------ Roster or Ratio display (Flexible Display) ----------------------
    # There is a choice of many paramters that can be passed.
    if params[:bench] == "roster" || (flagRefresh && params.has_key?(:roster)) 
      @options[:roster] = true
      @displayHeader = 'Roster' unless flagRefresh
    end
    if params[:bench] == "ratio" || (flagRefresh && params.has_key?(:ratio))
      @options[:ratio] = true
      @displayHeader = 'Display Ratios between Tutors and Students' unless flagRefresh
    end
    if params[:bench] == "stats" || (flagRefresh && params.has_key?(:stats))
      @options[:stats] = true
      @displayHeader = 'Display Statistics' unless flagRefresh
    end
    # if this is a refresh, then we now just pick up the passed in options
    if flagRefresh
      passedParams.each do |k, v|
        logger.debug "parameter: " + k.inspect + ' => ' + v.inspect
        if v.count(',') > 0
          @options[k.intern] = v.split(/\s*,\s*/)
        elsif v == ''
          @options[k.intern] = []
        else
          @options[k.intern] = v
        end
      end
      @options.each do |k, v|
        logger.debug "options: " + k.inspect + ' => ' + v.inspect
      end
    end # now override any other settings
    
    unless flagRefresh      # the options are already set
      # if roster or ratio is selected without any user settings selected,
      # then we run a standard roster configuration - used for publishing rosters.
      if @options[:roster] || @options[:ratio]
        # set default roster options, if not selected by user
        if((params.has_key?(:select_roster_default)) && 
           (params[:select_roster_default] == '1'))
          @options[:select_tutor_statuses]   = true
          @options[:tutor_statuses]    = ['attended', 'scheduled', 'notified', 'confirmed', 'deal']
          #if params[:bench] == "ratio"
          if @options.has_key?(:ratio)
            @options[:select_tutor_kinds_exclude]   = true
            @options[:tutor_kinds]    = ['onSetup', 'onCall']
          end
          @options[:select_student_statuses]   = true
          @options[:student_statuses]  = ['attended', 'scheduled', 'deal', 'absent']
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
    end             # end the refresh options - overriding normal flexible settings  
    # ------- END ------ Roster display (Flexible Display) ----------------------
    # If there are commas in the header, it will upset the page refresh functions.
    @displayHeader = @displayHeader.gsub(/\,/,"")
    @options[:displayheader] = @displayHeader
    logger.debug "pass these options: " + @options.inspect
    #byebug
    # @compress is used in rendering the display.
    ### @compress = params.has_key?(:compress) ? true : false
    @compress = false
    if params.has_key?(:compress) || (flagRefresh && @options.has_key?(:compress))
      @compress = true
      @options[:compress] = true
    end
    
    # call the library in controllers/concerns/calendarutilities.rb
    #@cal = calendar_read_display1f(@sf, @options)
    @cal = calendar_read_display1f(@options)
    
    if @options[:ratio]
      generate_ratios()
      render 'flexibledisplayratios' and return
    end
    if @options[:stats]
      generate_stats()
      render 'flexibledisplaystats' and return
    end

  end

end

