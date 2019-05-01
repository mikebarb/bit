#app/controllers/concerns/calendarutilities.rb
module Calendarutilities
  extend ActiveSupport::Concern

  # Note:
  #      includes -> minimum number of db queries
  #      joins    -> lazy loads the db query

  # -----------------------------------------------------------------------------
  # Obtain all the data from the database to display calendar or roster.
  #
  # Alternative options to limit tutors or students based on status
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

        #tutor_ids = options[:tutor_ids].map{|o| o.class == 'string' ? o.to_i : o} if options.has_key?(:tutor_ids)
        if options.has_key?(:tutor_ids)
          tutor_ids = options[:tutor_ids]
          if tutor_ids.class != Array
            tutor_ids = [tutor_ids]
          end
          tutor_ids = tutor_ids.map{|o| o.class == String ? o.to_i : o} 
        end

        if options.has_key?(:student_ids)
          student_ids = options[:student_ids]
          if student_ids.class != Array
            student_ids = [student_ids]
          end
          student_ids = student_ids.map{|o| o.class == String ? o.to_i : o} 
        end
    end
    
    # define a two dimesional array to hold the table info to be displayed.
    # row and column [0] will hold counts of elements populated in that row or column
    # row and column [1] will hold the titles for that rolw or column.
    # tip: 'joins' does lazy load, 'include' minimises sql calls

    # @tutors and @students are used by the cal
    if options.has_key?(:slot_ids)
      @slotsinfo     = Slot 
                     .select('id, timeslot, location')
                     .where(id: options[:slot_ids])
    else   # slots controlled by date range
      @slotsinfo     = Slot 
                     .select('id, timeslot, location')
                     .where("timeslot >= :start_date AND
                            timeslot < :end_date",
                            {start_date: mystartdate,
                             end_date: myenddate
                            })
    end
    @sessinfo      = Lesson
                     .joins(:slot)
                     .where(slot_id: @slotsinfo.map {|o| o.id})
                     .order(:status)
                     .includes(:slot)

    # when a 'allocate' lesson is added as part of this process,
    # we want to reread the database again to get all lessons.
    whilecountlimit = 2             # safety net - if 'allocate' lessons not added.
    flagAllocateAddedToSlot = true  # trick to force first loop.
    #while(flagAllocateAddedToSlot && whilecountlimit > 0) do
      whilecountlimit -= 1
      @sessinfo      = Lesson
                     .joins(:slot)
                     .where(slot_id: @slotsinfo.map {|o| o.id})
                     .order(:status)
                     .includes(:slot)
  
      # check that all slots have an allocate session!
      # required in the stats page for allocating catchups to a slot
      @slotallocate = Hash.new
      @sessinfo.each do |thissession| 
        if(thissession.status == 'allocate')
          @slotallocate[thissession.slot.id] = thissession.id
        end
      end
      # now check that all slots have an allocate session(lesson)
      flagAllocateAddedToSlot = false
      @slotAllocateLessonDom_id = Hash.new
      @slotsinfo.each do |thisslot|
        if @slotallocate.has_key?(thisslot.id)   # allocate present in this slot
          # add an allocate lesson for this slot
          # determine dom_id for slot where new allocate lesson is to be placed.
          #dom_id = location + datetime + lesson + student
          slot_dom_id = thisslot.location[0..2].upcase + 
                        thisslot.timeslot.strftime("%Y%m%d%H%M") +
                        'l' + thisslot.id.to_s.rjust(@sf, "0") +
                        'n' + @slotallocate[thisslot.id].to_s.rjust(@sf, "0")
          @slotAllocateLessonDom_id[thisslot.id] = slot_dom_id
        else    # no 'allocate' in this slot -> create one. 
          # add an allocate lesson for this slot
          # determine dom_id for slot where new allocate lesson is to be placed.
          #dom_id = location + datetime + lesson + student
          slot_dom_id = thisslot.location[0..2].upcase + 
                        thisslot.timeslot.strftime("%Y%m%d%H%M") +
                        'l' + thisslot.id.to_s.rjust(@sf, "0")
          #logger.debug "add lesson allocate to slot " + slot_dom_id
          #----------------------------------
          # !!!!!!! Add code here !!!!!!!!!!
          #----------------------------------
          flagAllocateAddedToSlot = true
        end
      end
    #end        # of while loop

    #@slotAllocateLessonDom_id[slot_id] = Dom_id of the allocate lesson.
    #logger.debug "+++++++++++++++++++++++++++@slotAllocateLessonDom_id: " + @slotAllocateLessonDom_id.inspect

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
                   #.select("student_id", "students.pname", "students.status", "students.kind")

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
        match = @colheaders[entry].match(/-(\d+-\d+-\d+)/)
        @cal[l.location][0][i]["datetime"] = DateTime.strptime(match[1], "%Y-%m-%d")
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
      if obj.location =~ /oncall/i 
        thisindex = 0
      else
        thisindex = ["GUNGAHLIN", "KALEEN", "DICKSON", "WODEN", "KAMBAH",
                     "ERINDALE", "CALWELL",
                     "ASHFIELD", "STANMORE"].index(obj.location)
        thisindex == nil ? 2 : thisindex + 3
      end
    else
      return 1
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
        #logger.debug "next row - " + rowindex.to_s
        rows.each_with_index do |cells, colindex|
          #logger.debug "next cell - " + colindex.to_s 
          if cells.key?("values") then  # in a slot with lessons
            slottutorcount = slotstudentcount = 0
            cells["values"].each do |entry|  # go thorugh each lesson
              #logger.debug "entry: " + entry.inspect
              if @tutrole_lessonindex.has_key? entry.id then  # check for tutroles linked to this lesson
                # could be multiple tutors in this lesson, a tutrole for each - need to step through each one
                #logger.debug "tutroles_lessonindex has an entry for this lesson with tutrole indexes into the array of: " +
                #             @tutrole_lessonindex[entry.id].inspect
                slottutorcount += @tutrole_lessonindex[entry.id].count
                #@tutrole_lessonindex[entry.id].each do |thistutor|  # check each tutrole for diagnostics
                  #logger.debug "tutor found - tutrole: " + @tutroleinfo[thistutor].inspect
                #end
              end
              if @role_lessonindex.has_key? entry.id then  # check for students
                #logger.debug "student found: " + @role_lessonindex[entry.id].inspect
                slotstudentcount += @role_lessonindex[entry.id].count 
                #@role_lessonindex[entry.id].each do |thisstudent|  # check each tutrole for diagnostics
                  #logger.debug "student found - role: " + @roleinfo[thisstudent].inspect
                #end
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
  # student_stats 
  # Generate student stats
  # Obtain stats on all the students in global for display on the stats page.
  # Pulled out separately so can do a ajax call on it.
  #
  # return: @students_stats    - a object hash available to the renderee
  #                              by stats_students
  # -----------------------------------------------------------------------------
  def student_stats
    # Want all the global lessons with their students
    global_students = Student.includes(:lessons, :roles)
                       .where(:lessons => {status: 'global'})
                       .order(:pname)
    alllessons = Hash.new
    global_students.each do |student|
      student.lessons.each do |lesson|
        unless(alllessons.key?(lesson.id))
          alllessons[lesson.id] = 0         # initialise
        end
        alllessons[lesson.id] += 1          # count
      end
    end
    # get all the global lessons containing these students
    alllessons_ids = alllessons.keys
    global_lessons_with_slots = Lesson.where(id: alllessons_ids ).includes(:slot)
    global_lessons_with_slots_index = Hash.new
    global_lessons_with_slots.each do |l|
      global_lessons_with_slots_index[l.id] = l 
    end
        
    @students_stats = Hash.new
    global_students.each do |student|
      unless(@students_stats.key?(student.id))
        @students_stats[student.id] = Hash.new
        @students_stats[student.id]['total'] = 0
        @students_stats[student.id]['dom_ids'] = Array.new
        @students_stats[student.id]['role_kind'] = Array.new
      end
      @students_stats[student.id]['student_object'] = student
      studentlessons = Array.new
      student.lessons.each do |lesson| 
        studentlessons.push([lesson, lesson.slot.timeslot])
      end
      #student.lessons.each_with_index do |lesson, i|
      studentlessons.sort{|x,y| x[1] <=> y[1]}.each_with_index do |a, i|
        #byebug if student.pname == 'Eliza McGill'
        lesson = a[0]
        unless(@students_stats[student.id].key?(lesson.id))
          @students_stats[student.id][lesson.id] = Hash.new
        end
        @students_stats[student.id]['total'] += 1
        @students_stats[student.id][lesson.id]['lesson_object'] = lesson
        @students_stats[student.id][lesson.id]['lesson_date'] = lesson.slot.timeslot
        glws = global_lessons_with_slots_index[lesson.id]
        dom_id = glws.slot.location[0..2].upcase + 
                 glws.slot.timeslot.strftime("%Y%m%d%H%M") +
                 'l' + glws.slot.id.to_s.rjust(@sf, "0") +
                 'n' + lesson.id.to_s.rjust(@sf, "0") + 
                 's' + student.id.to_s.rjust(@sf, "0")
        #@students_stats[student.id]['dom_ids'].push(dom_id)
        @students_stats[student.id]['dom_ids'].push(dom_id)
        student.roles.each do |thisrole|
          if thisrole.lesson_id == lesson.id
            role_comment = thisrole.comment 
            @students_stats[student.id]['role_kind'].push([thisrole.kind, role_comment])
            break
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
 # Required for free sessions:- 
 #  F     Free lesson for student
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
 #  Note: free routine sessions do non exist for flexible sessions.
 #
 # For free sessons:-
 #  free Free = sessons where free (introductory) lessons can be allocated
 #  = S - F
 
 # -----------------------------------------------------------------------------
  def generate_stats
    # get the student stats info first which is displayed at the top of 
    # the stats page.
    student_stats()     # call the def
    
    #logger.debug "********************@students_stats: " + @students_stats.inspect
    siv = {'S'=>0,'R'=>0,'A'=>0,'AoTo'=>0,'RoTo'=>0,'RCu'=>0,'RCoTo'=>0,'B'=>0}

    # step through each site
    @all_sites_ratio = {'tutor_count'=>0, 'student_count'=>0}
    @cal.each do |location, calLocation|
      calLocation.each_with_index do |rows, rowindex|
        rows.each_with_index do |cells, colindex|
          if cells.key?("values") then  # in a slot with lessons
            siv = {'S'=>0,'R'=>0,'A'=>0,'AoTo'=>0,'RoTo'=>0,'RCu'=>0,'RCoTo'=>0,'B'=>0,'F'=>0}
            s = {'routine'=>siv.clone, 'flexible'=>siv.clone,
                 'allocate'=>siv.clone, 'free'=>siv.clone}
            slottutorcount = slotstudentcount = 0
            cells["values"].each do |entry|  # go through each lesson
              # si = stats initiation parameters
              # ss = session status
              # s  = stats
              ss = entry.status
              ss = 'routine' if entry.status == 'standard' # standard and routine lessons are equivalent
              s[ss] = siv.clone unless s.has_key?(ss)
                s[ss]['S'] += 1
              if @tutrole_lessonindex.has_key? entry.id then  # check for tutroles linked to this lesson
                # could be multiple tutors in this lesson, a tutrole for each - need to step through each one
                @tutrole_lessonindex[entry.id].each do |thistutorrole|  # check each tutrole for diagnostics
                  # slottutorcount is for ratio calculations
                  # Ratios are only calculated using BFL, Routine and Flexible lessons
                  if(["scheduled", "notified", "confirmed", "attended"].include?@tutroleinfo[thistutorrole].status)  # valid statuses for ratio calculations
                    slottutorcount += 1 if(['on_BFL', 'standard', 'routine', 'flexible'].include?entry.status) # valid lessons for rations
                  end
                end
              end
              if @role_lessonindex.has_key? entry.id then  # check for students
                # for ratio calculation
                @role_lessonindex[entry.id].each do |thisstudentrole|  # check each role for diagnostics
                  thisstudent = @roleinfo[thisstudentrole].student
                  thisrole = @roleinfo[thisstudentrole]
                  thisstudent = thisrole.student
                  if(["scheduled", "attended", "deal", "queued"].include?thisrole.status)     # rostered
                    slotstudentcount += 1  if(['on_BFL', 'free', 'standard', 'routine', 'flexible'].include?entry.status)  # supporting ratio status
                    s[ss]['R'] += 1
                    if(["onetoone"].include?thisstudent.status)
                      s[ss]['RoTo'] += 1
                    end
                    if(["catchup", "catchupcourtesy"].include?thisrole.kind)
                      s[ss]['RCu'] += 1
                      if(["onetoone"].include?thisstudent.status)
                        s[ss]['RCoTo'] += 1
                      end        
                    end
                    if(["free"].include?thisrole.kind)
                      s[ss]['F'] += 1
                    end
                  elsif(["bye"].include?thisrole.status)
                    s[ss]['B'] += 1
                  elsif(["away", "absent"].include?thisrole.status)
                    s[ss]['A'] += 1
                    if(["onetoone"].include?thisstudent.status)
                      s[ss]['AoTo'] += 1
                    end        
                  end
                end
              end
            end
            # keep stats in the cell/slot data
            # track how many spare in routine/standard and flexible lessons
            ss = 'routine'
            #regularRoutine1 = 2*s[ss]['S']-s[ss]['A']-s[ss]['R']+s[ss]['RCu']-
            #              s[ss]['RoTo']-s[ss]['AoTo']+s[ss]['RCoTo']-s[ss]['B']
            ###catchupRoutine1 = s[ss]['A']+s[ss]['RoTo']+s[ss]['B']-s[ss]['RCu']-s[ss]['RCoTo']
            #catchupRoutine1 = s[ss]['A']+s[ss]['B']-s[ss]['RCu']-s[ss]['RCoTo']
            s[ss]['Regular'] = 2*s[ss]['S']-s[ss]['A']-s[ss]['R']+s[ss]['RCu']-
                               s[ss]['RoTo']-s[ss]['AoTo']+s[ss]['RCoTo']-s[ss]['B']
            s[ss]['Catchup'] = s[ss]['A']+s[ss]['B']-s[ss]['RCu']-s[ss]['RCoTo']
            ss = 'flexible'
            #catchupFlexible1 = 2 * s[ss]['S']-s[ss]['R']-s[ss]['RoTo'] 
            s[ss]['Catchup'] = 2 * s[ss]['S']-s[ss]['R']-s[ss]['RoTo']
            # now how many are to be used by allocations
            ss = 'allocate'
            s[ss]['Regular'] = s[ss]['R']+s[ss]['RoTo']-s[ss]['RCu']-
                               s[ss]['RCoTo']
            s[ss]['Catchup'] = s[ss]['RCu']+s[ss]['RCoTo']
            # now to calculate overall availabilities
            s['sum'] = {'regular'=>s['routine']['Regular'],
                        'catchup'=>s['routine']['Catchup'] + s['flexible']['Catchup'] }
            if s.has_key?('allocate')
              s['sum']['regular'] -= s['allocate']['Regular'] 
              s['sum']['catchup'] -= s['allocate']['Catchup']
            end
            # Now to handle the free lessons - quite independant of the routine and flexible lessons.
            ss = 'free'
            s['sum']['free'] = s[ss]['S'] - s[ss]['F'] - s['allocate']['F']
            cells["stats"] = s.clone
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
 # Get slot stats.
 #
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
 #  free Regular = availability of sessions for permanment allocations
 #  = 2S-A-R+RCu-RoTo-AoTo+RCoTo-B
 #
 #  free Catch Up = sessions where catch ups can be allocated
 #  = A+AoTo+B-RCu-RCoTo
 #
 # For routine sessons:-
 #  free Catch Up = sessons where catch ups can be allocated
 #  = 2S-R-RoTo
 #
 #  Note: free Regular sessions do on exist for flexible sessions.
 # -----------------------------------------------------------------------------
  def get_slot_stats(slot_dom_id)
    # want to get the stats for one slot
    # slot id passed in: GUN201805281530l02424n29192s00520
    #logger.debug "********************get_slot_stats: " + slot_dom_id
    if(result = /^([A-Z]+\d+l(\d+))/.match(slot_dom_id))
      slot_id = result[1]
      slot_dbid = result[2].to_i
    end
    # Need to get all relevant lessons for this slot
    #slot_lessons = Lesson.includes(:students, :roles, :slot).where(:slot_id => slot_dbid)
    @slot_lessons = Lesson.where(slot_id: slot_dbid)
                          .includes(roles:[:student], tutroles:[:tutor])
    # step through each lesson in this slot
    siv = {'S'=>0,'R'=>0,'A'=>0,'AoTo'=>0,'RoTo'=>0,'RCu'=>0,'RCoTo'=>0,'B'=>0,'F'=>0}
    s = {'routine'=>siv.clone, 'flexible'=>siv.clone,
         'allocate'=>siv.clone, 'free'=>siv.clone}
    # Define this outside this function, so that when this is called multiple
    # times with different slots, they are all concatenated.
    @duplicates = Array.new unless @duplicates
    # keep track of students and tutorsin this slot
    slottutors = Hash.new
    slotstudents = Hash.new
    @slot_lessons.each do |entry|
      # determine if this lesson is to be included in tutor/student deplicate checks
      flagcheckdup = true
      flagcheckdup = false if ["global", "parked", "setup"].include?entry.status
      #byebug if entry.status == 'allocate'
      # Remember lesson(entry) status is diaplayed to user as kind.
      #logger.debug "lesson: " + entry.id.to_s + " status:  " + entry.status
      ss = entry.status
      ss = 'routine' if entry.status == 'standard'
      s[ss] = siv.clone unless s.has_key?(ss)
      s[ss]['S'] += 1
      if entry.roles then  # check for students
        #logger.debug "student found: " + @role_lessonindex[entry.id].inspect
        # for ratio calculation
        #slotstudentcount += @role_lessonindex[entry.id].count
        entry.roles.each do |thisrole|  # check each role for diagnostics
          #logger.debug "student found - role: " + thisstudentrole.inspect
          thisstudent = thisrole.student
          # see if we already had this student
          if flagcheckdup
            if slotstudents.has_key?thisstudent.pname
              dsptimeslot = ""
              if(result = /^([A-Z]+)(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/.match(slot_dom_id))
                dsptimeslot = "#{result[1]} #{result[4]}/#{result[3]}/#{result[2]} #{result[5]}:#{result[6]}"
              end
              @duplicates.push(['student', thisstudent.pname, dsptimeslot])
              slotstudents[thisstudent.pname] += 1
            else
              slotstudents[thisstudent.pname]  = 1
            end
          end
          #logger.debug "thisstudent: " + thisstudent.inspect
          if(["scheduled", "attended", "deal", "queued"].include?thisrole.status)     # rostered
            s[ss]['R'] += 1
            if(["onetoone"].include?thisstudent.status)
              s[ss]['RoTo'] += 1
            end
            if(["catchup", "catchupcourtesy"].include?thisrole.kind)
              s[ss]['RCu'] += 1
              if(["onetoone"].include?thisstudent.status)
                s[ss]['RCoTo'] += 1
              end        
            end
            if(["free"].include?thisrole.kind)
              s[ss]['F'] += 1
            end
          elsif(["bye"].include?thisrole.status)
            s[ss]['B'] += 1
          elsif(["away", "absent"].include?thisrole.status)
            s[ss]['A'] += 1
            if(["onetoone"].include?thisstudent.status)
              s[ss]['AoTo'] += 1
            end        
          end
        end
      end
      if entry.tutroles then  # check for tutors
        entry.tutroles.each do |thistutrole|  # check each role for diagnostics
          #logger.debug "student found - role: " + thisstudentrole.inspect
          thistutor = thistutrole.tutor
          if flagcheckdup
            # see if we already had this student
            if slottutors.has_key?thistutor.pname
              dsptimeslot = ""
              if(result = /^([A-Z]+)(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/.match(slot_dom_id))
                dsptimeslot = "#{result[1]} #{result[4]}/#{result[3]}/#{result[2]} #{result[5]}:#{result[6]}"
              end
              @duplicates.push(['tutor', thistutor.pname, dsptimeslot])
              slottutors[thistutor.pname] += 1
            else
              slottutors[thistutor.pname]  = 1
            end
          end
        end      
      end
    end
    # keep stats in the cell/slot data
    # track how many spare in routine/standard and flexible lessons
    ss = 'routine'
    s[ss]['Regular'] = 2*s[ss]['S']-s[ss]['A']-s[ss]['R']+s[ss]['RCu']-
                       s[ss]['RoTo']-s[ss]['AoTo']+s[ss]['RCoTo']-s[ss]['B']
    s[ss]['Catchup'] = s[ss]['A']+s[ss]['B']-s[ss]['RCu']-s[ss]['RCoTo']
    ss = 'flexible'
    #catchupFlexible1 = 2 * s[ss]['S']-s[ss]['R']-s[ss]['RoTo'] 
    s[ss]['Catchup'] = 2 * s[ss]['S']-s[ss]['R']-s[ss]['RoTo']
    # now how many are to be used by allocations
    ss = 'allocate'
    s[ss]['Regular'] = s[ss]['R']+s[ss]['RoTo']-s[ss]['RCu']-
                       s[ss]['RCoTo']
    s[ss]['Catchup'] = s[ss]['RCu']+s[ss]['RCoTo']
    # now to calculate overall availabilities
    s['sum'] = {'regular'=>s['routine']['Regular'],
                'catchup'=>s['routine']['Catchup'] + s['flexible']['Catchup'] }
    if s.has_key?('allocate')
      s['sum']['regular'] -= s['allocate']['Regular'] 
      s['sum']['catchup'] -= s['allocate']['Catchup']
    end
    # Now to handle the free lessons - quite independant of the routine and flexible lessons.
    ss = 'free'
    s['sum']['free'] = s[ss]['S'] - s[ss]['F'] - s['allocate']['F']
#-------------------------------------------
    slot_html_partial = render_to_string("calendar/_stats_slot.html",
                        :formats => [:html], :layout => false,
                        :locals => {:stats => s})
    
    #logger.debug "slot_html_partial: " + slot_html_partial
    @statschange = Hash.new
    @statschange['slot_id']      = slot_id
    @statschange['html_partial'] = slot_html_partial
    
    #ActionCable.server.broadcast "stats_channel", { json: @statschange }
    #ably_rest.channels.get('stats').publish('json', @statschange)
    return @statschange.dup
    
  end
  
end



