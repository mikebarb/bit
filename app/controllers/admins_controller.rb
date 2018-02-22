class AdminsController < ApplicationController
  include Googleutilities
  #skip_before_action :authenticate_user!, only: [:home]

#---------------------------------------------------------------------------
#
#   Home Page - no login requird to get to this page
#               Splash page for first entering the application.
#
#---------------------------------------------------------------------------
  # GET /admins/home
  # GET /admins/home.json
  def home
  end

  
#---------------------------------------------------------------------------
#
#   Load Menu - select what you want to load
#
#---------------------------------------------------------------------------
  # GET /admins/load
  # GET /admins/load.json
  def load
  end

#---------------------------------------------------------------------------
#
#   Load Tutors
#
#---------------------------------------------------------------------------
  # GET /admins/loadtutors
  def loadtutors
    service = googleauthorisation(request)
    spreadsheet_id = '1CbtBqeHyYb9jRmROCgItS2eEaYSwzOMpQZdUWLMvjng'
    logger.debug 'about to read spreadsheet'
    startrow = 4
    # first get the 5 columns - Name + initial, subjects, mobile, email, surname
    range = "TUTORS!B#{startrow}:F"
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    @tutors = Array.new(response.values.length){Array.new(9)}
    #logger.debug "tutors: " + @tutors.inspect
    basecolumncount = 1
    rowcount = 0			   
    response.values.each do |r|
        #logger.debug "============ row #{rowcount} ================"
        #logger.debug "row: " + r.inspect
        colcount = 0
        @tutors[rowcount][0] = rowcount + startrow
        r.each do |c|
          #logger.debug "============ cell value for column #{colcount} ================"
    	    #logger.debug "cell value: " + c.inspect
    	    @tutors[rowcount][basecolumncount + colcount] = c
    	          #bc = v.effective_format.background_color
    	          #logger.debug  "background color: red=" + bc.red.to_s +
    	          #              " green=" + bc.green.to_s +
    		        #              " blue=" + bc.blue.to_s
    		  colcount = colcount + 1
        end
        rowcount = rowcount + 1
    end
    basecolumncount = basecolumncount + 5
    #now get the comments field
    range = "TUTORS!EC#{startrow}:EC"
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    rowcount = 0
    response.values.each do |r|
        colcount = 0
        r.each do |c|
    	    @tutors[rowcount][basecolumncount + colcount] = c
    		  colcount = colcount + 1
        end
        rowcount = rowcount + 1
    end
    basecolumncount = basecolumncount + 1
    #logger.debug "tutors: " + @tutors.inspect
    # Now to update the database
    loopcount = 0
    @tutors.each do |t|                 # step through all tutors from the spreadsheet
      pname = t[1]
      logger.debug "pname: " + pname.inspect
      if pname == ""  || pname == nil
        t[7] = "invalid pname - do nothing"
        next
      end
      if m =pname.match(/(^z+)(.+)$/)
        pname = m[2]
        t[1] = pname
      end
      
      db_tutor = Tutor.find_by pname: pname
      if(db_tutor)   # already in the database
        flagupdate = 0                  # detect if any fields change
        updatetext = ""
        if db_tutor.comment != t[6]
          db_tutor.comment = t[6]
          flagupdate = 1
          updatetext = updatetext + " - comment"  
        end
        if db_tutor.sname != t[5]
          db_tutor.sname = t[5]
          flagupdate = 1
          updatetext = updatetext + " - sname"  
        end
        if db_tutor.email != t[4]
          db_tutor.email = t[4]
          flagupdate = 1
          updatetext = updatetext + " - email"  
        end
        if db_tutor.phone != t[3]
          db_tutor.phone = t[3]
          flagupdate = 1
          updatetext = updatetext + " - phone"  
        end
        if db_tutor.subjects != t[2]
          db_tutor.subjects = t[2]
          flagupdate = 1
          updatetext = updatetext + " - subjects"  

        end
        logger.debug "flagupdate: " + flagupdate.inspect + " db_tutor: " + db_tutor.inspect
        if flagupdate == 1                   # something changed - need to save
          if db_tutor.save
            logger.debug "db_tutor saved changes successfully"
            t[7] = "updated" + updatetext  
          else
            logger.debug "db_tutor saving failed - " + @db_tutor.errors
            t[7] = "failed to create"
          end
        else
            t[7] = "no changes"
        end
      else
        # This tutor is not in the database - so need to add it.
        @db_tutor = Tutor.new(
                              pname: t[1],
                              subjects: t[2],
                              phone: t[3],
                              email: t[4],
                              sname: t[5],
                              comment: t[6],
                              status: "active"
                            )
        if pname =~ /^zz/                   # the way they show inactive tutors
          @db_tutor.status = "inactive"
        end
        logger.debug "new - db_tutor: " + @db_tutor.inspect
        if @db_tutor.save
          logger.debug "db_tutor saved successfully"
          t[7] = "created"  
        else
          logger.debug "db_tutor saving failed - " + @db_tutor.errors
          t[7] = "failed to create"
        end
      end
      #exit
      if loopcount > 5
        #break
      end
      loopcount += 1
    end
    #exit
  end

