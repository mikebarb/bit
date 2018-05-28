class CalendarController < ApplicationController
  include Calendarutilities

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
    #byebug
    #logger.debug "display1 ending"
  end
 
   #=============================================================================================
  # the workdesk - display tutors and students hortzontally 
  #=============================================================================================
  def display1f
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
    @cal = calendar_read_display1f(@sf, mystartdate, myenddate, {})
    #byebug
    #logger.debug "display1 ending"
  end
  
  
  
  #=============================================================================================
  # the workdesk - displays tutors and students vertically
  #=============================================================================================
  def display2
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
  end
  
  #=============================================================================================
  # roster display for use at the sites
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
  # roster display for use at the sites   -   show all days of the week
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

end
