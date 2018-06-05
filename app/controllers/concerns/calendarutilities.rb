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
    
    # Process parameters and set up the options.
    #
    roster = options.has_key?(:roster) ? true : false
    ratio = options.has_key?(:ratio) ? true : false
    if roster || ratio
        tutor_statuses = options[:tutor_statuses] if options.has_key?(:tutor_statuses)
        student_statuses = options[:student_statuses] if options.has_key?(:student_statuses)
  
        tutor_kinds = options[:tutor_kinds] if options.has_key?(:tutor_kinds)
        student_kinds = options[:student_kinds] if options.has_key?(:student_kinds)

        tutor_ids = options[:tutor_ids] if options.has_key?(:tutor_ids)
        student_ids = options[:student_ids] if options.has_key?(:student_ids)
    end




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

    @roleinfo    = Role
                   .joins(:student, :lesson)
                   .where(lesson_id: @sessinfo.map {|o| o.id})
                   .order('students.pname')
                   .includes(:student, :lesson)
    
    # Some code to reduce tutrole and role arrays
    # - eliminate categories of people that are not of interest.
    # This reduces tutors to ones with 
    # a) desired tutor statuses
    reduce_tutrole_status = lambda{
      @tutroleinfo = @tutroleinfo.reduce([]) { |a,o|
        if tutor_statuses.include?(o.status) then 
          a << o
        end
        a
      }
    }
    # b) desired tutor kinds
    reduce_tutrole_kind = lambda{
      @tutroleinfo = @tutroleinfo.reduce([]) { |a,o|
        if tutor_kinds.include?(o.kind) then 
          a << o
        end
        a
      }
    }
    # c) desired tutor ids
    reduce_tutrole_id = lambda{
      @tutroleinfo = @tutroleinfo.reduce([]) { |a,o|
        if tutor_ids.include?(o.tutor_id) then 
          a << o
        end
        a
      }
    }
    # This reduces students to ones with
    # a) desired student statuses
    reduce_role_status = lambda{
      @roleinfo = @roleinfo.reduce([]) { |a,o|
        if student_statuses.include?(o.status) then 
          a << o
        end
        a
      }
    }
    # b) desired student kinds
    reduce_role_kind = lambda{
      @roleinfo = @roleinfo.reduce([]) { |a,o|
        if student_kinds.include?(o.kind) then 
          a << o
        end
        a
      }
    }
    # c) desired students
    reduce_role_id = lambda{
      @roleinfo = @roleinfo.reduce([]) { |a,o|
        if student_ids.include?(o.student_id) then 
          a << o
        end
        a
      }
    }

    # now do reductions if generating a roster.
    if roster || ratio then    # if option = roster or ratio
      reduce_tutrole_id.call     if(options.has_key?(:select_tutors) && tutor_ids != nil)
      reduce_tutrole_status.call if(options.has_key?(:select_tutor_statuses) && tutor_statuses != nil) 
      reduce_tutrole_kind.call   if(options.has_key?(:select_tutor_kinds) && tutor_kinds != nil)
      
      reduce_role_id.call     if(options.has_key?(:select_students) && student_ids != nil)
      reduce_role_status.call if(options.has_key?(:select_student_statuses) && student_statuses != nil) 
      reduce_role_kind.call   if(options.has_key?(:select_student_kinds) && student_kinds != nil) 
    end

    # these indexes are required if reduced or not - so done after reduction.
    # First, create the hash{lesson_id}[tutor_index_into array, .....]    
    @tutrole_lessonindex = Hash.new
    @tutroleinfo.each_with_index { |o, count|
      unless @tutrole_lessonindex.has_key? o.lesson_id then
        @tutrole_lessonindex[o.lesson_id] = Array.new
      end  
      @tutrole_lessonindex[o.lesson_id].push(count)
    }
    # Second, create the hash{lesson_id}[student_index_into array, .....]    
    @role_lessonindex = Hash.new
    @roleinfo.each_with_index { |o, count|
      unless @role_lessonindex.has_key? o.lesson_id then
        @role_lessonindex[o.lesson_id] = Array.new
      end  
      @role_lessonindex[o.lesson_id].push(count)
    }
    # indexes completed.

    # Final reduction step, reduce the lesson array to eliminate lessons that have
    # no tutors or students of interest
    if roster then    // if option = roster               
      @sessinfo = @sessinfo.reduce([]) { |a,o|
        if ( @role_lessonindex.has_key?(o.id) ||
             @tutrole_lessonindex.has_key?(o.id)    )
          a << o
        end
        a
      }
    end

    # ------- Now generate the hash for use in the display -----------
    
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

 # -----------------------------------------------------------------------------
 # Generate ratios.
 #
 # Starting with the standard @cal hash, add in the tutor / student ratio
 # 
 # -----------------------------------------------------------------------------
  def generate_ratios
    # step through each site
    @all_sites_ratio = {'tutor_count'=>0, 'student_count'=>0}
    @cal.each do |location, calLocation|
      calLocation.each_with_index do |rows, rowindex|
        logger.debug "next row - " + rowindex.to_s
        rows.each_with_index do |cells, colindex|
          logger.debug "next cell - " + colindex.to_s 
          if cells.key?("values") then  # in a slot with lessons
            slottutorcount = slotstudentcount = 0
            cells["values"].each do |entry|  # go thorugh each lesson
              logger.debug "entry: " + entry.inspect
              if @tutrole_lessonindex.has_key? entry.id then  # check for tutroles linked to this lesson
                # could be multiple tutors in this lesson, a tutrole for each - need to step through each one
                logger.debug "tutroles_lessonindex has an entry for this lesson with tutrole indexes into the array of: " +
                             @tutrole_lessonindex[entry.id].inspect
                slottutorcount += @tutrole_lessonindex[entry.id].count
                @tutrole_lessonindex[entry.id].each do |thistutor|  # check each tutrole for diagnostics
                  logger.debug "tutor found - tutrole: " + @tutroleinfo[thistutor].inspect
                end
              end
              if @role_lessonindex.has_key? entry.id then  # check for students
                logger.debug "student found: " + @role_lessonindex[entry.id].inspect
                slotstudentcount += @role_lessonindex[entry.id].count 
                @role_lessonindex[entry.id].each do |thisstudent|  # check each tutrole for diagnostics
                  logger.debug "student found - role: " + @roleinfo[thisstudent].inspect
                end
              end
            end
            # keep counts in the cell/slot data
            cells["ratio"] = {'tutor_count'=>slottutorcount, 'student_count'=>slotstudentcount}
            rows[0]['ratio'] = {'tutor_count'=>0, 'student_count'=>0} unless rows[0].has_key?("ratio") 
            rows[0]['ratio']['tutor_count']   += slottutorcount
            rows[0]['ratio']['student_count'] += slotstudentcount
            calLocation[0][colindex]['ratio'] = {'tutor_count'=>0, 'student_count'=>0} unless calLocation[0][colindex].has_key?("ratio")
            calLocation[0][colindex]['ratio']['tutor_count']   += slottutorcount
            calLocation[0][colindex]['ratio']['student_count'] += slotstudentcount
            calLocation[0][0]['ratio'] = {'tutor_count'=>0, 'student_count'=>0} unless calLocation[0][0].has_key?("ratio")
            calLocation[0][0]['ratio']['tutor_count']   += slottutorcount
            calLocation[0][0]['ratio']['student_count'] += slotstudentcount
            @all_sites_ratio['tutor_count']   += slottutorcount
            @all_sites_ratio['student_count'] += slotstudentcount
          end
        end
      end
    end
  end
end