#---------------------------------------------------------------------------
#
#   Load Students
#
#---------------------------------------------------------------------------
  # GET /admins/loadstudents
  def loadstudents
    service = googleauthorisation(request)
    spreadsheet_id = '1CbtBqeHyYb9jRmROCgItS2eEaYSwzOMpQZdUWLMvjng'
    logger.debug 'about to read spreadsheet'
    startrow = 3
    # first get the 3 columns - Student's Name + Year, Focus, study percentages
    range = "STUDENTS!A#{startrow}:C"
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    @students = Array.new(response.values.length){Array.new(11)}
    #logger.debug "students: " + @students.inspect
    basecolumncount = 1    #index for loading array - 0 contains spreadsheet row number
    rowcount = 0			   
    response.values.each do |r|
        #logger.debug "============ row #{rowcount} ================"
        #logger.debug "row: " + r.inspect
        colcount = 0
        @students[rowcount][0] = rowcount + startrow
        r.each do |c|
          #logger.debug "============ cell value for column #{colcount} ================"
    	    #logger.debug "cell value: " + c.inspect
    	    @students[rowcount][basecolumncount + colcount] = c
    		  colcount = colcount + 1
        end
        rowcount = rowcount + 1
    end
    basecolumncount += 3
    # second get the 1 column - email
    range = "STUDENTS!E#{startrow}:E"
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    #logger.debug "students: " + @students.inspect
    rowcount = 0			   
    response.values.each do |r|
        #logger.debug "============ row #{rowcount} ================"
        #logger.debug "row: " + r.inspect
        colcount = 0
        r.each do |c|
          #logger.debug "============ cell value for column #{colcount} ================"
    	    #logger.debug "cell value: " + c.inspect
    	    @students[rowcount][basecolumncount + colcount] = c
    		  colcount = colcount + 1
        end
        rowcount = rowcount + 1
    end
    basecolumncount += 1
    #third get the perferences and invcode
    range = "STUDENTS!L#{startrow}:M"
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    rowcount = 0
    response.values.each do |r|
        colcount = 0
        r.each do |c|
    	    @students[rowcount][basecolumncount + colcount] = c
    		  colcount = colcount + 1
        end
        rowcount = rowcount + 1
    end
    basecolumncount += 2
    #fourth get the 3 columns daycode, term 4, daycode
    # these will be manipulated to get the savable daycode
    range = "STUDENTS!P#{startrow}:R"
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    rowcount = 0
    response.values.each do |r|
        colcount = 0
        r.each do |c|
    	    @students[rowcount][basecolumncount + colcount] = c
    		  colcount = colcount + 1
        end
        rowcount = rowcount + 1
    end
    basecolumncount += 3
    #logger.debug "students: " + @students.inspect
    # Now to update the database
    loopcount = 0                         # limit output during testing
    @students.each do |t|                 # step through all tutors from the spreadsheet
      pnameyear = t[1]
      logger.debug "pnameyear: " + pnameyear.inspect
      if pnameyear == ""  || pnameyear == nil
        t[10] = "invalid pnameyear - do nothing"
        next
      end
      pnameyear[/^zz/] == nil ? status = "active" : status = "inactive"
      name_year_sex = getStudentNameYearSex(pnameyear)
      pname = name_year_sex[0]
      year = name_year_sex[1]
      sex = name_year_sex[2]
=begin
      sex = nil
      pnameyear = pnameyear.strip
      pname, temp, year = pnameyear.rpartition(/ /)
      if year.include?("male")
        if year.include?("female")
          sex = "female"
        else
          sex = "male"
        end
        pnametemp = pname.strip
        pname, temp, year = pnametemp.rpartition(/ /)
      end
