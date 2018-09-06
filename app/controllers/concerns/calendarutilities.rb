#app/controllers/concerns/calendarutilities.rb
module Calendarutilities
  extend ActiveSupport::Concern

  # Note:
  #      includes -> minimum number of db queries
  #      joins    -> lazy loads the db query

  # -----------------------------------------------------------------------------
  # Obtain all the data from the database to display calendar or roster.
  #
  # Alternatice options to limit tutors or students based on status
  #
  # Quite a good document:
  # https://blog.carbonfive.com/2016/11/16/rails-database-best-practices/
  # 
  # -----------------------------------------------------------------------------
  #def calendar_read_display1f(sf, mystartdate, myenddate, options)
  #def calendar_read_display1f(sf, options)
  def calendar_read_display1f(options)
    #@sf = sf    # significant figures for ids used in browser display
    
    # Process parameters and set up the options.
    #
    mystartdate = options[:startdate]
    myenddate = options[:enddate]
    
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

    # @tutors and @students are used by the cal
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
    # b2) UNdesired tutor kinds
    reduce_tutrole_kind_exclude = lambda{
      @tutroleinfo = @tutroleinfo.reduce([]) { |a,o|
        unless tutor_kinds.include?(o.kind) then 
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
    # d) tutor with first aid certification into ids
    reduce_tutrole_firstaid = lambda{
      @tutroleinfo = @tutroleinfo.reduce([]) { |a,o|
        if(@tutor_index.has_key?(o.tutor_id))
          if @tutors[@tutor_index[o.tutor_id]].firstaid == 'yes' then 
            a << o
          end
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
    
    # need an index into @tutors for the sort
    # and for first aid lookup into tutors.
    # @tutors is already ordered by pname
    # so only have to return the index for the sort routine.
    @tutor_index = Hash.new
    unless @tutors == nil
      @tutors.each_with_index { |o, count|
        unless @tutor_index.has_key? o.id then
          @tutor_index[o.id] = Array.new
        end  
        @tutor_index[o.id] = count
      }
    end
    
    # now do reductions if generating a roster.
    if roster || ratio then    # if option = roster or ratio
      reduce_tutrole_firstaid.call      if(options.has_key?(:select_tutor_firstaid))
      reduce_tutrole_id.call            if(options.has_key?(:select_tutors) && tutor_ids != nil)
      reduce_tutrole_status.call        if(options.has_key?(:select_tutor_statuses) && tutor_statuses != nil) 
      reduce_tutrole_kind.call          if(options.has_key?(:select_tutor_kinds) && tutor_kinds != nil)
      reduce_tutrole_kind_exclude.call  if(options.has_key?(:select_tutor_kinds_exclude) && tutor_kinds != nil)
      reduce_role_id.call               if(options.has_key?(:select_students) && student_ids != nil)
      reduce_role_status.call           if(options.has_key?(:select_student_statuses) && student_statuses != nil) 
      reduce_role_kind.call             if(options.has_key?(:select_student_kinds) && student_kinds != nil) 
    end

    # these indexes are required if reduced or not - so done after reduction.
    # First, create the hash{lesson_id}[tutor_index_into array, .....]    
    @tutrole_lessonindex = Hash.new
    unless @tutroleinfo == nil
      @tutroleinfo.each_with_index { |o, count|
        unless @tutrole_lessonindex.has_key? o.lesson_id then
          @tutrole_lessonindex[o.lesson_id] = Array.new
        end  
        @tutrole_lessonindex[o.lesson_id].push(count)
      }
      # Sort all tutors within each session entry by pname
      @tutrole_lessonindex.each { |k, a|
        a = a.sort_by{ |t| @tutroleinfo[t].tutor.pname }
      }
    end 
    
    # Second, create the hash{lesson_id}[student_index_into array, .....]    
    @role_lessonindex = Hash.new
    unless @roleinfo == nil
      @roleinfo.each_with_index { |o, count|
        unless @role_lessonindex.has_key? o.lesson_id then
          @role_lessonindex[o.lesson_id] = Array.new
        end  
        @role_lessonindex[o.lesson_id].push(count)
      }
      # Sort all students within each session entry by pname
      @role_lessonindex.each { |k, a|
        a = a.sort_by{ |t| @roleinfo[t].student.pname }
      }
    end    
    # indexes completed.

    # Final reduction step, reduce the lesson array to eliminate lessons that have
    # no tutors or students of interest
    if roster then    # if option = roster               
      @sessinfo = @sessinfo.reduce([]) { |a,o|
        if ( @role_lessonindex.has_key?(o.id) ||
             @tutrole_lessonindex.has_key?(o.id)    )
          a << o
        end
        a
      }
    end
    
    # @sessinfo needs to be sorted in correct order as this will control the order
    # they are loaded into @cal. - for lesson order.
    # routing to sort the tutrole_lesson_index
    # by 1. lesson.status
    #    2. lesson.tutor.pname

    @sessinfo = @sessinfo.sort_by{ |o| [valueOrderStatus(o), valueOrderTutor(o)]}

    # ------- Now generate the hash for use in the display -----------
    # locations - there will be separate tables for each location
    @locations    = Slot
                  .select('location')
                  .distinct
                  .order('location')
                  .where(id: @slotsinfo.map {|o| o.id})
                  
    # Sort sites order by specific sequence
    # sequence requested by organiser - actually geographic locations
    #@sessinfo = @sessinfo.sort_by{ |o| [valueOrderStatus(o), valueOrderTutor(o)]}
    #byebug
    @locations = @locations.sort_by{ |o| valueOrderSite(o) }

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
  
  # Sort the values in display2 (cell of lessons/sessions) by status and then by tutor name
  # as some lessons have no tutor, this returns the tutor name if available.
  # This can then be used as the second attribute in the sort.
  def valueOrderTutor(obj)
    thistutorindexarray =  @tutrole_lessonindex[obj.id]
    if thistutorindexarray == nil
      return  100001
    end
    if thistutorindexarray.count > 0   # has tutor entries
      thisindex = @tutor_index[@tutroleinfo[thistutorindexarray[0]].tutor_id]
      if thisindex == nil
        return 100000
      else
       1 + @tutor_index[@tutroleinfo[thistutorindexarray[0]].tutor_id]
      end
    else
      return 100000
    end
  end
  
  def valueOrderStatus(obj)
    #logger.debug "obj status: " + obj.id.inspect + " - " + obj.status
    if obj.status != nil
      thisindex = ["onCall", "onSetup", "free", "on_BFL", "standard",
                   "routine", "flexible", "allocte", "global", "park"].index(obj.status)
      thisindex == nil ? 0 : thisindex + 1
    else
      return 0
    end
  end
  
  # used to order the sites - provided as geographic locations.
  def valueOrderSite(obj)
    #logger.debug "obj status: " + obj.id.inspect + " - " + obj.status
    if obj.location != nil
      thisindex = ["GUNGAHLIN", "KALEEN", "DICKSON", "WODEN", "KAMBAH",
                   "ERINDALE", "CALWELL"].index(obj.location)
      thisindex == nil ? 0 : thisindex + 1
    else
      return 0
    end
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
  
   # -----------------------------------------------------------------------------
 # Generate stats.
 #
 # Starting with the standard @cal hash, add in the tutor / student ratio
 # Stats recorded are:
 # For both routine and flexible sessions:- 
 #  S     Sessions
 #  R     Rostered = Scheduled, Notified, Confirmed, Attended
 #  RoTo  Rostered One to one
 #  RCu   Rostered Catchup
 #  RCoTo Rostered Catchup One to one
 # 
 # Also required for routine sessions:- 
 #  A     Away or Absent
 #  AoTo  Away One to one
 #  B     Bye = fortnightly bye session, normal would be Rostered
 #
 # Formulas:
 # For routine sessons:-
 #  free Routine = availability of sessions for permanment allocations
 #  = 2S-A-R+RCu-RoTo-AoTo+RCoTo-B
 #
 #  free Catch Up = sessions where catch ups can be allocated
 #  = A+AoTo+B-RCu-RCoTo
 #
 # For routine sessons:-
 #  free Catch Up = sessons where catch ups can be allocated
 #  = 2S-R-RoTo
 #
 #  Note: free routine sessions do on exist for flexible sessions.
 # -----------------------------------------------------------------------------
  def generate_stats
    # step through each site
    @all_sites_ratio = {'tutor_count'=>0, 'student_count'=>0}
    @cal.each do |location, calLocation|
      calLocation.each_with_index do |rows, rowindex|
        logger.debug "next row - " + rowindex.to_s
        rows.each_with_index do |cells, colindex|
          logger.debug "next cell - " + colindex.to_s 
          if cells.key?("values") then  # in a slot with lessons
            rS = rR = rA = rAoTo = rRoTo = rRCu = rRCoTo = rB = 0
            fS = fR = fRoTo = fRCu = fRCoTo = 0
            flagFlexible = flagRoutine = false
            flagRostered = false
            slottutorcount = slotstudentcount = 0
            cells["values"].each do |entry|  # go through each lesson
              logger.debug "entry: " + entry.inspect
              if(entry.status == "standard" ||
                 entry.status == "routine")
                flagRoutine = true
                rS += 1
              elsif entry.status == "flexible"
                flagFlexible = true
                fS += 1
              end
              if @tutrole_lessonindex.has_key? entry.id then  # check for tutroles linked to this lesson
                # could be multiple tutors in this lesson, a tutrole for each - need to step through each one
                #logger.debug "tutroles_lessonindex has an entry for this lesson with tutrole indexes into the array of: " +
                #             @tutrole_lessonindex[entry.id].inspect
                @tutrole_lessonindex[entry.id].each do |thistutorrole|  # check each tutrole for diagnostics
                  # slottutorcount is for ratio calculations
                  # Ratios are only calculated using BFL, Routine and Flexible lessons
                  #slottutorcount += @tutrole_lessonindex[entry.id].count
                  if(["scheduled", "notified", "confirmed", "attended"].include?@tutroleinfo[thistutorrole].status)  # valid statuses for ratio calculations
                    slottutorcount += 1 if(['on_BFL', 'standard', 'routine', 'flexible'].include?entry.status) # valid lessons for rations
                  end
                  logger.debug "tutor found - tutrole: " + @tutroleinfo[thistutorrole].inspect
                end
              end
              if @role_lessonindex.has_key? entry.id then  # check for students
                logger.debug "student found: " + @role_lessonindex[entry.id].inspect
                # for ratio calculation
                # slotstudentcount += @role_lessonindex[entry.id].count
                @role_lessonindex[entry.id].each do |thisstudentrole|  # check each tutrole for diagnostics
                  #logger.debug "student found - role: " + @roleinfo[thisstudentrole].inspect
                  thisstudent = @roleinfo[thisstudentrole].student
                  #logger.debug "thisstudent: " + thisstudent.inspect
                  thisrole = @roleinfo[thisstudentrole]
                  thisstudent = thisrole.student
                  if(["scheduled", "attended"].include?thisrole.status)     # rostered
                    flagRostered = true
                    slotstudentcount += 1  if(['on_BFL', 'standard', 'routine', 'flexible'].include?entry.status)  # supporting ratio status
                    rR += 1 if flagRoutine
                    fR += 1 if flagFlexible
                    if(["onetoone"].include?thisstudent.status)
                      rRoTo += 1 if flagRoutine
                      fRoTo += 1 if flagFlexible
                    end
                    if(["catchup"].include?thisrole.kind)
                      rRCu += 1 if flagRoutine
                      fRCu += 1 if flagFlexible
                      if(["onetoone"].include?thisstudent.status)
                        rRCoTo += 1 if flagRoutine
                        fRCoTo += 1 if flagFlexible
                      end        
                    end
                  elsif(["bye"].include?thisrole.status)
                    rB += 1 if flagRoutine
                  elsif(["away", "absent"].include?thisrole.status)
                    rA += 1 if flagRoutine
                    if(["onetoone"].include?thisstudent.status)
                      rAoTo += 1 if flagRoutine
                    end        
                  end
                end
              end
            end
            # keep stats in the cell/slot data
            freeRoutine = 2*rS-rA-rR+rRCu-rRoTo-rAoTo+rRCoTo-rB
            freeCatchup = rA+rAoTo+rB-rRCu-rRCoTo
            flexCatchup = 2*fS-fR-fRoTo
            cells["stats"] = {
                              "routine"=>{
                                           'S'       =>rS,
                                           'R'       =>rR,
                                           'RoTo'    =>rRoTo,
                                           'A'       =>rA,
                                           'AoTo'    =>rAoTo,
                                           'RCu'     =>rRCu,
                                           'RCoTo'   =>rRCoTo,
                                           'B'       =>rB,
                                           'Free'    =>freeRoutine,
                                           'Catchup' =>freeCatchup
                                         },
                              "flexible"=>{
                                           'S'       =>fS,
                                           'R'       =>fR,
                                           'RoTo'    =>fRoTo,
                                           'RCu'     =>fRCu,
                                           'RCoTo'   =>fRCoTo,
                                           'Catchup' =>flexCatchup
                                         }
                              }

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