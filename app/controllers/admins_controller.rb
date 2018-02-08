class AdminsController < ApplicationController
      include Googleutilities
  
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
    #byebug
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
    
=begin
    # second get the start of day rows and start of slot rows
    # from the first column
    range = "#{sheet_name}!A3:A"
    Rails.logger.level = 1 
    response = service.get_spreadsheet_values(spreadsheet_id, range, major_dimension: "COLUMNS")
    Rails.logger.level = 0 
    mycol = response.values[0]
    # pick up the column start of days and slottimes
    days = Array.new      # array of rows numbers starting the day
    slottimes = Array.new() # array of row number starting each slot
                           # index = row number, values = ssdate
                           # and datetime = datetime of the slot
    mydate = Date.new   # temp store only during loop processing
    rowDate = Hash.new()   # held for later use (outside of this loop)
    mycol.map.with_index do |v, i|
      # find days
      if v == week
        days.push(i)
      end
      if m = v.match(/(\d+)\/(\d+)\/(\d+)/)
        mydate = Date.new(m[3].to_i,m[1].to_i,m[2].to_i)
        slottimes.push({"row_start" => i,
                          "ssdate" => v, 
                          "datetime" =>  mydate.to_time
                          })
        rowDate[i] = mydate
      end
      if m = v.match(/(\w+)\n(\d+)(\d{2})$/im)
        dt = DateTime.new(mydate.year, mydate.month, mydate.day,
                          m[2].to_i, m[3].to_i)
        slottimes[slottimes.length-1]["datetime"] = dt
      end
    end
    #logger.debug "slottimes: " + slottimes.inspect
    #logger.debug "sites: " + sites.inspect
    #logger.debug "days: " + days.inspect
=end

    #this function converts spreadsheet indices to column name
    # examples: e[0] => A; e[30] => AE 
    e=->n{a=?A;n.times{a.next!};a}  

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
    thisSession = Hash.new()
    # @allColours is used in the view
    @allColours = Hash.new()
    # work through our sites, reading spreadsheet for each
    # and extract the slots, sessions, tutors and students
    # We also get the session notes.
    # At the beginning of each day, we get the on call and
    # setup info
    sites.each do |si, sv|  # site name, {col_start}
      mystartcol = e[sv["col_start"]]
      myendcol = e[sv["col_start"] + colsPerSite - 1]
      # ****************** temp seeting during development
      # restrict output 
      range = "#{sheet_name}!#{mystartcol}3:#{myendcol}60"
      # becomes for production
      #range = "#{sheet_name}!#{mystartcol}3:#{myendcol}"
      Rails.logger.level = 1 
      response = service.get_spreadsheet(
        spreadsheet_id,
        ranges: range,
        fields: "sheets(data.rowData.values" + 
        "(formattedValue,effectiveFormat.backgroundColor))"
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
            col = [cf.red,cf.green,cf.blue]
            @allColours[col] ? 
              @allColours[col][2] += 1 :
              @allColours[col] = [e[j + sv["col_start"]],3+ri,1]
          end
        }
        # Now start processing the row content
        c0 = getvalue1(r.values[0])
        if c0 == week     # this is the first row of the day e.g. T3W1
          storecolours.call(1)
          next
        end
        if c0 == "ON CALL"     # we are on "ON CALL" row e.g. T3W1
          storecolours.call(1)
          for i in 1..7 do     # keep everything on row
            cv = getvalue1(r.values[i])
            onCall.push(cv) if cv != ""
          end
          next
        end
        if c0 == "SETUP"     # we are on "ON CALL" row e.g. T3W1
          storecolours.call(1)
          for i in 1..7 do   # keep everything on row
            cv = getvalue1(r.values[i])
            onSetup.push(cv) if cv != ""
          end
          next
        end
        # look for date row - first row for slot e.g 7/18/2016
        if m = c0.match(/(\d+)\/(\d+)\/(\d+)/)
          unless requiredSlot.empty?
            @schedule.push(requiredSlot.clone)
            requiredSlot.clear
          end
          c1 = getvalue1(r.values[1])
          n = c1.match(/(\w+)\s+(\d+)(\d{2})$/im) # MONDAY 330
          mydate = Date.new(m[3].to_i,m[1].to_i,m[2].to_i)
          #logger.debug "mydate : " + mydate.inspect +
          #           "\nnewdate: " + newdate.inspect + 
          #           "\n------------------------------"
          dt = DateTime.new(mydate.year, mydate.month, mydate.day,
                          n[2].to_i, n[3].to_i)
          requiredSlot["timeslot"] = dt
          requiredSlot["location"] = si
          # Now that we have a slot created, check if this has been
          # the first oe for the day. i.e. there are on call and setup events
          # If so, we make them into a session and add them  to the slot.
          # Delete them when done.
          if(!onCall.empty? || !onSetup.empty?)
            requiredSlot["onCall"] = onCall.clone unless onCall.empty?
            requiredSlot["onSetup"] = onSetup.clone unless onSetup.empty?
            onCall.clear
            onSetup.clear
          end
          next
        end
        # any other rows are now standard session rows
        c1 = getvalue1(r.values[1])     # tutor
        c2 = getvalue1(r.values[2])     # student 1
        c4 = getvalue1(r.values[4])     # student 2
        c6 = getvalue1(r.values[6])     # session comment
        cf1 = getformat1(r.values[1])
        cf2 = getformat1(r.values[2])
        cf4 = getformat1(r.values[4])
        # store colours for cells of interest
        #byebug
        [1,2,3,4,5,6].each do |j|
          storecolours.call(j)
        end
        thisSession["tutor"] = [c1,cf1] if c1 != ""
        if c2 != "" || c4 != ""       #student/s present
          thisSession["students"] = Array.new()
          thisSession["students"].push([c2,cf2]) if c2 != ""
          thisSession["students"].push([c4,cf4]) if c4 != ""
        end
        thisSession["comment"] = c6 if c6 != ""
        requiredSlot["sessions"] = Array.new() unless requiredSlot["sessions"] 
        requiredSlot["sessions"].push(thisSession.clone) unless thisSession.empty?
        thisSession.clear
      end
      unless requiredSlot.empty?
        @schedule.push(requiredSlot.clone)
        requiredSlot.clear
      end
      break       # during dev only - only doing one site
    end
=begin
    logger.debug "Print out @schedule"
    @schedule.each do |slot|
      logger.debug "------------schedule -> slot ---------------"
      logger.debug slot.inspect
    end
=end
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
    range = "#{sheet_name}!A1:B5"
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
    cellcontentarray = Array.new(2)
    response.sheets[0].data[0].row_data.map.with_index do |r, ri| # value[], row index
      # Now start processing the row content
      r.values.map.with_index do |mycell, cellindex|
        #c0 = getvalue.call(0)
        #c0 = getvalue1(r.values(0))
        c0 = getvalue1(mycell)
        cellcontentarray[0] = c0
        
        #cf0 = getformat.call(0)
        cf0 = getformat1(mycell)
        cellcontentarray[1] = showcolour(cf0)

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