=end
      logger.debug "pname: " + pname + " : " + year + " : " + sex.inspect
      # day code
      # use term 3 code unless a term 4 code, then take term 4
      t[9] == "" || t[9] == nil ? usedaycode = t[7] : usedaycode = t[9]
      # check if alrady an entry in the database
      # if so, update it. else create a new record.
      db_student = Student.find_by pname: pname
      if(db_student)   # already in the database
        flagupdate = 0                  # detect if any fields change
        updatetext = ""
        # first get the 4 columns - 1. Student's Name + Year, 2. Focus,
        #                           3. study percentages, 4. email
        # now get the 5. perferences and 6. invcode
        # now get the 7. daycode, 8. term 4, 9. daycode
        if db_student.year != year
          db_student.year = year
          flagupdate = 1
          updatetext = updatetext + " - year"  
        end
        if sex
          if db_student.sex != sex
            db_student.sex = sex
            flagupdate = 1
            updatetext = updatetext + " - sex"
          end
        end
        if db_student.comment != t[2]
          db_student.comment = t[2]
          flagupdate = 1
          updatetext = updatetext + " - comment"  
        end
        if db_student.study != t[3]
          db_student.study = t[3]
          flagupdate = 1
          updatetext = updatetext + " - study percentages"  
        end
        if db_student.email != t[4]
          db_student.email = t[4]
          flagupdate = 1
          updatetext = updatetext + " - email"  
        end
        if db_student.preferences != t[5]
          db_student.preferences = t[5]
          flagupdate = 1
          updatetext = updatetext + " - preferences"  
        end
        if db_student.invcode != t[6]
          db_student.invcode = t[6]
          flagupdate = 1
          updatetext = updatetext + " - invoice code"  
        end
        if db_student.daycode != usedaycode
          db_student.daycode = usedaycode
          flagupdate = 1
          updatetext = updatetext + " - day code"  
        end
        if db_student.status != status
          db_student.status = status
          flagupdate = 1
          updatetext = updatetext + " - status"  
        end
        logger.debug "flagupdate: " + flagupdate.inspect + " db_student: " + db_student.inspect
        if flagupdate == 1                   # something changed - need to save
          if db_student.save
            logger.debug "db_student saved changes successfully"
            t[10] = "updated" + updatetext  
          else
            logger.debug "db_student saving failed - " + @db_student.errors
            t[10] = "failed to create"
          end
        else
            t[10] = "no changes"
        end
      else
        # This tutor is not in the database - so need to add it.
        #
        # first get the 4 columns - 1. Student's Name + Year, 2. Focus,
        #                           3. study percentages, 4. email
        # now get the 5. perferences and 6. invcode
        # now get the 7. daycode, 8. term 4, 9. daycode
        @db_student = Student.new(
                              pname: pname,
                              year: year,
                              comment: t[2],
                              study: t[3],
                              email: t[4],
                              preferences: t[5],
                              invcode: t[6],
                              daycode: usedaycode,
                              status: "active"
                            )
        if pname =~ /^zz/                   # the way they show inactive tutors
          @db_student.status = "inactive"
        end
        logger.debug "new - db_student: " + @db_student.inspect
        if @db_student.save
          logger.debug "db_student saved successfully"
          t[10] = "created"  
        else
          logger.debug "db_student saving failed - " + @db_student.errors.inspect
          t[10] = "failed to create"
        end
      end
      #exit
      if loopcount > 2
        #break
      end
      loopcount += 1
    end
  end

