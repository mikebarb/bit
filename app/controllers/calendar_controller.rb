class CalendarController < ApplicationController
  def display2
    @sf = 3   # number of significant figures in dom ids for session,tutor, etc.
    @site = "Kaleen"
    # define a two dimesional array to hold the table info to be displayed.
    # row and column [0] will hold counts of elements populated in that row or column
    # row and column [1] will hold the titles for that rolw or column.

    @sessinfo      = Session.all
    logger.debug "calendar display - (sessinfo) " + @sessinfo.inspect

    @slotsinfo     = Slot 
                  .select('id, timeslot, location')         
              
    # locations - there will be separate tables for each location
    @locations    = Slot
                  .select('location')
                  .distinct

   logger.debug '@locations- ' + @locations.inspect


    #column headers will be the days - two step process to get these
    @datetimes = Slot
                  .select('timeslot')
                  .distinct
                  
    @colheaders = Hash.new()
    @datetimes.each do |datetime|
      mydate = datetime.timeslot.strftime("%Y-%m-%d")
      @colheaders[mydate] = datetime.timeslot.strftime("%a-%Y-%m-%d")
    end
    logger.debug "@colheaders: " + @colheaders.inspect

    # row headers will be the session times for the day - allready have unique slots               
    @rowheaders = Hash.new()
    @datetimes.each do |datetime|
      mytime = datetime.timeslot.strftime("%H-%M")
      @rowheaders[mytime] = datetime.timeslot.strftime("%I-%M %p")
    end
    logger.debug "@rowheaders: " + @rowheaders.inspect

    logger.debug '@rowheaders.count: ' + @rowheaders.count.inspect
    logger.debug '@colheaders.count: ' + @colheaders.count.inspect
    
    #@cal1 = Array.new(1 + @rowheaders.count){Array.new(1 + @colheaders.count){Hash.new()}}
    #logger.debug 'cal1: ' + @cal1.inspect
    
    @cal = Hash.new()
    @locations.each do |l|
      @cal[l.location] = Array.new(1 + @rowheaders.count){Array.new(1 + @colheaders.count){Hash.new()}}
      @cal[l.location][0][0]["value"] = l.location    # put in the site name.
    end
    #logger.debug 'cal: ' + @cal.inspect



    i = 0
    @colindex = Hash.new
    @colheaders.keys.each do |entry|
      #logger.debug 'entry: ' + entry.inspect
      i += 1
      @locations.each do |l|
        #logger.debug 'in colheaders loop => l: ' + l.location.inspect
        #@cal1[0][i]["value"] = @colheaders[entry]
        #logger.debug 'in colheaders loop => @cal[l.location]: ' + @cal[l.location].inspect
        @cal[l.location][0][i]["value"] = @colheaders[entry]
      end
      @colindex[entry] = i
    end
    logger.debug "colindex- " + @colindex.inspect
    logger.debug 'cal: ' + @cal.inspect
   
    j = 0
    @rowindex = Hash.new
    @rowheaders.each do |key, value|
      logger.debug 'rowindex loop - entry: ' + key.inspect + "  " + value.inspect
      j += 1
      @locations.each do |l|
        @cal[l.location][j][0]["value"] = value
      end
      @rowindex[key] = j
    end
    logger.debug "rowindex- " + @rowindex.inspect
    logger.debug 'cal: ' + @cal.inspect
    logger.debug '---------- now do the slots --------------------'
    # identify valid slots for display
    # first need to split out the location, date and time
    @slotsinfo.each do |myslot|
      mydate = myslot.timeslot.strftime("%Y-%m-%d")
      mytime = myslot.timeslot.strftime("%H-%M")
      mylocation = myslot.location
      
      #thistime = myslot.timeslot.strftime("%Y-%m-%d %H:%M")
      @cal[mylocation][@rowindex[mytime]][@colindex[mydate]]["slotid"] = myslot.id.to_s
      @cal[mylocation][@rowindex[mytime]][@colindex[mydate]]["id_dom"] = 
                  myslot.location[0, 3].ljust(3, "-") + myslot.timeslot.strftime("%Y%m%d%H%M")
    end 
    logger.debug 'cal: ' + @cal.inspect
    
    logger.debug '---------- now do the sessions --------------------'
    @sessinfo.each do |entry|
      logger.debug "entry- " + entry.inspect

      thisdate = entry.slot.timeslot.strftime("%Y-%m-%d")
      thistime = entry.slot.timeslot.strftime("%H-%M")
      thislocation = entry.slot.location
      
      #thistime = entry.slot.timeslot.strftime("%Y-%m-%d %H:%M")
      logger.debug "thisdate- " + thisdate.inspect
      logger.debug "colindex- " + @colindex[thisdate].inspect
      #thislocation = entry.slot.location
      logger.debug "thistime- " + thistime.inspect
      logger.debug "rowindex- " + @rowindex[thistime].inspect
      logger.debug "thislocation- " + thislocation.inspect

      unless @cal[thislocation][@rowindex[thistime]][@colindex[thisdate]].key?('values') then  
        @cal[thislocation][@rowindex[thistime]][@colindex[thisdate]]["values"]   = Array.new()
      end
      @cal[thislocation][@rowindex[thistime]][@colindex[thisdate]]["values"]   << entry

    end
    logger.debug '@cal- ' + @cal.inspect
  end
  
  #=============================================================================================
  # original one follows
  #=============================================================================================

  def display
    @sf = 3   # number of significant figures in dom ids for session,tutor, etc.
    @hall = "Kaleen"
    # define a two dimesional array to hold the table info to be displayed.
    # row and column [0] will hold counts of elements populated in that row or column
    # row and column [1] will hold the titles for that rolw or column.

    @sessinfo      = Session.all
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
