#app/controllers/concerns/calendarutilities.rb
module Calendarutilities
  extend ActiveSupport::Concern

  # Note:
  #      includes -> minimum number of db queries
  #      joins    -> lazy loads the db query

  # Obtain all the data from the database to display calendar2.
  def calendar_read_display2(sf, mystartdate, myenddate)
    @sf = sf    # significant figures for ids used in browser display
    
    # define a two dimesional array to hold the table info to be displayed.
    # row and column [0] will hold counts of elements populated in that row or column
    # row and column [1] will hold the titles for that rolw or column.
    # tip: 'joins' does lazy load, 'include' minimises sql calls

                   #.joins(:slot)

                   #.includes(:slot)
                   #.references(:slot)
                   
                   #.eager_load(:slot)

    @sessinfo1      = Lesson
                   .joins(:slot)
                   .where("slots.timeslot >= :start_date AND
                           slots.timeslot < :end_date",
                          {start_date: mystartdate,
                           end_date: myenddate
                          })

    @sessinfo = @sessinfo1.eager_load(:slot, :tutroles, :tutors, :roles, :students)

    @slotsinfo     = Slot 
                   .select('id, timeslot, location')
                   .where("timeslot >= :start_date AND
                          timeslot < :end_date",
                          {start_date: mystartdate,
                           end_date: myenddate
                          })
              
    # locations - there will be separate tables for each location
    @locations    = Slot
                  .select('location')
                  .distinct
                  .order('location')
                  .where("timeslot >= :start_date AND
                          timeslot < :end_date",
                          {start_date: mystartdate,
                           end_date: myenddate
                          })
                  
    #column headers will be the days - two step process to get these
    @datetimes = Slot
                  .select('timeslot')
                  .distinct
                  .order('timeslot')
                  .where("timeslot >= :start_date AND
                          timeslot < :end_date",
                          {start_date: mystartdate,
                           end_date: myenddate
                          })
                  
    @colheaders = Hash.new()
    @datetimes.each do |datetime|
      mydate = datetime.timeslot.strftime("%Y-%m-%d")
      @colheaders[mydate] = datetime.timeslot.strftime("%a-%Y-%m-%d")
    end

    # row headers will be the lesson times for the day - already have unique slots               
    @rowheaders = Hash.new()
    @datetimes.each do |datetime|
      mytime = datetime.timeslot.strftime("%H-%M")
      @rowheaders[mytime] = datetime.timeslot.strftime("%I-%M %p")
    end

    @cal = Hash.new()
    @locations.each do |l|
      @cal[l.location] = Array.new(1 + @rowheaders.count){Array.new(1 + @colheaders.count){Hash.new()}}
      @cal[l.location][0][0]["value"] = l.location    # put in the site name.
      @cal[l.location][0][0]["days"] = Hash.new(0)       # put in days that have sessions.
    end

    i = 0
    @colindex = Hash.new
    @colheaders.keys.each do |entry|        # lesson times
      i += 1
      @locations.each do |l|
        @cal[l.location][0][i]["value"] = @colheaders[entry]
      end
      @colindex[entry] = i
    end

    j = 0
    @rowindex = Hash.new
    @rowheaders.sort_by { |key1, value1| key1 }.each do |key, value|   # lesson day
      j += 1
      @locations.each do |l|
        @cal[l.location][j][0]["value"] = value
      end
      @rowindex[key] = j
    end
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

    @sessinfo.each do |entry|
      thisdate = entry.slot.timeslot.strftime("%Y-%m-%d")
      thistime = entry.slot.timeslot.strftime("%H-%M")
      thislocation = entry.slot.location
      unless @cal[thislocation][@rowindex[thistime]][@colindex[thisdate]].key?('values') then  
        @cal[thislocation][@rowindex[thistime]][@colindex[thisdate]]["values"]   = Array.new()
      end
      @cal[thislocation][@rowindex[thistime]][@colindex[thisdate]]["values"]   << entry
      @cal[thislocation][0][0]["days"][entry.slot.timeslot.strftime("%a-%Y-%m-%d")] += 1    # put in days that have sessions.
    end
    
    return @cal

  end

 # -----------------------------------------------------------------------------
 # Obtain all the data from the database to display calendar or roster.
 #
 # Alternatice options to limit tutors or students based on status
 #
 # Quite a good document:
 # https://blog.carbonfive.com/2016/11/16/rails-database-best-practices/
 # 
 # -----------------------------------------------------------------------------
  def calendar_read_display1f(sf, mystartdate, myenddate, options)
    @sf = sf    # significant figures for ids used in browser display
    
    roster = options.has_key?(:roster) ? true : false
    #roster = true
    # define a two dimesional array to hold the table info to be displayed.
    # row and column [0] will hold counts of elements populated in that row or column
    # row and column [1] will hold the titles for that rolw or column.
    # tip: 'joins' does lazy load, 'include' minimises sql calls

    @slotsinfo     = Slot 
                   .select('id, timeslot, location')
                   .where("timeslot >= :start_date AND
                          timeslot < :end_date",
                          {start_date: mystartdate,
                           end_date: myenddate
                          })

    @sessinfo      = Lesson
                   .joins(:slot)
                   .where(slot_id: @slotsinfo.map {|o| o.id})
                   .order(:status)
                   .includes(:slot)

    @tutroleinfo = Tutrole
                   .joins(:tutor, :lesson)
                   .where(lesson_id: @sessinfo.map {|o| o.id})
                   .order('kind, tutors.pname')
                   .includes(:tutor, :lesson)
    
    # Some code to reduce this array 
    # - eliminate categories of tutors that are not of interest.

    if roster then    // if option = roster               
      @tutroleinfo = @tutroleinfo.reduce([]) { |a,o|
        if ['attended', 'notified', 'scheduled'].include?(o.status) then 
          a << o
        end
        a
      }
    end
    
    # now create the hash{lesson_id}[tutor_index_into array, .....]    
    @tutrole_lessonindex = Hash.new
    @tutroleinfo.each_with_index { |o, count|
      unless @tutrole_lessonindex.has_key? o.lesson_id then
        @tutrole_lessonindex[o.lesson_id] = Array.new
      end  
      @tutrole_lessonindex[o.lesson_id].push(count)
    }

    @roleinfo    = Role
                   .joins(:student, :lesson)
                   .where(lesson_id: @sessinfo.map {|o| o.id})
                   .order('students.pname')
                   .includes(:student, :lesson)
                   
    # Now some code to reduce this array 
    # - eliminate categories of tutors or students that are not of interest.
    if roster then    // if option = roster               
      @roleinfo = @roleinfo.reduce([]) { |a,o|
        if ['attended', 'notified', 'scheduled'].include?(o.status) then 
          a << o
        end
        a
      }
    end
                   
    # now create the hash{lesson_id}[student_index_into array, .....]    
    @role_lessonindex = Hash.new
    @roleinfo.each_with_index { |o, count|
      unless @role_lessonindex.has_key? o.lesson_id then
        @role_lessonindex[o.lesson_id] = Array.new
      end  
      @role_lessonindex[o.lesson_id].push(count)
    }
    
    # We can now reduce the lesson array to eliminate lessons that have
    # no tutors or students of interest
    if roster then    // if option = roster               
      @sessinfo = @sessinfo.reduce([]) { |a,o|
        if (    @role_lessonindex.has_key?(o.id) ||
             @tutrole_lessonindex.has_key?(o.id)    )
          a << o
        end
        a
      }
    end
    
    # locations - there will be separate tables for each location
    @locations    = Slot
                  .select('location')
                  .distinct
                  .order('location')
                  .where(id: @slotsinfo.map {|o| o.id})
                  
    #column headers will be the days - two step process to get these
    @datetimes = Slot
                  .select('timeslot')
                  .distinct
                  .order('timeslot')
                  .where(id: @slotsinfo.map {|o| o.id})
 
    @colheaders = Hash.new()
    @datetimes.each do |datetime|
      mydate = datetime.timeslot.strftime("%Y-%m-%d")
      @colheaders[mydate] = datetime.timeslot.strftime("%a-%Y-%m-%d")
    end

    # row headers will be the lesson times for the day - already have unique slots               
    @rowheaders = Hash.new()
    @datetimes.each do |datetime|
      mytime = datetime.timeslot.strftime("%H-%M")
      @rowheaders[mytime] = datetime.timeslot.strftime("%I-%M %p")
    end

    @cal = Hash.new()
    @locations.each do |l|
      @cal[l.location] = Array.new(1 + @rowheaders.count){Array.new(1 + @colheaders.count){Hash.new()}}
      @cal[l.location][0][0]["value"] = l.location    # put in the site name.
      @cal[l.location][0][0]["days"] = Hash.new(0)       # put in days that have sessions.
    end

    i = 0
    @colindex = Hash.new
    @colheaders.keys.each do |entry|        # lesson times
      i += 1
      @locations.each do |l|
        @cal[l.location][0][i]["value"] = @colheaders[entry]
      end
      @colindex[entry] = i
    end

    j = 0
    @rowindex = Hash.new
    @rowheaders.sort_by { |key1, value1| key1 }.each do |key, value|   # lesson day
      j += 1
      @locations.each do |l|
        @cal[l.location][j][0]["value"] = value
      end
      @rowindex[key] = j
    end

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

    @sessinfo.each do |entry|
      thisdate = entry.slot.timeslot.strftime("%Y-%m-%d")
      thistime = entry.slot.timeslot.strftime("%H-%M")
      thislocation = entry.slot.location
      unless @cal[thislocation][@rowindex[thistime]][@colindex[thisdate]].key?('values') then  
        @cal[thislocation][@rowindex[thistime]][@colindex[thisdate]]["values"]   = Array.new()
      end
      @cal[thislocation][@rowindex[thistime]][@colindex[thisdate]]["values"]   << entry
      @cal[thislocation][0][0]["days"][entry.slot.timeslot.strftime("%a-%Y-%m-%d")] += 1    # put in days that have sessions.
    end

    return @cal

  end

end