#---------------------------------------------------------------------------
#
#   Load Schedule
#
#---------------------------------------------------------------------------
  # GET /admins/loadschedule
  def loadschedule
    # log levels are: :debug, :info, :warn, :error, :fatal, and :unknown, corresponding to the log level numbers from 0 up to 5
    #logger.fatal "1.log level" + Rails.logger.level.inspect
    
    service = googleauthorisation(request)
    spreadsheet_id = '1CbtBqeHyYb9jRmROCgItS2eEaYSwzOMpQZdUWLMvjng'
    sheet_name = 'WEEK 1'
    colsPerSite = 7
    # first get sites from the first row
    range = "#{sheet_name}!A3:AI3"
    Rails.logger.level = 1 
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    Rails.logger.level = 0 
    # extract the key for this week e.g. T3W1
    myrow = response.values[0]
    week = myrow[0]   # this key is used over and over
    # pick up the sites
    sites = Hash.new()    # array holding all sites
                          # index = site name
                          # col_start = first column for site
    myrow.map.with_index do |v, i|
      sites[v[/\w+/]] = {"col_start" => i-1} if v != "" && v != week
    end

    #this function converts spreadsheet indices to column name
    # examples: e[0] => A; e[30] => AE 
    e=->n{a=?A;n.times{a.next!};a}  
    
    #---------------------------------------------
    # We now need to work through the sites by day
    # and tutorial slots
    # We will load a spreadsheet site at a time
    #sites     # array holding all sites
               # index = site name
               # col_start = first column for site
    #days      # array of rows numbers starting the day
    #slottimes # array of row number starting each slot
               # index = row number, values = ssdate
               # and datetime = datetime of the slot
    # This array holds all the info required for updating 
    # the database and displaying the results
    @schedule = Array.new()
    #These arrays and hashes are used within the sites loop
    #They get cloned and cleared during iterations
    onCall = Array.new()
    onSetup = Array.new()
    requiredSlot = Hash.new()
    thisLesson = Hash.new()
    # @allColours is used in the view
    @allColours = Hash.new()
    # work through our sites, reading spreadsheet for each
    # and extract the slots, lessons, tutors and students
    # We also get the lesson notes.
    # At the beginning of each day, we get the on call and
    # setup info
    sites.each do |si, sv|  # site name, {col_start}
      #byebug
      mystartcol = e[sv["col_start"]]
      myendcol = e[sv["col_start"] + colsPerSite - 1]
      myendcoldates = e[sv["col_start"] + 1] 
      # ****************** temp seeting during development
      # restrict output for testing and development
      #range      = "#{sheet_name}!#{mystartcol}3:#{myendcol}60"
      #rangedates = "#{sheet_name}!#{mystartcol}3:#{mystartcol}60"
      # becomes for production
      range = "#{sheet_name}!#{mystartcol}3:#{myendcol}"
      rangedates = "#{sheet_name}!#{mystartcol}3:#{mystartcol}"
      Rails.logger.level = 1 
      response = service.get_spreadsheet(
        spreadsheet_id,
        ranges: range,
        fields: "sheets(data.rowData.values" + 
        "(formattedValue,effectiveFormat.backgroundColor))"
      )
      
      responsedates = service.get_spreadsheet_values(
        spreadsheet_id,
        rangedates,
        {value_render_option: 'UNFORMATTED_VALUE',
         date_time_render_option: 'SERIAL_NUMBER'
        }
      )

      Rails.logger.level = 0
      # Now scan each row read from the spreadsheet in turn
      response.sheets[0].data[0].row_data.map.with_index do |r, ri| # value[], row index
        # To analyse all the colours used in the spreadsheet,
        # we store all background colours from relevant cells.
        # Show them at the end to see if some are not what they
        # should be - manual inspection.
        # use: cell_background_color = getformat.call(column_index)
        storecolours = lambda{|j| 
          cf = nil
          if r.values[j]
            if r.values[j].effective_format
              cf = r.values[j].effective_format.background_color
            end
          end
          # store all colours and keep count of how often
          # also, keep location oif first occurance
          if cf != nil
            #col = [cf.red,cf.green,cf.blue]
            col = colourToArray(cf)
            @allColours[col] ? 
              @allColours[col][2] += 1 :
              @allColours[col] = [e[j + sv["col_start"]],3+ri,1]
          end
        }
        # Now start processing the row content
        c0 = getvalue(r.values[0])
        if c0 == week     # this is the first row of the day e.g. T3W1
          storecolours.call(1)
          next
        end
        if c0 == "ON CALL"     # we are on "ON CALL" row e.g. T3W1
          storecolours.call(1)
          for i in 1..7 do     # keep everything on row
            cv = getvalue(r.values[i])
            onCall.push(cv) if cv != ""
          end
          next
        end
        if c0 == "SETUP"     # we are on "ON CALL" row e.g. T3W1
          storecolours.call(1)
          for i in 1..7 do   # keep everything on row
            cv = getvalue(r.values[i])
            onSetup.push(cv) if cv != ""
          end
          next
        end
        # look for date row - first row for slot e.g 7/18/2016
        if c0.match(/(\d+)\/(\d+)\/(\d+)/)
          cf1 = getformat(r.values[1])
          # If this cell with day/time content is black,
          # then this slot is not used.
          # just skip - any onCall or onSetup already found will be
          # put into the first valid slot.
          next if colourToStatus(cf1)['colour'].downcase != 'white'
          # we are now working with a valid slot
          unless requiredSlot.empty?
            @schedule.push(requiredSlot.clone)
            requiredSlot.clear
          end
          logger.debug " --------" + si.inspect + "-----------"
          #now get the matching date from the responsedates array
          mydateserialnumber = responsedates.values[ri][0]
          mydate = Date.new(1899, 12, 30) + mydateserialnumber 
          c1 = getvalue(r.values[1])
          n = c1.match(/(\w+)\s+(\d+)(\d{2})$/im) # MONDAY 330
          dt = DateTime.new(mydate.year, mydate.month, mydate.day,
                          n[2].to_i, n[3].to_i)
          requiredSlot["timeslot"] = dt
          requiredSlot["location"] = si
          # Now that we have a slot created, check if this has been
          # the first oe for the day. i.e. there are on call and setup events
          # If so, we make them into a lesson and add them  to the slot.
          # Delete them when done.
          if(!onCall.empty? || !onSetup.empty?)
            requiredSlot["onCall"] = onCall.clone unless onCall.empty?
            requiredSlot["onSetup"] = onSetup.clone unless onSetup.empty?
            onCall.clear
            onSetup.clear
          end
          next
        end
        # any other rows are now standard lesson rows
        c1 = getvalue(r.values[1])     # tutor
        c2 = getvalue(r.values[2])     # student 1
        c4 = getvalue(r.values[4])     # student 2
        c6 = getvalue(r.values[6])     # lesson comment
        cf1 = getformat(r.values[1])
        cf2 = getformat(r.values[2])
        cf4 = getformat(r.values[4])
        # store colours for cells of interest
        [1,2,3,4,5,6].each do |j|
          storecolours.call(j)
        end
        thisLesson["tutor"] = [c1,cf1] if c1 != ""
        if c2 != "" || c4 != ""       #student/s present
          thisLesson["students"] = Array.new()
          thisLesson["students"].push([c2,cf2]) if c2 != ""
          thisLesson["students"].push([c4,cf4]) if c4 != ""
        end
        thisLesson["comment"] = c6 if c6 != ""
        requiredSlot["lessons"] = Array.new() unless requiredSlot["lessons"] 
        requiredSlot["lessons"].push(thisLesson.clone) unless thisLesson.empty?
        thisLesson.clear
      end
      unless requiredSlot.empty?
        @schedule.push(requiredSlot.clone)
        requiredSlot.clear
      end
      #break       # during dev only - only doing one site
    end
    # cache the tutors and students for laters processing by the utilities.
    @tutors = Tutor.all
    @students = Student.all
  
    # Now start the database updates using the info in @schedule
    # Note:
    #       my...   = the info extracted from @schedule
    #       this... = the database record 
    
    # slot info
    @schedule.each do |r|
      mylocation = r["location"]
      mytimeslot = r["timeslot"] 
      thisslot = Slot.where(location: mylocation, timeslot: mytimeslot).first
      r["slot_updates"] = ""
      unless thisslot    # none exist
        thisslot = Slot.new(timeslot: mytimeslot, location: mylocation)
        if thisslot.save
          r["slot_updates"] = "slot created"
        else
          r["slot_updates"] = "slot creation failed"
        end
      else
        r["slot_updates"] = "slot exists - no change"
      end
      # Now load lessons (create or update)
      # first up is the "On Call"
      # these will have a lesson status of "oncall"
      # ["DAVID O\n| E12 M12 S10 |"]
      if(mylesson = r["onCall"])
        r["onCallupdates"] = ""
        mytutornamecontent = findTutorNameComment(mylesson, @tutors)
        # check if there was a tutor found.
        # If not, then we add any comments to the lesson comments.
        lessoncomment = ""
        if mytutornamecontent[0]["name"] == "" && 
           mytutornamecontent[0]["comment"].strip != ""
            lessoncomment = mytutornamecontent[0]["comment"]
        end
        if mytutornamecontent[0]["name"] != "" || 
           lessoncomment != ""
            # something to put in lesson so ensure it exists - create if necessary
          thislesson = Lesson.where(slot_id: thisslot.id, status: "onCall").first
          unless thislesson
            thislesson = Lesson.new(slot_id: thisslot.id,
                                    status: "onCall",
                                    comments: lessoncomment)
            thislesson.save
          end
        end
        # Now load in the tutors - if any
        mytutornamecontent.each do |te|
          # need tutor record - know it exists if found here
          if te['name']
            # create a tutrole record if not already there
            thistutor = Tutor.where(pname: te['name']).first # know it exists
            mytutorcomment = te['comment']
            # determine if this tutrole already exists
            thistutrole = Tutrole.where(lesson_id: thislesson.id,
                                        tutor_id:   thistutor.id
            ).first
            if thistutrole      # already there
              if thistutrole.comment == mytutorcomment
                r["onCallupdates"] += "|no change|"
              else
                if thistutrole.update(comment: mytutorcomment)
                  r["onCallupdates"] += "|updated tutrole|"
                else
                  r["onCallupdates"] += "|updated failed|"
                end
              end
            else                # need to be created
              thistutrole = Tutrole.new(lesson_id: thislesson.id,
                                        tutor_id:   thistutor.id,
                                        comment: mytutorcomment,
                                        status: "onCall")
              if thistutrole.save
                r["onCallupdates"] = "|created|"
              else
                r["onCallupdates"] = "|creation failed|"
              end
            end
          end
        end
      end
      # second up is the "Setup"
      # these will have a lesson status of "oncall"
      # ["DAVID O\n| E12 M12 S10 |"]
      if(mylesson = r["onSetup"])
        r["onSetupupdates"] = ""
        mytutornamecontent = findTutorNameComment(mylesson, @tutors)
        # check if there was a tutor found.
        # If not, then we add any comments to the lesson comments.
        lessoncomment = ""
        if mytutornamecontent[0]["name"] == "" && 
           mytutornamecontent[0]["comment"].strip != ""
            lessoncomment = mytutornamecontent[0]["comment"]
        end
        if mytutornamecontent[0]["name"] != "" || 
           lessoncomment != ""
            # something to put in lesson so ensure it exists - create if necessary
          thislesson = Lesson.where(slot_id: thisslot.id, status: "onSetup").first
          unless thislesson
            thislesson = Lesson.new(slot_id: thisslot.id,
                                    status: "onSetup",
                                    comments: lessoncomment)
            thislesson.save
          end
        end
        # Now load in the tutors - if any
        mytutornamecontent.each do |te|
          # need tutor record - know it exists if found here
          if te['name']
            # create a tutrole record if not already there
            thistutor = Tutor.where(pname: te['name']).first # know it exists
            mytutorcomment = te['comment']
            # determine if this tutrole already exists
            thistutrole = Tutrole.where(lesson_id: thislesson.id,
                                        tutor_id:   thistutor.id
            ).first
            if thistutrole      # already there
              if thistutrole.comment == mytutorcomment
                r["onSetupupdates"] += "|no change|"
              else
                if thistutrole.update(comment: mytutorcomment)
                  r["onSetupupdates"] += "|updated tutrole|"
                else
                  r["onSetupupdates"] += "|updated failed|"
                end
              end
            else                # need to be created
              thistutrole = Tutrole.new(lesson_id: thislesson.id,
                                        tutor_id:   thistutor.id,
                                        comment: mytutorcomment,
                                        status: "onSetup")
              if thistutrole.save
                r["onSetupupdates"] = "|created|"
              else
                r["onSetupupdates"] = "|creation failed|"
              end
            end     # if thistutrole
          end
        end
      end         # end onSetup      
      # third is standard lessons
      # these will have a lesson status of that depends on colour
      # which gets mapped into a status
      # ["DAVID O\n| E12 M12 S10 |"]
      # mylessons = 
      #[{tutor   =>[name, colour], 
      #  students=>[[name, colour],[name, colour]],
      #  comment => ""
      #  }, ...{}... ]
      #
      #
      #{"tutor"=>["ALLYSON B\n| M12 S12 E10 |",
      #           #<Google::Apis::SheetsV4::Color:0x00000003ef3c80 
      #           @blue=0.95686275, @green=0.7607843, @red=0.6431373>],
      # "students"=>[
      #           ["Mia Askew 4", 
      #           #<Google::Apis::SheetsV4::Color:0x00000003edeab0 
      #           @blue=0.972549, @green=0.85490197, @red=0.7882353>],
      #           ["Emily Lomas 6", 
      #           #<Google::Apis::SheetsV4::Color:0x00000003eb06d8 
      #           @blue=0.827451, @green=0.91764706, @red=0.8509804>]],
      # "comment"=>"Emilija away"
      #}
      #

      # first we need to see if there are already lessons
      # for this tutor in this slot (except Setup & oncall)
      # Check procedure
      # 1. Get all lessons from database in this slot
      # 2. From the database for these lessons, we cache
      #    a) all the tutroles   (tutors) 
      #    b) all the roles      (students)
      #    Tutroles query excludes status "onSetup" & "onCall"
      #    Note: tutroles hold: sessin_id, tutor_id, status, comment
      # 3. Loop through each lesson from the spreadsheet and check
      #    Note: if tutor in ss, but not found in database, then add
      #          as a comment; same for students
      #    a) if tutor or student in the ss for this lesson has either
      #       a tutor or student in the database, then that is the 
      #         lesson to use, ELSE we create a new lesson.
      #       This is then the lesson we use for the following steps
      #    b) for my tutor in ss, is there a tutrole with this tutor
      #       If so, update the tutrole with tutor comments (if changed)
      #       If not,
      #              i)  create a lesson in this slot
      #              ii) create a tutrole record linking lesson and tutor
      #       Note 1: This lesson is then used for the students.
      #               If a student is found in a different lesson in this
      #               slot, then they are moved into this lesson.
      #       Note 2: there could be tutrole records in db that are not in ss.
      # ---------------------------------------------------------------------
      # Step 1: get all the lessons in this slot
      thislessons = Lesson.where(slot_id: thisslot.id)
      # Step 2: get all the tutrole records for this slot
      #alltutroles = Tutrole.where(lesson_id: thislessons.ids)
      alltutroles = Tutrole.where(lesson_id: thislessons.ids).
                       where.not(status: ['onSetup', 'onCall'])
      allroles    = Role.where(lesson_id: thislessons.ids)
      # Step 3:
      if(mylessons = r["lessons"])   # this is all the standard
                                       # ss lessons in this slot
        mylessons.each do |mysess|    # treat lesson by lesson
          thislesson = nil            # ensure all reset
          mylessoncomment = ""
          #
          #   Process students
          #
          # Step 3a - check if tutors present
          # if so, this is the lesson to hang onto.
          # Will check later if the students are in the same lesson.
          flagtutorpresent = flagstudentpresent = FALSE
          #
          #   Process tutor
          #
          mytutor = mysess["tutor"] # only process if tutor exists
                                       # mytutor[0] is ss name string,
          mytutorcomment = ""         # provide full version in comment
          if mytutor                             # mytutor[1] is colour
            mytutorcomment = mytutor[0]
            mytutornamecontent = findTutorNameComment(mytutor[0], @tutors) 
            mytutorstatus = colourToStatus(mytutor[1])["tutor"]
            if mytutornamecontent.empty?  ||  # no database names found for this tutor
               mytutornamecontent[0]['name'] == ""
                # put ss name string into lesson comment
                mylessoncomment += mytutor[0] 
            else
              flagtutorpresent = TRUE
              thistutor = Tutor.where(pname: mytutornamecontent[0]["name"]).first
              thistutroles = alltutroles.where(tutor_id: thistutor.id)
              if thistutroles.empty?   # none there, so create one
                # Step 4ai: Create a new lesson
                thislesson = Lesson.new(slot_id: thisslot.id,
                                          status: 'standard')
                thislesson.save
                thistutrole = Tutrole.new(lesson_id: thislesson.id,
                                          tutor_id:   thistutor.id,
                                          comment: mytutorcomment,
                                          status: mytutorstatus)
                if thistutrole.save
                  r["tutroleupdates"] = "|created|"
                else
                  r["tutroleupdates"] = "|creation failed|"
                end
              else  # already exist
                r["tutroleupdates"] = ""
                thistutroles.each do |thistutrole1|
                  # get the lesson they are in
                  thislesson = Lesson.find(thistutrole1.lesson_id)
                  if thistutrole1.comment == mytutorcomment &&
                     thistutrole1.status  == mytutorstatus
                    r["tutroleupdates"] += "|no change|"
                  else
                    if thistutrole1.comment != mytutorcomment
                      thistutrole1.update(comment: mytutorcomment)
                    end
                    if thistutrole1.status != mytutorstatus
                      thistutrole1.update(status: mytutorstatus)
                    end
                    if thistutrole1.save
                      r["tutroleupdates"] += "|updated tutrole|"
                    else
                      r["tutroleupdates"] += "|update failed|"
                    end
                  end
                end     # thistutroles.each 
              end   # if thistutroles.emepty?
            end
          end
          #
          #   Process students
          #
          mystudents = mysess["students"]
          unless mystudents == nil || mystudents.empty?   # there are students in ss
            mystudents.each do |mystudent|                # precess each student
              mystudentcomment = ""
              mystudentstatus  = colourToStatus(mystudent[1])["student"]
              mystudentnamecontent = findStudentNameComment(mystudent[0], @students) 
              if mystudentnamecontent.empty?  ||  # no database names found for this student
                 mystudentnamecontent[0]['name'] == ""
                # put ss name string into lesson comment
                mylessoncomment += mystudent[0] 
              else
                flagstudentpresent = TRUE    # we have students
                thisstudent = Student.where(pname: mystudentnamecontent[0]["name"]).first
                logger.debug "thisstudent: " + thisstudent.inspect
                thisroles = allroles.where(student_id: thisstudent.id)
                # CHECK if there is already a lesson from the tutor processing 
                # Step 4ai: Create a new lesson ONLY if necessary
                unless thislesson
                  thislesson = Lesson.new(slot_id: thisslot.id,
                                            status: 'standard')
                  thislesson.save
                end
                if thisroles.empty?   # none there, so create one
                  thisrole = Role.new(lesson_id: thislesson.id,
                                      student_id:   thisstudent.id,
                                      comment: mystudentcomment,
                                      status: mystudentstatus)
                  if thisrole.save
                    r["roleupdates"] = "|created|"
                  else
                    r["roleupdates"] = "|creation failed|"
                  end
                else  # already exist
                  r["roleupdates"] = ""
                  thisroles.each do |thisrole1|
                    # An additional check for students
                    # If a student is allocated to a different tutor
                    # in the db, then we will move them to this tutor
                    # as per the spreadsheet.
                    # Note that a student cannot be in a lesson twice.
                    if thislesson.id != thisrole1.lesson_id
                      # move this tutrole
                      if thisrole1.update(lesson_id: thislesson.id)
                        r["roleupdates"] += "|role move updated|"
                      else
                        r["roleupdates"] += "|role move failed|"
                      end
                    end
                    if thisrole1.comment == mystudentcomment &&
                       thisrole1.status  == mystudentstatus
                      r["roleupdates"] += "|no change|"
                    else
                      if thisrole1.comment != mystudentcomment
                        thisrole1.update(comment: mystudentcomment)
                      end
                      if thisrole1.status != mystudentstatus
                        thisrole1.update(status: mystudentstatus)
                      end
                      if thisrole1.save
                        r["roleupdates"] += "|updated tutrole|"
                      else
                        r["roleupdates"] += "|update failed|"
                      end
                    end
                  end     # thisroles.each 
                end   # if thisroles.emepty?
              end
            end
          end
          #
          #   Process comments
          #
          if mysess["comment"]
            mycomments = mysess["comment"] 
            mylessoncomment += mycomments if mycomments != ""
          end
          # process comments - my have been generated elsewhere (failed tutor
          # and student finds, etc. so still need to be stored away 
          if mylessoncomment != ""    # some lesson comments exist
            # if no lesson exists to place the comments
            # then we need to build one.
            unless thislesson
              # let's see if there is a lesson with this comment
              # looking through the lessons for this slot that do
              # not have a tutor or student
              # Need the sessin that have no tutor or student - already done
              allcommentonlylessons = thislessons -
                  thislessons.joins(:tutors, :students).distinct
              # now to see if this comment is in one of these
              allcommentonlylessons.each do |thiscommentlesson|
                if thiscommentlesson.comments == mylessoncomment
                  thislesson = thiscommentlesson
                  break
                end
              end
            end
            # see if we now have identified a lesson for this comment
            # create one if necessary
            unless thislesson
              thislesson = Lesson.new(slot_id: thisslot.id,
                                        status: 'standard')
              thislesson.save
            end
            r["commentupdates"] = ""
            if mylessoncomment == thislesson.comments
                r["commentupdates"] += "|no change|"
            else
              thislesson.update(comments: mylessoncomment)
              if thislesson.save
                r["commentupdates"] += "|updated comment|"
              else
                r["commentupdates"] += "|comment update failed|"
              end             
            end
          end
        end
      end
    end
  end
