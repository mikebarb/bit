class CalendarController < ApplicationController
  def display
    @hall = "Kaleen"
    # define a two dimesional array to hold the table info to be displayed.
    # row and column [0] will hold counts of elements populated in that row or column
    # row and column [1] will hold the titles for that rolw or column.
#    @sessinfo      = Session
#                  .select('sessions.id as sessionid, slots.timeslot as timeslot, slots.location as location, students.pname as studentpname, tutors.pname as tutorpname, slots.id as slotid, students.id as studentid, tutors.id as tutorid')
#                  .joins(:slot)
#                  .joins(:students)
#                  .joins(:tutor)

#    @sessinfo      = Session
#                  .select('sessions.id as sessionid, slots.timeslot as timeslot, slots.location as location, tutors.pname as tutorpname, slots.id as slot_id, tutors.id as tutorid')
#                  .joins(:slot)
#                  .joins(:tutor)

    @sessinfo      = Session.all
#                  .joins(:slot)
#                  .joins(:tutor)
#                  .joins(:students)
    logger.debug "calendar display - (sessinfo) " + @sessinfo.inspect

#    @roles         = Role.all
#                  .select('student_id, session_id')
#                  .joins(:student)
#    logger.debug "calendar display - (roles) " + @roles.inspect

#    @students      = Student
#                  .joins(:roles)
#                  .pluck('roles.session_id, students.id, students.pname')
#    logger.debug "calendar display - (students) " + @students.inspect

#    @studenthash = Hash.new
#    @students.each do |a|
#      unless @studenthash.has_key?(a[0])
#         @studenthash[a[0]] = Array.new
#      end
#      @studenthash[a[0]] << a
#    end
    
#    logger.debug "calendar display - (studenthash) " + @studenthash.inspect

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

    @cal = Array.new(2 + @rowheaders.count){Array.new(2 + @colheaders.count){Hash.new()}}

    i = 1
    @colindex = Hash.new
    @colheaders.each do |entry|
      i += 1
      thistime = entry.timeslot.strftime("%Y-%m-%d %H:%M")
      @cal[0][i]["value"] = 0
      @cal[1][i]["value"] = thistime
      @colindex[thistime] = i
    end
    logger.debug "colindex- " + @colindex.inspect
    
    j = 1
    @rowindex = Hash.new
    @rowheaders.each do |entry|
      j += 1
      @cal[j][0]["value"] = 0
      @cal[j][1]["value"] = entry.location
      @rowindex[entry.location] = j
    end
    logger.debug "rowindex- " + @rowindex.inspect

    # identify valid slots for display
    @slotsinfo.each do |myslot|
      thistime = myslot.timeslot.strftime("%Y-%m-%d %H:%M")
      @cal[@rowindex[myslot.location]][@colindex[thistime]]["slotid"] = myslot.id.to_s
    end 
    
    @sessinfo.each do |entry|
      logger.debug "entry- " + entry.inspect
#      thistime = entry.slot.timeslot.to_time.strftime("%Y-%m-%d %H:%M")
      thistime = entry.slot.timeslot.strftime("%Y-%m-%d %H:%M")
      logger.debug "thistime- " + thistime.inspect
      logger.debug "colindex- " + @colindex[thistime].inspect
      thislocation = entry.slot.location   
      logger.debug "thislocation- " + thislocation.inspect
      logger.debug "rowindex- " + @rowindex[thislocation].inspect
      unless @cal[@rowindex[thislocation]][@colindex[thistime]].key?('values') then  
        @cal[@rowindex[thislocation]][@colindex[thistime]]["values"]   = Array.new()
#        @cal[@rowindex[thislocation]][@colindex[thistime]]["students"] = Array.new()
      end
      @cal[@rowindex[thislocation]][@colindex[thistime]]["values"]   << entry
#      @cal[@rowindex[thislocation]][@colindex[thistime]]["students"] << @studenthash[entry.id]
      @cal[0][@colindex[thistime]]["value"] += 1
      @cal[@rowindex[thislocation]][0]["value"] += 1
    end
    logger.debug '@cal- ' + @cal.inspect
  end
end
