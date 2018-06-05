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
    options = Hash.new  # options to be passed into calendar read utility.
    # dates can come from user preferences or be overridden by settings
    # in the flexible display options or passed parameter options.
    params[:daystart].blank? ? mystartdate = current_user.daystart :
                                       mystartdate = params[:daystart].to_date
    params[:daydur].blank?   ? mydaydur = current_user.daydur :
                                       mydaydur = params[:daydur].to_i  
    mydaydur < 1  || mydaydur > 21   ? mydaydur : 1 # limit range of days allowed!!!
    myenddate = mystartdate + mydaydur.days
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
      options[:roster] = true
      @displayHeader = 'Flexible Display of Roster'
    end
    if params[:bench] == "ratio"
      options[:ratio] = true
      @displayHeader = 'Flexible Display of Ratios between Tutors and Students'
    end

    # if roster or ratio is selected without any user settings selected,
    # then we run a standard roster configuration - used for publishing rosters.
    if options[:roster] || options[:ratio]
      # set default roster options, if not selected by user
      if((params.has_key?(:select_roster_default)) && (params[:select_roster_default] == '1'))
        options[:select_tutor_statuses]   = true
        options[:tutor_statuses]    = ['attended', 'notified', 'scheduled']
        options[:select_student_statuses]   = true
        options[:student_statuses]  = ['attended', 'scheduled']
        @displayHeader = 'Flexible Display of Roster - default roster filtering' if options[:roster]
        @displayHeader = 'Flexible Display of Ratios - using default roster filtering' if options[:ratio]
      else 
        # Check = does user want to display NO tutors
        if((params.has_key?(:select_tutor_none)) && (params[:select_tutor_none] == '1'))
          # To not display tutors, trick is to select tutors with empty ids
          options[:select_tutors] = true
          options[:tutor_ids] = []
        else   # Normal user selection for tutors
          #
          # detect if selection by statues is requested
          # if so, then load the requested statues - else do not create the option
          # For tutors.
          if((params.has_key?(:select_tutor_statuses)) && (params[:select_tutor_statuses] == '1'))
            options[:select_tutor_statuses] = true
            if params.has_key?(:tutor_statuses)
              options[:tutor_statuses] = params[:tutor_statuses]
            end
          end
          
          # detect if selection by kinds is requested
          # if so, then load the requested kinds - else do not create the option
          # For tutors
          if((params.has_key?(:select_tutor_kinds)) && (params[:select_tutor_kinds] == '1'))
            options[:select_tutor_kinds] = true
            if params.has_key?(:tutor_kinds)
              options[:tutor_kinds] = params[:tutor_kinds]
            end
          end
          
          # detect if selection by tutors (names, email, ids) is requested
          # if so, then load the requested tutors - else do not create this option
          # One of three ways to identify tutors - names, emails or record ids
          if((params.has_key?(:select_tutors)) && (params[:select_tutors] == '1'))
            options[:select_tutors] = true
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
              options[:tutor_ids] = desiredtutors
            end   # end of tutor identifere present
          end     # end of select tutors - user selectible options
        end       # of display tutors ( none or user selectable)

        if((params.has_key?(:select_student_none)) && (params[:select_student_none] == '1'))
          # To not display students, trick is to select students with empty ids
          options[:select_students] = true
          options[:student_ids] = []
        else   # Normal user selection for students
          # detect if selection by statues is requested
          # if so, then load the requested statues - else do not create the option
          # For students.
          if((params.has_key?(:select_student_statuses)) && (params[:select_student_statuses] == '1'))
            options[:select_student_statuses] = true
            if params.has_key?(:student_statuses)
              options[:student_statuses] = params[:student_statuses]
            end
          end
          
          # detect if selection by kinds is requested
          # if so, then load the requested kinds - else do not create the option
          # For tutors
          if((params.has_key?(:select_student_kinds)) && (params[:select_student_kinds] == '1'))
            options[:select_student_kinds] = true
            if params.has_key?(:student_kinds)
              options[:student_kinds] = params[:student_kinds]
            end
          end
          
          # detect if selection by students is requested
          # if so, then load the requested students - else do not create the option
          # One of three ways to identify students - names, emails or record ids
          if((params.has_key?(:select_students)) && (params[:select_students] == '1'))
            options[:select_students] = true
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
              options[:student_ids] = desiredstudents
            end   # end of student identifere present
          end     # end of select students ...
        end       # end of none or user selection 
      end         # end of default roster & ratio settings
    end           # end of roster display - setting up parameters
    # ------- END ------ Roster display (Flexible Display) ----------------------
    logger.debug "pass these options: " + options.inspect
    #byebug
    # @compress is used in rendering the display.
    @compress = params.has_key?(:compress) ? true : false
    
    # call the library in controllers/concerns/calendarutilities.rb
    @cal = calendar_read_display1f(@sf, mystartdate, myenddate, options)
    
    if options[:ratio]
      generate_ratios()
      render 'flexibledisplayratios' and return
    end

  end

  #=============================================================================================
  # the workdesk - display tutors and students hortzontally
  # calls the database query optimised version of the calendar utility.
  #=============================================================================================
  def display1f
    @sf = 5   # number of significant figures in dom ids for lesson,tutor, etc.

    @tutors = Tutor
              .where.not(status: "inactive")
              .order('pname')
    @students = Student
                .where.not(status: "inactive")
                .order('pname')

    mystartdate = current_user.daystart
    myenddate = current_user.daystart + current_user.daydur.days
    
    # call the library in controllers/concerns/calendarutilities.rb
    @cal = calendar_read_display1f(@sf, mystartdate, myenddate, {})
    @displayHeader = 'Calendar Workbench'
  end
  
  #=============================================================================================
  # the workdesk - display tutors and students hortzontally 
  #=============================================================================================
  def display1
    @sf = 5   # number of significant figures in dom ids for lesson,tutor, etc.
    #@site = "Kaleen"

    @tutors = Tutor
              .where.not(status: "inactive")
              .order('pname')
    @students = Student
                .where.not(status: "inactive")
                .order('pname')

    mystartdate = current_user.daystart
    myenddate = current_user.daystart + current_user.daydur.days
    
    # call the library in controllers/concerns/calendarutilities.rb
    @cal = calendar_read_display2(@sf, mystartdate, myenddate)
    @displayHeader = 'Calendar Workbench - slow version'
  end
 

  
  #=============================================================================================
  # the workdesk - displays tutors and students vertically
  #=============================================================================================
  def display2
    @sf = 5   # number of significant figures in dom ids for lesson,tutor, etc.

    @tutors = Tutor
              .where.not(status: "inactive")
              .order('pname')
    @students = Student
                .where.not(status: "inactive")
                .order('pname')

    mystartdate = current_user.daystart
    myenddate = current_user.daystart + current_user.daydur.days
    
    # call the library in controllers/concerns/calendarutilities.rb
    @cal = calendar_read_display2(@sf, mystartdate, myenddate)
  end
  
  #=============================================================================================
  # roster display for use at the sites
  #=============================================================================================
  def roster2
    #*****************************************************************
    # Set these to control what is displayed in the roster
    
    @tutorstatusforroster   = ["scheduled", "dealt", "confirmed", "attended"]
    @studentstatusforroster = ["scheduled", "dealt", "attended"]
    
    #*****************************************************************
    
    @sf = 5   # number of significant figures in dom ids for lesson,tutor, etc.

    mystartdate = current_user.daystart
    myenddate = current_user.daystart + current_user.daydur.days
    
    # call the library in controllers/concerns/calendarutilities.rb
    @cal = calendar_read_display2(@sf, mystartdate, myenddate)

    # remove unwanted lessons for the roster diaplay - empty of tutors and students.
    @cal.each do |location, calLocation|      # going through the sites
      calLocation.each do |rows|              # within a site, go through each array for that site
        rows.each do |cells|                  # for the array, step through each cell - which are slots - valid or invalid
          # still want to show all slots - just investigating lessions within slots.
          if cells.key?("values") then        # now dealing with a slot that has lessions
            if cells["values"].respond_to?(:each) then            # definitely has lesson entries.
              deleteLessons = []
              cells["values"].each_with_index do |entry, indexLesson|   # look at each lesson in turn.
                  # aim here is to remove lessons that have no tutors or students
                  logger.debug "indexLesson: " + indexLesson.inspect
                  logger.debug "entry: " + entry.inspect
                  
                  lessonTutorCount = 0
                  if entry.tutors.respond_to?(:each) then                        # if there are tutors
                    entry.tutors.each do |tutor|
                      if tutor then
                        mystatus = tutor.tutroles.where(lesson_id: entry.id).first.status
                        logger.debug "tutor status: " + mystatus.inspect
                        wantedTutor = @tutorstatusforroster.include?(tutor.tutroles.where(lesson_id: entry.id).first.status) 
                        if wantedTutor then
                          logger.debug "wanted tutor"
                          lessonTutorCount += 1                        # count the tutors 
                        end
                      end                     
                    end
                  end
                     
                  lessonStudentCount = 0
                  if entry.students.respond_to?(:each) then                     # if there are students
                    entry.students.each do |student|
                      if student then
                        mystatus = student.roles.where(lesson_id: entry.id).first.status
                        logger.debug "student status: " + mystatus.inspect
                        wantedStudent = @studentstatusforroster.include?(student.roles.where(lesson_id: entry.id).first.status) 
                        if wantedStudent then
                          logger.debug "wanted student"
                          lessonStudentCount += 1                        # count the students 
                        end
                      end
                    end
                  end

                  # Now if this lesson has no tutors or students, then need to delete it.
                  logger.debug "lessonTutorCount:   " + lessonTutorCount.inspect
                  logger.debug "lessonStudentCount: " + lessonStudentCount.inspect
                  if lessonTutorCount + lessonStudentCount == 0 then
                    logger.debug "delete this lesson: " + indexLesson.inspect
                    deleteLessons.push(indexLesson)
                  end
                  logger.debug "deleteLessons: " + deleteLessons.inspect
              end
              # now delete - starting at end
              deleteLessons.sort.reverse.each do |deleteIndex|
                cells["values"].delete_at(deleteIndex)
              end
            end
          end
        end
      end
    end

  end

  #=============================================================================================
  # the roster - display tutors and students hortzontally 
  #=============================================================================================
  def roster1f
    @sf = 5   # number of significant figures in dom ids for lesson,tutor, etc.
    #@site = "Kaleen"

    @tutors = Tutor
              .where.not(status: "inactive")
              .order('pname')
    @students = Student
                .where.not(status: "inactive")
                .order('pname')

    mystartdate = current_user.daystart
    myenddate = current_user.daystart + current_user.daydur.days
    
    # call the library in controllers/concerns/calendarutilities.rb
    @cal = calendar_read_display1f(@sf, mystartdate, myenddate, {roster: true})
  end
  
  #=============================================================================================
  # roster display for use at the sites   -   show all days of the week
  #=============================================================================================
  def roster1
    #*****************************************************************
    # Set these to control what is displayed in the roster
    
    @tutorstatusforroster   = ["scheduled", "dealt", "confirmed", "attended"]
    @studentstatusforroster = ["scheduled", "dealt", "attended"]
    
    #*****************************************************************
    
    @sf = 5   # number of significant figures in dom ids for lesson,tutor, etc.

    mystartdate = current_user.daystart
    myenddate = current_user.daystart + current_user.daydur.days
    
    # call the library in controllers/concerns/calendarutilities.rb
    @cal = calendar_read_display2(@sf, mystartdate, myenddate)

    # remove unwanted lessons for the roster diaplay - empty of tutors and students.
    @cal.each do |location, calLocation|      # going through the sites
      calLocation.each do |rows|              # within a site, go through each array for that site
        rows.each do |cells|                  # for the array, step through each cell - which are slots - valid or invalid
          # still want to show all slots - just investigating lessions within slots.
          if cells.key?("values") then        # now dealing with a slot that has lessions
            if cells["values"].respond_to?(:each) then            # definitely has lesson entries.
              deleteLessons = []
              cells["values"].each_with_index do |entry, indexLesson|   # look at each lesson in turn.
                  # aim here is to remove lessons that have no tutors or students
                  logger.debug "indexLesson: " + indexLesson.inspect
                  logger.debug "entry: " + entry.inspect
                  
                  lessonTutorCount = 0
                  if entry.tutors.respond_to?(:each) then                        # if there are tutors
                    entry.tutors.each do |tutor|
                      if tutor then
                        mystatus = tutor.tutroles.where(lesson_id: entry.id).first.status
                        logger.debug "tutor status: " + mystatus.inspect
                        wantedTutor = @tutorstatusforroster.include?(tutor.tutroles.where(lesson_id: entry.id).first.status) 
                        if wantedTutor then
                          logger.debug "wanted tutor"
                          lessonTutorCount += 1                        # count the tutors 
                        end
                      end                     
                    end
                  end
                     
                  lessonStudentCount = 0
                  if entry.students.respond_to?(:each) then                     # if there are students
                    entry.students.each do |student|
                      if student then
                        mystatus = student.roles.where(lesson_id: entry.id).first.status
                        logger.debug "student status: " + mystatus.inspect
                        wantedStudent = @studentstatusforroster.include?(student.roles.where(lesson_id: entry.id).first.status) 
                        if wantedStudent then
                          logger.debug "wanted student"
                          lessonStudentCount += 1                        # count the students 
                        end
                      end
                    end
                  end

                  # Now if this lesson has no tutors or students, then need to delete it.
                  logger.debug "lessonTutorCount:   " + lessonTutorCount.inspect
                  logger.debug "lessonStudentCount: " + lessonStudentCount.inspect
                  if lessonTutorCount + lessonStudentCount == 0 then
                    logger.debug "delete this lesson: " + indexLesson.inspect
                    deleteLessons.push(indexLesson)
                  end
                  logger.debug "deleteLessons: " + deleteLessons.inspect
              end
              # now delete - starting at end
              deleteLessons.sort.reverse.each do |deleteIndex|
                cells["values"].delete_at(deleteIndex)
              end
            end
          end
        end
      end
    end
  end
  
  #=============================================================================================
  # original one follows
  #=============================================================================================

  def display
    @sf = 3   # number of significant figures in dom ids for lesson,tutor, etc.
    @hall = "Kaleen"
    # define a two dimesional array to hold the table info to be displayed.
    # row and column [0] will hold counts of elements populated in that row or column
    # row and column [1] will hold the titles for that rolw or column.

    @sessinfo      = Lesson.all
    logger.debug "calendar display - (sessinfo) " + @sessinfo.inspect

    @slotsinfo     = Slot 
                  .select('id, timeslot, location')         
              
    @colheaders    = Slot
                  .select('timeslot')
                  .distinct
   
   logger.debug 'colheaders- ' + @colheaders.inspect
                  
    @rowheaders    = Slot
                  .select('location')
                  .distinct

   logger.debug 'rowheaders- ' + @rowheaders.inspect

    @cal = Array.new(1 + @rowheaders.count){Array.new(1 + @colheaders.count){Hash.new()}}

    i = 0
    @colindex = Hash.new
    @colheaders.each do |entry|
      i += 1
      thistime = entry.timeslot.strftime("%Y-%m-%d %H:%M")
      #@cal[0][i]["value"] = 0
      @cal[0][i]["value"] = entry.timeslot.strftime("%a %Y-%m-%d %H:%M")
      @colindex[thistime] = i
    end
    logger.debug "colindex- " + @colindex.inspect
    
    j = 0
    @rowindex = Hash.new
    @rowheaders.each do |entry|
      j += 1
      #@cal[j][0]["value"] = 0
      @cal[j][0]["value"] = entry.location
      @rowindex[entry.location] = j
    end
    logger.debug "rowindex- " + @rowindex.inspect

    # identify valid slots for display
    @slotsinfo.each do |myslot|
      thistime = myslot.timeslot.strftime("%Y-%m-%d %H:%M")
      @cal[@rowindex[myslot.location]][@colindex[thistime]]["slotid"] = myslot.id.to_s
      @cal[@rowindex[myslot.location]][@colindex[thistime]]["id_dom"] = 
                  myslot.location[0, 3].ljust(3, "-") + myslot.timeslot.strftime("%Y%m%d%H%M")
    end 
    
    @sessinfo.each do |entry|
      logger.debug "entry- " + entry.inspect
      thistime = entry.slot.timeslot.strftime("%Y-%m-%d %H:%M")
      logger.debug "thistime- " + thistime.inspect
      logger.debug "colindex- " + @colindex[thistime].inspect
      thislocation = entry.slot.location   
      logger.debug "thislocation- " + thislocation.inspect
      logger.debug "rowindex- " + @rowindex[thislocation].inspect
      unless @cal[@rowindex[thislocation]][@colindex[thistime]].key?('values') then  
        @cal[@rowindex[thislocation]][@colindex[thistime]]["values"]   = Array.new()
      end
      @cal[@rowindex[thislocation]][@colindex[thistime]]["values"]   << entry
      #@cal[@rowindex[thislocation]][@colindex[thistime]]["id_dom"] = thislocation[0, 3].ljust(3, "-") + 
      #                                            entry.slot.timeslot.strftime("%Y%m%d%H%M") 

      #logger.debug "======entry location" + thislocation
      #logger.debug "======entry id_dom" + @cal[@rowindex[thislocation]][@colindex[thistime]]["id_dom"].inspect
      
      #@cal[0][@colindex[thistime]]["value"] += 1
      #@cal[@rowindex[thislocation]][0]["value"] += 1
    end
    logger.debug '@cal- ' + @cal.inspect
  end
  
  private
  def display_params
    params.permit(:utf8, :daystart, :daydur, :commit, :bench, :tutor_statuses)
  end

end
