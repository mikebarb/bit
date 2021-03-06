#app/controllers/concerns/historyutilities.rb
module Historyutilities
  extend ActiveSupport::Concern

  # Note:
  #      includes -> minimum number of db queries
  #      joins    -> lazy loads the db query

  # Obtain the history for a single tutor
  # @tutorhistory holds everything required in the view
  def tutor_history(tutor_id, options)
    # put everything in a hash for use in the view.
    @tutorhistory = Hash.new
    # keep the tutor details
    @tutorhistory["tutor"] = Tutor.find(tutor_id)
    # control how much history to provide
    startdate = Date.today - (Integer(current_user.history_back) rescue 100)
    enddate = Date.today + (Integer(current_user.history_forward) rescue 7)
    @tutorhistory["startdate"] = startdate
    @tutorhistory["enddate"]   = enddate
    #provide the capability to override the start and end dates by
    # passing them as options
    if options.has_key?('startdate')
      startdate = options['startdate']
    end
    if options.has_key?('enddate')
      enddate = options['enddate']
    end

    @tutorhistory["display"]   = options['action']
    # get all lessons this tutor is in - all history
    # link to lessons for this tutor through the tutroles
    tutrole_objs = Tutrole.where (["tutor_id = ?", tutor_id])
    # get all the lessons found through tutroles 
    lesson_ids = tutrole_objs.map { |obj| obj.lesson_id }.uniq
    lesson_objs = Lesson.includes(:slot, roles: :student, tutroles: :tutor)
                        .where( id: lesson_ids, slots: { timeslot: startdate..enddate})
                        .order('slots.timeslot').reverse_order
    @tutorhistory["lessons"] = lesson_objs.map { |obj| [
                                            obj.id,
                                            obj.status,
                                            obj.slot.timeslot,
                                            obj.slot.location,
                                            obj.tutroles.map {|r| [r.tutor.pname,   r.status]},
                                            obj.roles.map    {|r| [r.student.pname, r.status]},
                                            date_to_weekofterm(obj.slot.timeslot)  
                                          ] }
    @tutorhistory
  end

  # Obtain all the details about the current chain this tutor is in.
  # @tutorhistory holds everything required in the view
  # From the passed in student/lesson, obtail all the links in the chain.
  def tutor_chain(tutor_id, lesson_id, options)
    # put everything in a hash for use in the view.
    @tutorhistory = Hash.new
    # keep the tutor details
    @tutorhistory["tutor"] = Tutor.find(tutor_id)
    # get this role
    tutrole  = Tutrole.where(tutor_id: tutor_id, lesson_id: lesson_id).first
    tutroles = Tutrole.where(block: tutrole.block)
    # link to lessons for these roles
    lesson_ids = tutroles.map { |obj| obj.lesson_id }.uniq
    lesson_objs = Lesson.includes(:slot, :students, :tutors, :roles)
                        .where( id: lesson_ids)
                        .order('slots.timeslot')
    @tutorhistory["lessons"] = lesson_objs.map { |obj| [
                                            obj.id,
                                            obj.status,
                                            obj.slot.timeslot,
                                            obj.slot.location,
                                            obj.tutroles.map {|r| [r.tutor.pname,   r.status]},
                                            obj.roles.map    {|r| [r.student.pname, r.status]},
                                            date_to_weekofterm(obj.slot.timeslot)  
                                          ] }
    @tutorhistory
  end

  # Obtain all the details about the current chaing the student is in.
  # @studenthistory holds everything required in the view
  # From the passed in student/lesson, obtail all the links in the chain.
  def student_chain(student_id, lesson_id, options)
    # put everything in a hash for use in the view.
    @studenthistory = Hash.new
    # keep the student details
    @studenthistory["student"] = Student.find(student_id)
    # get this role
    role  = Role.where(student_id: student_id, lesson_id: lesson_id).first
    roles = Role.where(block: role.block)
    # link to lessons for these roles
    lesson_ids = roles.map { |obj| obj.lesson_id }.uniq
    lesson_objs = Lesson.includes(:slot, :students, :tutors, :roles)
                        .where( id: lesson_ids)
                        .order('slots.timeslot')
    @studenthistory["lessons"] = lesson_objs.map { |obj| [
                                  obj.id,
                                  obj.status,
                                  obj.slot.timeslot,
                                  obj.slot.location,
                                  obj.tutroles.map {|r| [r.tutor.pname,   r.status]},
                                  obj.roles.map    {|r| [r.student.pname, r.status]},
                                  #obj.roles.where(student_id: student_id).first.status == nil ?
                                  #  "" : obj.roles.where(student_id: student_id).first.status,
                                  date_to_weekofterm(obj.slot.timeslot)  
                                  ] }
    @studenthistory
  end

  # Obtain the history for a single student
  # @studenthistory holds everything required in the view
  def student_history(student_id, options)
    # put everything in a hash for use in the view.
    @studenthistory = Hash.new
    # keep the student details
    @studenthistory["student"] = Student.find(student_id)
    # control how much history to provide
    startdate = Date.today - (Integer(current_user.history_back) rescue 100)
    enddate = Date.today + (Integer(current_user.history_forward) rescue 7)
    #provide the capability to override the start and end dates by
    # passing them as options
    if options.has_key?('startdate')
      startdate = options['startdate']
    end
    if options.has_key?('enddate')
      enddate = options['enddate']
    end
    @studenthistory["startdate"] = startdate
    @studenthistory["enddate"]   = enddate
    @studenthistory["display"]    = options['action']
    # get all lessons this student is in - all history
    # link to lessons for this student through the roles
    role_objs = Role.where (["student_id = ?", student_id])
    # get all the lessons found through tutroles 
    lesson_ids = role_objs.map { |obj| obj.lesson_id }.uniq
    lesson_objs = Lesson.includes(:slot, roles: :student, tutroles: :tutor)
                        .where( id: lesson_ids, slots: { timeslot: startdate..enddate})
                        .order('slots.timeslot').reverse_order
    @studenthistory["lessons"] = lesson_objs.map { |obj| [
                                            obj.id,
                                            obj.status,
                                            obj.slot.timeslot,
                                            obj.slot.location,
                                            obj.tutroles.map {|r| [r.tutor.pname,   r.status]},
                                            obj.roles.map    {|r| [r.student.pname, r.status]},
                                            date_to_weekofterm(obj.slot.timeslot)  
                                          ] }

    @studenthistory
  end


  # Obtain the history for a single student for obtaining feedback
  # from a tutor for this student.
  # @studentfeedback holds everything required in the view
  def student_feedback(student_id, options)
    # put everything in a hash for use in the view.
    @studentfeedback = Hash.new
    # keep the student details
    @studentfeedback["student"] = Student.find(student_id)
    # control how much history to provide
    startdate = Date.today - (Integer(current_user.history_back) rescue 100)
    enddate = Date.today + (Integer(current_user.history_forward) rescue 7)
    #provide the capability to override the start and end dates by
    # passing them as options
    if options.has_key?('startdate')
      startdate = options['startdate']
    end
    if options.has_key?('enddate')
      enddate = options['enddate']
    end
    @studentfeedback["startdate"] = startdate
    @studentfeedback["enddate"]   = enddate
    @studentfeedback["display"]   = options['action']
    # get all lessons this student is in - all history
    # link to lessons for this student through the roles
    role_objs = Role.where (["student_id = ?", student_id])
    # get all the lessons found through tutroles 
    lesson_ids = role_objs.map { |obj| obj.lesson_id }.uniq
    lesson_objs = Lesson.includes(:slot, roles: :student, tutroles: :tutor)
                        .where( id: lesson_ids, slots: { timeslot: startdate..enddate})
                        .order('slots.timeslot')
    #                    .order('slots.timeslot').reverse_order
    @studentfeedback["lessons"] = Array.new
    tutornames = Hash.new
    lesson_objs.each do |thislesson|
      rowdata = Hash.new
      flagstudentfound = flagtutorfound = false
      thislesson.roles.each do |thisrole|
        if thisrole.student_id == student_id.to_i   # check if desired student
          if ['scheduled', 'attended'].include?(thisrole.status) # student is rostered.
            rowdata[:student_pname] = thisrole.student.pname
            rowdata[:student_status] = thisrole.student.status
            flagstudentfound = true
            # Now get the tutor that was on.
            thislesson.tutroles.each do |thistutrole|
              if ['scheduled', 'notified', 'confirmed', 'attended'].include?(thisrole.status) # tutor is rostered.
                tutname = thistutrole.tutor.pname
                rowdata[:tutor_pname] = tutname
                tutornames[tutname] = tutornames[tutname] ? 1 + tutornames[tutname] : 1
                rowdata[:tutor_count] = tutornames[tutname]
                flagtutorfound = true
              end          
            end
            unless flagtutorfound
              rowdata[:tutor_pname] = ''
              rowdata[:tutor_count] = 0
            end
          end
        end  
      end
      if flagstudentfound
        rowdata[:location] = thislesson.slot.location
        rowdata[:timeslot] = thislesson.slot.timeslot
        @studentfeedback["lessons"].push(rowdata.clone)
      end

    end
    @studentfeedback
  end




  
  def date_to_weekofterm(thisdatetime)  
    thistermweek = ''
    if current_user.termstart != nil && current_user.termweeks != nil        
      termweek = ((thisdatetime.to_datetime - current_user.termstart.to_datetime).to_i)/7
      if termweek >= 0 && termweek < current_user.termweeks
        thistermweek = 'W' + (termweek + 1).to_s
      end
    end
    return thistermweek
  end


  # Obtain the changes for a single tutor
  # @tutorchanges holds everything required in the view
  def tutor_change(tutor_id)
    # put everything in a hash for use in the view.
    @tutorchanges = Hash.new
    @tutorchanges["tutor"] = Tutor.find(tutor_id)
    startdate = Date.today - (Integer(current_user.history_back) rescue 100)
    enddate = Date.today + (Integer(current_user.history_forward) rescue 7)
    # override for testing only
    #startdate = Date.parse('4-4-2018')
    #enddate = Date.parse('5-4-2018')
    @tutorchanges["startdate"] = startdate
    @tutorchanges["enddate"]   = enddate

    # provide ability to display userids ( = email address)
    @users = User
             .select(:id, :email)
             .all
    @user_names = {}
    @users.each do |o|
      @user_names[o.id] = o.email
    end
    # now collate the changes
    # slotes o interest - in the date range
    myslots = Slot.select(:id).where(timeslot: startdate..enddate)
    # all lessons in those slots
    mylessons = Lesson.select(:id).where(slot_id: myslots)
    # all tut roles for this tutor in these lessons
    mytutroles = Tutrole.select(:id, :lesson_id).where(tutor_id: tutor_id, lesson_id: mylessons)
    mytutroleslessonsids = mytutroles.map {|o| o.lesson_id} # for code efficiency later
    # now reduce to only lessons that have this tutor
    mylessons = mylessons.select { |o| mytutroleslessonsids.include?(o.id) ? true : false }
    #now get full details on these relevant lessons - slot info required in display 
    mylessons = Lesson
                 .joins(:slot)
                 .where(id: mylessons.map {|o| o.id})
                 .includes(:slot)
    # lookup table into lessons to reduce db activity.
    mylessonsindex = {}  # key = session id , value is index in lessons object array 
    mylessons.each_with_index do |v, i|
      mylessonsindex[v.id] = i
    end
    # ditto lookup table for tutroles
    mytutrolesindex = {}  # key = session id , value is index in lessons object array 
    mytutroles.each_with_index { |v, i| mytutrolesindex[v.id] = i }
    # go and get the relevent changes from the change table 
    changelessons = Change.where(table: 'Lesson', rid: mylessons.map {|o| o.id})
    changetutroles = Change.where(table: 'Tutrole', rid: mytutroles.map {|o| o.id})
    changetutor = Change.where(table: 'Tutor', rid: tutor_id)
    # generate the data for display - go through each category
    makeDsp = lambda{|h, o| 
      h['user']     = @user_names[o.user]
      h['modified'] = o.modified
      h['table']    = o.table
      h['field']    = o.field
      h['id']       = o.id
      h['value']    = o.value
      h
    }
    @dsp = Array.new
    changelessons.each do |o|
      h = makeDsp.call(Hash.new(), o)
      h['timeslot'] = mylessons[mylessonsindex[o.rid]].slot.timeslot
      h['location'] = mylessons[mylessonsindex[o.rid]].slot.location
      @dsp.push(h)
    end
    changetutroles.each do |o| 
      h = makeDsp.call(Hash.new(), o)
      h['timeslot'] = mylessons[mylessonsindex[mytutroles[mytutrolesindex[o.rid]].lesson_id]].slot.timeslot
      h['location'] = mylessons[mylessonsindex[mytutroles[mytutrolesindex[o.rid]].lesson_id]].slot.location
      @dsp.push(h)
    end
    # only dealing with a single tutor
    if changetutor.length > 0
      changetutor.each do |this|
        h = makeDsp.call(Hash.new(), this)
        h['timeslot'] = ''
        h['location'] = ''
        @dsp.push(h)
      end
    end
    # sort in modified date order
    @dsp = @dsp.sort_by{ |q| q['modified']}.reverse
    # now store all these changes in passed display data
    @tutorchanges["data"] = @dsp
    @tutorchanges
  end

  # Obtain the changes for a single student
  # @studentchanges holds everything required in the view
  def student_change(student_id)
    logger.debug "student_change called"
    # put everything in a hash for use in the view.
    @studentchanges = Hash.new
    @studentchanges["student"] = Student.find(student_id)
    startdate = Date.today - (Integer(current_user.history_back) rescue 100)
    enddate = Date.today + (Integer(current_user.history_forward) rescue 7)
    # override for testing only
    #startdate = Date.parse('4-4-2018')
    #enddate = Date.parse('5-4-2018')
    @studentchanges["startdate"] = startdate
    @studentchanges["enddate"]   = enddate

    # provide ability to display userids ( = email address)
    @users = User
             .select(:id, :email)
             .all
    @user_names = {}
    @users.each do |o|
      @user_names[o.id] = o.email
    end
    # now collate the changes
    # slotes o interest - in the date range
    myslots = Slot.select(:id).where(timeslot: startdate..enddate)
    # all lessons in those slots
    mylessons = Lesson.select(:id).where(slot_id: myslots)
    # all roles for this student in these lessons
    myroles = Role.select(:id, :lesson_id).where(student_id: student_id, lesson_id: mylessons)
    myroleslessonsids = myroles.map {|o| o.lesson_id} # for code efficiency later
    # now reduce to only lessons that have this student
    mylessons = mylessons.select { |o| myroleslessonsids.include?(o.id) ? true : false }
    #now get full details on these relevant lessons - slot info required in display 
    mylessons = Lesson
                 .joins(:slot)
                 .where(id: mylessons.map {|o| o.id})
                 .includes(:slot)
    # lookup table into lessons to reduce db activity.
    mylessonsindex = {}  # key = session id , value is index in lessons object array 
    mylessons.each_with_index do |v, i|
      mylessonsindex[v.id] = i
    end
    # ditto lookup table for tutroles
    myrolesindex = {}  # key = session id , value is index in lessons object array 
    myroles.each_with_index { |v, i| myrolesindex[v.id] = i }
    # go and get the relevent changes from the change table 
    changelessons = Change.where(table: 'Lesson', rid: mylessons.map {|o| o.id})
    changeroles = Change.where(table: 'Role', rid: myroles.map {|o| o.id})
    changestudent = Change.where(table: 'Student', rid: student_id)
    # generate the data for display - go through each category
    #byebug
    makeDsp = lambda{|h, o| 
      h['user']     = @user_names[o.user]
      h['modified'] = o.modified
      h['table']    = o.table
      h['field']    = o.field
      h['id']       = o.id
      h['value']    = o.value
      h
    }
    @dsp = Array.new
    changelessons.each do |o|
      h = makeDsp.call(Hash.new(), o)
      h['timeslot'] = mylessons[mylessonsindex[o.rid]].slot.timeslot
      h['location'] = mylessons[mylessonsindex[o.rid]].slot.location
      @dsp.push(h)
    end
    changeroles.each do |o| 
      h = makeDsp.call(Hash.new(), o)
      h['timeslot'] = mylessons[mylessonsindex[myroles[myrolesindex[o.rid]].lesson_id]].slot.timeslot
      h['location'] = mylessons[mylessonsindex[myroles[myrolesindex[o.rid]].lesson_id]].slot.location
      @dsp.push(h)
    end
    # only dealing with a single student
    #byebug
    if changestudent.length > 0
      changestudent.each do |this|
        h = makeDsp.call(Hash.new(), this)
        h['timeslot'] = ''
        h['location'] = ''
        @dsp.push(h)
      end
    end
    # sort in modified date order
    @dsp = @dsp.sort_by{ |q| q['modified']}.reverse
    # now store all these changes in passed display data
    @studentchanges["data"] = @dsp
    @studentchanges
  end
  
end