#---------------------------------------------------------------------------
#
#   Load Test
#
#   This is simply to allow some testing
#   Look at the test spreadsheet
#
#---------------------------------------------------------------------------
  # GET /admins/loadschedule
  def loadtest
    service = googleauthorisation(request)
    spreadsheet_id = '10dXs-AT-UiFV1OGv2DOZIVYHEp81QSchFbIKZkrNiC8'
    sheet_name = 'New Sheet Name'
    range = "#{sheet_name}!A7:C33"
    Rails.logger.level = 1 
    response = service.get_spreadsheet(
      spreadsheet_id,
      ranges: range,
      fields: "sheets(data.rowData.values" + 
      "(formattedValue,effectiveFormat.backgroundColor))"
    )
    Rails.logger.level = 0
    # Now scan each row read from the spreadsheet in turn

    @output = Array.new()
    rowarray = Array.new()
    cellcontentarray = Array.new(3)
    response.sheets[0].data[0].row_data.map.with_index do |r, ri| # value[], row index
      # Now start processing the row content
      r.values.map.with_index do |mycell, cellindex|
        c0 = getvalue(mycell)
        cellcontentarray[0] = c0
        
        cf0 = getformat(mycell)
        cellcontentarray[1] = showcolour(cf0)
        cellcontentarray[2] = cf0

        logger.debug "c0: " + c0.inspect
        logger.debug "cf0: " + showcolour(cf0)
        logger.debug ""
        
        rowarray[cellindex] = cellcontentarray.clone
      end
      @output[ri] = rowarray.clone
    end
    logger.debug "@output: " + @output.inspect
    
    # Test some helpers
    logger.debug "------testing in controller-------------"
    [
      "Joshua Kerr",
      "Alexandra (Alex) Cosgrove 12",
      "Aanya Daga 4 (male)",
      "Riley Howatson 1 (female)",
      "Amelia Clark (kindy)",
      "Amelia Clark (kindy) (female)",
      "Amelia Clark kindy (female)",
      "Amelia Clark kindy female",
      "Amelia Clark 1 (female)",
      "Bill Clark 1 (male)",
      "Amelia Clark 1 female",
      "Elisha Stojanovski K",
      "Bella Parsonage Phelan 8",
      "Billy Johnson K (female)"
    ].each do |a|
        b = getStudentNameYearSex(a)
        logger.debug "name: " + a + "\n" + b.inspect 
    end
  end
end