class CalendarController < ApplicationController
  include Calendarutilities
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
