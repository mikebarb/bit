class AdminsController < ApplicationController
  include Googleutilities
  include Calendarutilities

  #skip_before_action :authenticate_user!, only: [:home]
  #before_filter :set_user_for_models
  #after_filter :reset_user_for_models
  # before_filter is depreciated in rails 5.1
  before_action :set_user_for_models
  after_action :reset_user_for_models

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
#   Check Chains
#
#---------------------------------------------------------------------------
  # GET /admins/checkchains
  def checkchains
    # show oldest date in database and youngest date in database
    @oldestdate      = Slot.order(:timeslot).first.timeslot
    @newestdate      = Slot.order(:timeslot).reverse_order.first.timeslot
    @oldestslotchain = Slot.order(:timeslot).where.not(first: nil).first.timeslot
    # warn if all the wpos are not in the same week
    @slotwpoweeks = Slot.select(:timeslot).where.not(wpo: nil).map{|o| o.timeslot.to_datetime.cweek}.uniq
    @slotwpofirst = Slot.select(:timeslot).where.not(wpo: nil).order(:timeslot).first
    @slotwpolast = Slot.select(:timeslot).where.not(wpo: nil).order(:timeslot).last
    
    # Checking  options
    flagCheckwpos              = false    # true to check, false to ignore
    flagCheckSlots             = false
    flagCheckLessons           = false
    flagCheckTutroles          = false
    
    flagCheckNilTerminate      = false    # true to fix, false to monitor
    flagCheckLessonDisconnects = false    # true to fix, false to monitor
    flagcheckshortchains       = false    # true to fix, false to monitor

    # Fixing options
    flagFixNilTerminate        = true    # true to fix, false to monitor
    flagFixLessonDisconnects   = true    # true to fix, false to monitor
    flagfixwpos                = true     # true to fix, false to monitor

    @errors              = Array.new   # keep track of errors.
    @displayshort        = Array.new
    @displayshortlesson  = Array.new
    @displayshorttutrole = Array.new

    #----------------- show wpo entries -------------------------------
    @wpos = Array.new
    if flagCheckwpos
      # wpo = week + one
      wposlots = Slot.where.not(wpo: nil).order(:location, :timeslot)
      #@wpos = wposlots.map{|o| [o.id, o.wpo, o.first, o.location, o.timeslot]}  
      wposlots.each do |s|
        if s.first == s.wpo   # this should not happen  
          @wpos.push([s.id, s.wpo, s.first, s.location, s.timeslot, "problem case"])
          if flagfixwpos
            @wpos.push("Fix this wpo - set to nil")
            s.wpo = nil
            s.save
          end
        else
          @wpos.push([s.id, s.wpo, s.first, s.location, s.timeslot])
        end
      end
    end    

    #----------------- slot chains -------------------------------
    if flagCheckSlots    
      # deal with slots
      # get all the 'first' ids in the database 
      checkslotchains = Slot.select(:first).where.not(first: nil).distinct
      @numberofchains_slots = checkslotchains.count
      # Now check each chain
      checkslotchains.each do |firstslot|   # step through chains - one by one 
        #byebug
        thischain = Slot.where(first: firstslot.first)  # all links in the chain
        chainindex = Hash.new     # index chain links by link.id
        thischain.each do |link|
          chainindex[link.id] = link
        end
        unless chainindex.has_key?(firstslot.first) # ensure first link exists!
          @errors.push(firstslot.first.to_s + " block " + firstslot.to_s + "is missing first link")
          next     # finish work on this chain - go to next chain
        end
        thislink = chainindex[firstslot.first]    # now check the linkages flow
        if thislink.next.nil? # single link chain
          if chainindex.length != 1   # check that it should be
            @errors.push(firstslot.first.to_s + " chain too short " + thislink.inspect)
          end
          next    # all OK - go to next chain
        end
        
        # now setp through rest of this chain checking flows and length
        linkcount = 1
        while chainindex.has_key?(thislink.next)  # next link exists 
          #byebug
          thislink = chainindex[thislink.next]             # select next link
          linkcount += 1
          if thislink.next.nil? # last link in chain
            if chainindex.length != linkcount   # check that it should be
              @errors.push(firstslot.first.to_s +  " chain too short " + thislink.inspect)
            end
            next    # all OK - go to next chain
          end
        end
        if chainindex.length != linkcount
          @errors.push(firstslot.first.to_s + "chain length error " + firstslot.inspect)
        end
        if !thislink.next.nil?    # check last link encounted has next == nil
          @errors.push(firstslot.first.to_s + " chain not nil terminated " + thislink.inspect)
          if flagFixNilTerminate
            thislink.next = nil
            thislink.save
          end
        end
  
      end
    end    
    @numberoferrors_slots = @errors.count
    
    #----------------- lesson chains -------------------------------
    if flagCheckLessons
      @lessonlinkerroroccurred = false
      @keepshortchain = Array.new   # keep instances of short chain errors
      #byebug
      # deal with lessons
      # get all the 'first' ids in the database 
      checklessonchains = Lesson.select(:first).where.not(first: nil).distinct
      @numberofchains_lessons = checklessonchains.count
      # Now check each chain
      count = 0
      checklessonchains.each do |firstlesson|   # step through chains - one by one 
        count += 1
        #break if count > 100
        #byebug
        thischain = Lesson.where(first: firstlesson.first)  # all links in the chain
        chainindex = Hash.new     # index chain links by link.id
        thischain.each do |link|
          chainindex[link.id] = link
        end
        unless chainindex.has_key?(firstlesson.first) # ensure first link exists!
          @errors.push(firstlesson.first.to_s + " block " + firstlesson.to_s + "is missing first link")
          next     # finish work on this chain - go to next chain
        end
        thislink = chainindex[firstlesson.first]    # now check the linkages flow
        if thislink.next.nil? # single link chain
          if chainindex.length != 1   # check that it should be
            @errors.push(firstlesson.first.to_s + " chain should be multiple links " + thislink.inspect)
            @keepshortchain.push(firstlesson.first)
            flagerror = true
          end
          next    # all OK - go to next chain
        end
        
        if flagCheckLessonDisconnects
          # now setup through rest of this chain checking flows and length
          linkcount = 1
          flagerror = false
          while chainindex.has_key?(thislink.next)  # next link exists 
            #byebug
            thislink = chainindex[thislink.next]    # select next link
            linkcount += 1
            if thislink.next.nil?                   # last link in chain
              if chainindex.length != linkcount     # check that it should be
                #byebug
                @errors.push(firstlesson.first.to_s +  " chain nil terminated - too short" + thislink.inspect)
                @keepshortchain.push(firstlesson.first)
                flagerror = true
              end
              next    # all OK - go to next link
            end
          end
          if !flagerror && (chainindex.length != linkcount)
            @errors.push(firstlesson.first.to_s + " chain length error " + firstlesson.inspect)
            @keepshortchain.push(firstlesson.first)
            flagerror = true
          end
          if !thislink.next.nil?    # check last link encounted has next == nil
            @errors.push(firstlesson.first.to_s + " chain not nil terminated " + thislink.inspect)
            @keepshortchain.push(firstlesson.first) unless flagerror
            if flagFixNilTerminate
              thislink.next = nil
              thislink.save
            end
          end
          @lessonlinkerroroccurred = true if flagerror == true
        end
      end
      
      @numberoferrors_lessons = @errors.count - @numberoferrors_slots
      @displayshortlesson = Array.new
      #return
      # analyse short chain errors
      if flagCheckLessonDisconnects && flagcheckshortchains
        @keepshortchain.each do |short|
          firstlink = Lesson.find(short)
          lessonchain = Lesson.includes(:slot, :students, :tutors).where(first: firstlink.first)  # all links in the chain
          lessonchainindex = Hash.new     # index chain links by link.id
          lessonchainnext = Hash.new
          leftlinks = Hash.new
          lessonchain.each do |link|
            lessonchainindex[link.id] = link
            lessonchainnext[link.next] = link
            leftlinks[link.id] = link 
          end
          
          # Put in a header for this chain      
          @displayshortlesson.push("--------------------------------------------------------------------------------------")
          @displayshortlesson.push(["slot_id", "location", "timeslot", "lesson id",
                              "first", "next", "students", "tutors"])
          # Work through this lesson chain
          thislink = firstlink    # begin with the first link
          @displayshortlesson.push([thislink.slot_id, thislink.slot.location,
                              thislink.slot.timeslot, thislink.id,
                              thislink.first, thislink.next,
                              thislink.students.count, thislink.tutors.count])
          leftlinks.delete(thislink.id)
          while lessonchainindex.has_key?(thislink.next)  # now work through rest using next linkage 
            thislink = lessonchainindex[thislink.next]    # select next link
            @displayshortlesson.push([thislink.slot_id, thislink.slot.location,
                                thislink.slot.timeslot, thislink.id,
                                thislink.first, thislink.next,
                                thislink.students.count, thislink.tutors.count])
            leftlinks.delete(thislink.id)
            if thislink.next.nil?                         # ? last link in chain
              break                                       # end of valid portion
            end
          end
          # Now process the invalid portion
          disconnectedlessons = Array.new   # keep list of invalid lessons
          flagpersonspresent = false
          @displayshortlesson.push("Now disconnected from first chain links")
          lastlink = nil                                  
          while leftlinks.count > 0                       # ? while links left
            leftlinks.each do |k, mylink|
              if lessonchainnext.has_key?(mylink.id)
                # OK thislink is part of chain ( there is a link before this  one)
              else
                # At the end of chain - though not set to nil
                lastlink = mylink
                break                                      # then keep it
              end
            end
            # now work our way BACK through the chain
            while !lastlink.nil? && lessonchainindex.has_key?(lastlink.id)  # next link exists 
              countstudents = lastlink.students.count
              counttutors = lastlink.tutors.count
              flagpersonspresent = true if countstudents + counttutors > 0
              if lastlink.slot_id.nil?
                @displayshortlesson.push([lastlink.slot_id, "-",
                                    "-", lastlink.id, 
                                    lastlink.first, lastlink.next, 
                                    countstudents, counttutors])
              else
                @displayshortlesson.push([lastlink.slot_id, lastlink.slot.location,
                                    lastlink.slot.timeslot, lastlink.id, 
                                    lastlink.first, lastlink.next, 
                                    countstudents, counttutors])
              end
              leftlinks.delete(lastlink.id)
              disconnectedlessons.push(lastlink.id)   # keep track of lessons to possibley be removed
              lastlink = lessonchainindex[lastlink.next]             # select next link
            end
            if flagFixLessonDisconnects
              if !flagpersonspresent  # NO tutors or students present in lessons
                @displayshortlesson.push("removed lessons "+ disconnectedlessons.inspect )
                Lesson.where(id: disconnectedlessons).delete_all
              else
                @displayshortlesson.push("CANNOT remove lessons as tutors or students present." )
              end
            end
          end
        end
      end
    end
    
    #----------------- tutrole chains -------------------------------
    @tutrolelinkerroroccurred = false
    @keepshortchaintutrole = Array.new   # keep instances of short chain errors
    
    # get all the 'first' ids in the database for tutroles (tutor related info) 
    checktutroleblocks = Tutrole.select(:block).where.not(block: nil).distinct
    @numberofblocks_tutroles = checktutroleblocks.count
    # Now check each block
    count = 0
    checktutroleblocks.each do |firsttutrole|   # step through blocks - one by one 
      flagerror = false
      count += 1
      #break if count > 2
      thisblock = Tutrole.where(block: firsttutrole.block)  # all links in the block
      blockindex = Hash.new      # track every link in the block - index by link id
      segmentcount = Hash.new    # count links in segment - indexed by first link in segment
      segmentfirst = Hash.new    # track first link for each segment
      segmentlast = Hash.new     # track terminating link for each segment
      thisblock.each do |link|   # step through evey link in block
        blockindex[link.id] = link   # index to all links in block
        # segment index - show each segment indexed by first link in segment
        if segmentcount.has_key?(link.first)    # first link in segment
          segmentcount[link.first] += 1         # count links in segment
        else
          segmentcount[link.first] = 1
        end
        if link.first == link.id        # first link in segment
          if segmentfirst.has_key?(link.first)
            @errors.push(firsttutrole.block.to_s + " block " + link.first.to_s + "segment has duplicate first link")
            flagerror = true
            next #
          else
            segmentfirst[link.first] = link # keep track of segment first link
          end
        end
        if link.next.nil?        # terminating link
          if segmentlast.has_key?(link.first)
            @errors.push(firsttutrole.block.to_s + " block " + link.first.to_s + " segment has duplicate terminations")
            flagerror = true
          else
            segmentlast[link.first] = link # keep track of segment terminations
          end
        end
      end
      #Do some elementaty sanity checkslotchains
      segmentcount.each do |k,v|                 # checking every segment
        unless segmentfirst.has_key?(k)          # has a valid first link
          @errors.push(firsttutrole.block.to_s + " block " + k.to_s +
                       "segment has no valid first link")
          flagerror = true
        end
        unless segmentlast.has_key?(k)          # has a valid terminating link
          @errors.push(firsttutrole.block.to_s + " block " + k.to_s +
                       " segment has no valid termination")
          #flagerror = true  # don't terminate as can be fixed.
        end
      end
      next if flagerror           # if any errors so far, go to next block
                
      # Now check segment flows
      # above checks make this simpler - begin and end are trusted
      linkcount = 0   # get scope at this level
      segmentcount.each do |k,v|    # checking every segment
        thislink = blockindex[k]    # first link in segment
        # now setup through rest of this chain checking flows and length
        linkcount = 1
        flagerror = false
        while !thislink.next.nil?   # another link in segment expected
          if blockindex.has_key?(thislink.next)   # next link is valid
            thislink = blockindex[thislink.next]  # select next link
            linkcount += 1                        # count link processed in segment
          else                                    # error - expected link not found
            @errors.push(firsttutrole.block.to_s + " block " + k.to_s +
                         " segment expected link not found " + thislink.id.to_s)
            @keepshortchaintutrole.push(k)
            flagerror = true
          end
          if linkcount == segmentcount[k] &&  # now processed all stored links in segment
             !thislink.next.nil?              # and this last link is not nil terminated
            @errors.push(firsttutrole.block.to_s + " block " + k.to_s +
                         " segment last link is not null terminated " + thislink.id.to_s)
            @keepshortchaintutrole.push(k)
            flagerror = true
            if (!(thislink.next.nil?))              # but is not nil terminated
              if flagFixNilTerminate
                @errors.push(firsttutrole.block.to_s + " block " + k.to_s +
                             " FIXING - segment last link requires nil termination " +
                             thislink.id.to_s)
                thislink.next = nil
                thislink.save
              else
                @errors.push(firsttutrole.block.to_s + " block " + k.to_s +
                             " segment last link requires nil termination " +
                             thislink.id.to_s)
              end
            end
            break
          end
        end
        # segmented terminated - check links processed matches no. of links found
        # for this segment in the database
        if linkcount != segmentcount[k]   # length decrepency
          @errors.push(firsttutrole.block.to_s + " block " + k.to_s +  
                       " segment has wrong length " + thislink.inspect)
          @keepshortchaintutrole.push(k)
          flagerror = true
        end
        @tutrolelinkerroroccurred = true if flagerror == true
      end
    end
    
    @errors.each do |o|
      logger.debug o.inspect
    end
    logger.debug "-------------------------------------------"
    @displayshortlesson.each do |o|
      logger.debug o.inspect
    end
  end



#---------------------------------------------------------------------------
#
#   Delete Old Data up to a provided date - Edit parameters 
#
#---------------------------------------------------------------------------
  # GET /admins/deleteolddata
  def deleteolddataedit
    # show oldest date in database and youngest date in database
    @oldestdate      = Slot.order(:timeslot).first.timeslot
    @newestdate      = Slot.order(:timeslot).reverse_order.first.timeslot
    @oldestslotchain = Slot.order(:timeslot).where.not(first: nil).first.timeslot
  end


#---------------------------------------------------------------------------
#
#   Delete Old Data up to a provided date- do the deletes
#
#---------------------------------------------------------------------------
  # GET /admins/deleteolddata
  def deleteolddata
    @result = ""
    if deleteolddata_params["to"] == ""
      @result = "Failed to pass required parameter (date)!"
      return
    end
    @startdatetokeep = deleteolddata_params["to"].to_date
    
    if @startdatetokeep > DateTime.now - 365.days
      @result = "You must keep at least one year of data!"
      return
    end
  
    @startdatetokeep = deleteolddata_params["to"].to_date
    @checkdate = @startdatetokeep
    # First of all, we must unlink any chains that cross this date.
    # A chain link must exist in every week. Thus we must do this for each
    # day of this week. 
    # Because of this, we force the @startdatetokeep to be a Monday
    # and then break the chain for every day in this week.
    # Architecture facts: 
    #   a chain link cannot exist twice in the same week.
    #   a chain must have a parent chain (except slots)
    
    thisdayofweek = @startdatetokeep.wday
    if thisdayofweek == 0
      @startdatetokeep = @startdatetokeep + 1.day
    else
      @startdatetokeep = @startdatetokeep - (thisdayofweek - 1).day
    end
    # Process day at a time - Monday first then next for 7 days.
    @basecheckdate = @startdatetokeep
    for offsetdays in 0..6
      @checkdate = @basecheckdate + offsetdays.days
      logger.debug "check chains for " + @checkdate.inspect
      
      # get all slots that are part of a chain
      checkslots    = Slot.where("timeslot > ? AND
                                  timeslot < ? ",
                                  @checkdate.beginning_of_day,
                                  @checkdate.end_of_day)
                          .where.not(first: nil)
      # get all lessons in these slots that are part of a chain
      checklessons  = Lesson.where(slot_id: checkslots.map{|o| o.id})
                            .where.not(first: nil)
      # get all student roles in these lessons that are part of a chain
      checkroles =    Role.where(lesson_id: checklessons.map{|o| o.id})
                          .where.not(first: nil)
      # get all tutor tutroles in these lessons that are part of a chain
      checktutroles =    Tutrole.where(lesson_id: checklessons.map{|o| o.id})
                          .where.not(first: nil)

      # Break the chains for the slots
      checkslots.each do |slot|
        if slot.id != slot.first   # not first element in chain
          # for slots, make this the first element in the chain
          #slots_to_update = Slot.where(first: slot.first)
          Slot.where(first: slot.first).update_all(first: slot.id)
        end
      end
      # Break the chains for the lessons
      checklessons.each do |lesson|
        if lesson.id != lesson.first   # not first element in chain
          # for lessons, make this the first element in the chain
          #lessons_to_update = Lesson.where(first: lesson.first)
          Lesson.where(first: lesson.first).update_all(first: lesson.id)
        end
      end
      # Break the chains for the student roles
      # for roles and tutroles, there can be multiple chain segments 
      # within the chain block. For the first chain in the set,
      # first and block will be equal. Subsequent segments has
      # and block different. Block will identify all chain segments
      # in this chain.
      checkroles.each do |role|
        flag_first_in_block   = role.id    == role.block ? true : false
        flag_first_in_segment = role.id    == role.first ? true : false 
        flag_first_segment    = role.first == role.block ? true : false
        # if first element in block, then nothing to do.
        if !flag_first_in_block   # break chain, not first in block
          # No matter where it it broken, the block needs updating
          # this element id will become the block value for this block
          role_to_update_block = Role.where(block: role.block)
          #Role.where(block: role.block).update_all(block: role.id)
          if !flag_first_in_segment # not first element in segment
            # this element id will become the first value for this segment
            #role_to_update_first = Role.where(first: role.first)
            Role.where(first: role.first).update_all(first: role.id)
          end
        end
      end

      checktutroles.each do |tutrole|
        flag_first_in_block   = tutrole.id    == tutrole.block ? true : false
        flag_first_in_segment = tutrole.id    == tutrole.first ? true : false 
        flag_first_segment    = tutrole.first == tutrole.block ? true : false
        # if first element in block, then nothing to do.
        if !flag_first_in_block   # break chain, not first in block
          # No matter where it it broken, the block needs updating
          # this element id will become the block value for this block
          tutrole_to_update_block = Tutrole.where(block: tutrole.block)
          #Tutrole.where(block: tutrole.block).update_all(block: tutrole.id)
          if !flag_first_in_segment # not first element in segment
            # this element id will become the first value for this segment
            #tutrole_to_update_first = Tutrole.where(first: tutrole.first)
            Tutrole.where(first: tutrole.first).update_all(first: tutrole.id)
          end
        end
      end
      
    end

    # Get all the slots (ids) for the deletion period.
    removeslots    = Slot.select(:id).where("timeslot < :end_date",
                                            {end_date: @startdatetokeep})
    # Get all the lessons (ids) in the slots for this deletion period.
    removelessons  = Lesson.select(:id).where(slot_id: removeslots.map{|o| o.id})
    # Remove all the tutroles (tutors allocated) in these lessons
    #removetutroles = Tutrole.select(:id).where(lesson_id: removelessons.map{|o| o.id})
    Tutrole.where(lesson_id: removelessons.map{|o| o.id}).delete_all
    # Remove all the roles (students allocated) in these lessons
    #removeroles    = Role.select(:id).where(lesson_id: removelessons.map{|o| o.id})
    Role.where(lesson_id: removelessons.map{|o| o.id}).delete_all
    # Now remove the lessons
    Lesson.where(slot_id: removeslots.map{|o| o.id}).delete_all
    # And remove the slots.
    Slot.where("timeslot < :end_date", {end_date: @startdatetokeep}).delete_all

    #Remove all change records created before this date.
    removechanges = Change.select(:id).where("created_at < :end_date", {end_date: @startdatetokeep})  
    logger.debug "Number of change records: " + Change.count.to_s
    logger.debug "Remove change records   : " + removechanges.count.to_s
    Change.select(:id).where("created_at < :end_date", {end_date: @startdatetokeep}).delete_all  
    logger.debug "Change records left     : " + Change.count.to_s


    # Remove tutors not referred to in the calendar and 
    # who have a status of inactive
    #byebug
    linkedtutors = Tutrole.select(:tutor_id).distinct
    #logger.debug "linkedtutors: " + linkedtutors.count.to_s
    linkedstudents = Role.select(:student_id).distinct
    #logger.debug "linkedstudents: " + linkedstudents.count.to_s
    #removetutors = Tutor.where(status: 'inactive').where.not(id: linkedtutors.map{|o| o.tutor_id})
    #logger.debug "removetutors: " + removetutors.count.to_s
    Tutor.where(status: 'inactive').where.not(id: linkedtutors.map{|o| o.tutor_id}).delete_all
    #removestudents = Student.where(status: 'inactive').where.not(id: linkedstudents.map{|o| o.student_id})
    #logger.debug "removestudents: " + removestudents.count.to_s
    Student.where(status: 'inactive').where.not(id: linkedstudents.map{|o| o.student_id}).delete_all
    
  end


#---------------------------------------------------------------------------
#
#   Delete Scheduler Days Edit paramenters - select days you want to delete
#
#---------------------------------------------------------------------------
  # GET /admins/deletedaysedit
  def deletedaysedit
  end

#---------------------------------------------------------------------------
#
#   Delete Scheduler Days - do the deletes
#
#---------------------------------------------------------------------------
  # GET /admins/deletedays
  def deletedays
    #logger.debug "entering deletedays"
    #logger.debug "deletedays_params: " + deletedays_params.inspect
    #sf = 5    # signigicant figures
    mystartdeletedate = deletedays_params["from"].to_date
    myenddeletedate = deletedays_params["from"].to_date + deletedays_params["num_days"].to_i
    @options = Hash.new
    @options[:startdate] = mystartdeletedate
    @options[:enddate]   = myenddeletedate
    @cal = calendar_read_display1f(@options)
    if @cal.empty?
      # these days are empty - show error and return
      flash[:notice] = "These days are empty - nothing to delete!!!"
      redirect_to deletedaysedit_path(deletedays_params)
    end
    # get to here, we are set up to do deletes
    # @cal contains the info to be deleted.
    @results = Array.new
#      Each site has an array
#      @cal{sitename}[0][] -> [0] = {value = site name}
#                             [1] = {value = date}
#      @cal{sitename}[1][] -> [0] = {value = session_time}  e.g. "03-3- PM"
#                             [1] = {slotid = nnnn
#                                    id_dom = "CAL201804041530"
#                                    values[] -> [0] = object #<Lesson>
#                                                [1] = object #<Lesson>
#                                                 ....
    @cal.each do |site, sitevalue| 
      # Now work through the slots for this site and day
      siteName = siteDate = ""    # control scope
      sitevalue.each_with_index do |bankslots, bankslotindex|
        if bankslotindex == 0 
          siteName = bankslots[0]['value']
          siteDate = siteDateBankFrom = bankslots[1]['value']
          n = siteDate.match(/(\d+.*)/)
          siteDate = n[1]
          if bankslots[2] == nil
            @results.push "processing #{siteName} #{siteDateBankFrom}"
          else
            siteDateBankTo = bankslots[2]['value']
            @results.push "processing #{siteName} #{siteDateBankFrom} to #{siteDateBankTo}"
          end
        else
          bankslots.each_with_index do |slot, slotindex|
            if slotindex == 0
              next        # simply holds the slot time - will get from found slot
            end
            thisslotid = slot['slotid']
            # if not a valid slot, go to next iteration.
            if thisslotid == nil
              next
            end
            @results.push "Slotid: #{thisslotid}"
            thisslot = Slot.find(thisslotid)
            @results.push "Check slot " + thisslot.inspect 
            # Now to look at each lession in each slot
            if slot['values'].respond_to?(:each) then
              slot['values'].each do |lesson|
                logger.debug "lesson: " + lesson.inspect
                @results.push "Check lesson " + lesson.inspect 
                # Now find all the tutors in this lesson
                if lesson.tutors.respond_to?(:each) then
                  lesson.tutors.sort_by {|obj| obj.pname }.each do |tutor|
                    tutroles = tutor.tutroles.where(lesson_id: lesson.id)
                    tutroles.each do |tutrole|
                      if tutrole.destroy
                        @results.push "Removed tutrole #{tutor.pname} " + 
                                      tutrole.inspect 
                      else
                        @results.push "FAILED removing tutrole #{tutor.pname} " +
                                      tutrole.inspect + 
                                      "ERROR: " + tutrole.errors.messages.inspect
                      end
                    end
                  end
                end
  
                # Now find all the students in this lesson
                if lesson.students.respond_to?(:each) then
                  lesson.students.sort_by {|obj| obj.pname }.each do |student|
                    roles = student.roles.where(lesson_id: lesson.id)
                    roles.each do |role|
                      if role.destroy
                        @results.push "Removed role #{student.pname} " + role.inspect
                      else
                        @results.push "FAILED removing role #{student.pname} " +
                                      role.inspect + 
                                      "ERROR: " + role.errors.messages.inspect
                      end
                    end
                  end
                end
                # Now remove the lesson the tutors and students were in
                mylesson = Lesson.find(lesson.id)
                if mylesson.destroy
                  @results.push "Removed lesson " + 
                                    mylesson.inspect 
                else
                  @results.push "FAILED removing lesson " + mylesson.inspect + 
                                "ERROR: " + mylesson.errors.messages.inspect
                end
              end    # looping lessons
            end
            # Now remove the slot the lessons were in.
            if thisslot.destroy
              @results.push "Removed slot " + thisslot.inspect 
            else
              @results.push "FAILED removing slot " + thisslot.inspect + 
                                "ERROR: " + thisslot.errors.messages.inspect
            end
          end
        end
      end
    end
  end
  
#---------------------------------------------------------------------------
#
#   Copy Scheduler Days Edit paramenters - select days you want to copy
#
#---------------------------------------------------------------------------
  # GET /admins/copydaysedit
  def copydaysedit
  end

#---------------------------------------------------------------------------
#
#   Copy Scheduler Days 
#   - select days you want to copy in the copydaysedit menu
#   - copies ALL content for the selected days.
#
#   An alternate copy is available for copying term data (selectable copy).
#
#---------------------------------------------------------------------------
  # GET /admins/copydays
  def copydays
    logger.debug "entering copydays"
    #logger.debug "copydays_params: " + copydays_params.inspect
    #sf = 5    # signigicant figures
    mystartcopyfromdate = copydays_params["from"].to_date
    myendcopyfromdate = copydays_params["from"].to_date + copydays_params["num_days"].to_i
    mystartcopytodate = copydays_params["to"].to_date
    myendcopytodate = copydays_params["to"].to_date + copydays_params["num_days"].to_i
    #@cal = calendar_read_display2(sf, mystartcopytodate, myendcopytodate)
    #@cal = calendar_read_display1f(sf, mystartcopytodate, myendcopytodate, {})
    @options = Hash.new
    @options[:startdate] = mystartcopytodate
    @options[:enddate]   = myendcopytodate
    #@cal = calendar_read_display1f(sf, @options)
    @cal = calendar_read_display1f(@options)
    unless @cal.empty?
      # destination is not empty - show error and return
      flash[:notice] = "Destination days are not empty - will not copy!!!"
      redirect_to copydaysedit_path(copydays_params)
    end
    #@cal = calendar_read_display2(sf, mystartcopyfromdate, myendcopyfromdate)
    #@cal = calendar_read_display1f(sf, mystartcopyfromdate, myendcopyfromdate, {})
    @options[:startdate] = mystartcopyfromdate
    @options[:enddate]   = myendcopyfromdate
    #@cal = calendar_read_display1f(sf, @options)
    @cal = calendar_read_display1f(@options)
    if @cal.empty?
      # source is empty - show error and return
      flash[:notice] = "Source days are empty - nothing to copy!!!"
      redirect_to copydaysedit_path(copydays_params)
    end
    # get to here, we are set up to do a copy
    # @cal contains the info to be copied.
    # First get the number of dayes to advance by ( + or - is valid)
    adddays = mystartcopytodate - mystartcopyfromdate
    logger.debug "adddays: " + adddays.inspect
    @results = Array.new
#      Each site has an array
#      @cal{sitename}[0][] -> [0] = {value = site name}
#                             [1] = {value = date}
#      @cal{sitename}[1][] -> [0] = {value = session_time}  e.g. "03-3- PM"
#                             [1] = {slotid = nnnn
#                                    id_dom = "CAL201804041530"
#                                    values[] -> [0] = object #<Lesson>
#                                                [1] = object #<Lesson>
#                                                 ....
#                                   }
    @cal.each do |site, sitevalue| 
      # Now work through the slots for this site and day
      siteName = siteDate = ""    # control scope
      sitevalue.each_with_index do |bankslots, bankslotindex|
        if bankslotindex == 0 
          siteName = bankslots[0]['value']
          siteDate = siteDateBankFrom = bankslots[1]['value']
          n = siteDate.match(/(\d+.*)/)
          siteDate = n[1]
          if bankslots[2] == nil
            @results.push "processing #{siteName} #{siteDateBankFrom}"
          else
            siteDateBankTo = bankslots[2]['value']
            @results.push "processing #{siteName} #{siteDateBankFrom} to #{siteDateBankTo}"
          end
        else
          bankslots.each_with_index do |slot, slotindex|
            if slotindex == 0
              next        # simply holds the slot time - will get from found slot
            end
            thisslotid = slot['slotid']
            # if not a valid slot, go to next iteration.
            if thisslotid == nil
              next
            end
            @results.push "Slotid: #{thisslotid}"
            thisslot = Slot.find(thisslotid)
            mytimeslotTo = thisslot.timeslot + adddays.to_i * 86400
            myslotTo = Slot.new(timeslot: mytimeslotTo, location: thisslot.location)
            if myslotTo.save
              @results.push "created slot " + myslotTo.inspect
            else
              @results.push "FAILED creating slot " + myslotTo.inspect + 
                            "ERROR: " + myslotTo.errors.messages.inspect
            end
            # Now to look at each session in each slot
            if slot['values'].respond_to?(:each) then
              slot['values'].each do |lesson|
                logger.debug "lesson: " + lesson.inspect
                mylesson = Lesson.new(slot_id: myslotTo.id, status: lesson.status)
                if mylesson.save
                  @results.push "created lesson " + mylesson.inspect
                else
                  @results.push "FAILED creating lesson " + mylesson.inspect + 
                            "ERROR: " + mylesson.errors.messages.inspect
                end
                
                # Now find all the tutors in this lesson
                if lesson.tutors.respond_to?(:each) then
                  lesson.tutors.sort_by {|obj| obj.pname }.each do |tutor|
                    thistutrole = tutor.tutroles.where(lesson_id: lesson.id).first
                    mytutrole = Tutrole.new(lesson_id: mylesson.id,
                                            tutor_id: tutor.id, 
                                            status: thistutrole.status,
                                            kind: thistutrole.kind)
                    if mytutrole.save
                      @results.push "created tutrole #{tutor.pname} " + mytutrole.inspect 
                    else
                      @results.push "FAILED creating tutrole " + mytutrole.inspect + 
                                    "ERROR: " + mytutrole.errors.messages.inspect
                    end
                  end
                end
  
                # Now find all the students in this lesson
                if lesson.students.respond_to?(:each) then
                  lesson.students.sort_by {|obj| obj.pname }.each do |student|
                    thisrole = student.roles.where(lesson_id: lesson.id).first
                    myrole = Role.new(lesson_id: mylesson.id,
                                            student_id: student.id, 
                                            status: thisrole.status,
                                            kind: thisrole.kind)
                    if myrole.save
                      @results.push "created role #{student.pname} " + myrole.inspect
                    else
                      @results.push "FAILED creating role " + myrole.inspect + 
                                    "ERROR: " + myrole.errors.messages.inspect
                    end
                  end
                end
              end
            end
          end
        end        
      end
    end
  end

#---------------------------------------------------------------------------
#
#   Copy Term Days 
#   - select days you want to copy in the copydaysedit menu
#   - copies content for the selected days based on:
#       . session type 
#       . student/session type
#
#   An alternate copy is available for copying all data.
#
#---------------------------------------------------------------------------
  # GET /admins/copytermdays
  def copytermdays
    logger.debug "entering copytermdays"
    #logger.debug "copytermdays_params: " + copytermdays_params.inspect
    #sf = 5    # signigicant figures
    mystartcopyfromdate = copytermdays_params["from"].to_date
    myendcopyfromdate = copytermdays_params["from"].to_date + copytermdays_params["num_days"].to_i
    mystartcopytodate = copytermdays_params["to"].to_date
    myendcopytodate = copytermdays_params["to"].to_date + copytermdays_params["num_days"].to_i
    #@cal = calendar_read_display2(sf, mystartcopytodate, myendcopytodate)
    #@cal = calendar_read_display1f(sf, mystartcopytodate, myendcopytodate, {})
    @options = Hash.new
    @options[:startdate] = mystartcopytodate
    @options[:enddate]   = myendcopytodate
    #@cal = calendar_read_display1f(sf, @options)
    @cal = calendar_read_display1f(@options)
    unless @cal.empty?
      # destination is not empty - show error and return
      flash[:notice] = "Destination days are not empty - will not copy!!!"
      redirect_to copytermdaysedit_path(copytermdays_params)
    end
    @options[:startdate] = mystartcopyfromdate
    @options[:enddate]   = myendcopyfromdate
    @cal = calendar_read_display1f(@options)
    if @cal.empty?
      # source is empty - show error and return
      flash[:notice] = "Source days are empty - nothing to copy!!!"
      redirect_to copytermdaysedit_path(copytermdays_params)
    end
    # get to here, we are set up to do a copy
    # @cal contains the info to be copied.
    # First get the number of dayes to advance by ( + or - is valid)
    adddays = mystartcopytodate - mystartcopyfromdate
    logger.debug "adddays: " + adddays.inspect
    @results = Array.new
#      Each site has an array
#      @cal{sitename}[0][] -> [0] = {value = site name}
#                             [1] = {value = date}
#      @cal{sitename}[1][] -> [0] = {value = session_time}  e.g. "03-3- PM"
#                             [1] = {slotid = nnnn
#                                    id_dom = "CAL201804041530"
#                                    values[] -> [0] = object #<Lesson>
#                                                [1] = object #<Lesson>
#                                                 ....
#                                   }
    @cal.each do |site, sitevalue| 
      # Now work through the slots for this site and day
      siteName = siteDate = ""    # control scope
      sitevalue.each_with_index do |bankslots, bankslotindex|
        if bankslotindex == 0 
          siteName = bankslots[0]['value']
          siteDate = siteDateBankFrom = bankslots[1]['value']
          n = siteDate.match(/(\d+.*)/)
          siteDate = n[1]
          if bankslots[2] == nil
            @results.push "processing #{siteName} #{siteDateBankFrom}"
          else
            siteDateBankTo = bankslots[2]['value']
            @results.push "processing #{siteName} #{siteDateBankFrom} to #{siteDateBankTo}"
          end
        else
          bankslots.each_with_index do |slot, slotindex|
            if slotindex == 0
              next        # simply holds the slot time - will get from found slot
            end
            thisslotid = slot['slotid']
            # if not a valid slot, go to next iteration.
            if thisslotid == nil
              next
            end
            @results.push "Slotid: #{thisslotid}"
            thisslot = Slot.find(thisslotid)
            mytimeslotTo = thisslot.timeslot + adddays.to_i * 86400
            myslotTo = Slot.new(timeslot: mytimeslotTo, location: thisslot.location)
            if myslotTo.save
              @results.push "created slot " + myslotTo.inspect
            else
              @results.push "FAILED creating slot " + myslotTo.inspect + 
                            "ERROR: " + myslotTo.errors.messages.inspect
            end
            #-------------------------------------------------------------------
            # For copying term info,
            # 1. Slots are always copied.
            # 2. Determine what tutors and students need to be copied.
            # Logic is:
            # Lesson status | copy lesson  | copy tutors  | copy students
            # routine       |    yes       |    yes if    |      yes if
            # (=standard)   |              | - rostered   |  - rostered
            #               |              | - away       |  - away
            #               |              | - absent     |  - absent
            #               |              |              |  - bye
            #               |              |    no if     |      no if
            #               |              | - deal       |  - deal
            #               |              | - kind=called| 
            # flexible      |    yes       |    yes if    |     no always
            #               |              | - rostered   | 
            #               |              | - away       | 
            #               |              | - absent     |  
            #               |              |    no if     |      
            #               |              | - deal       | 
            #               |              | - kind=called| 
            # on_BFL        |    yes       |   yes if     |     no always
            #               |              | - rostered   | 
            #               |              | - away       |  
            #               |              | - absent     | 
            #               |              |    no if     | 
            #               |              | - deal       | 
            #               |              | - kind=called| 
            # onSetup       |    yes       |   yes if     |     no always
            #               |              | - rostered   | 
            #               |              | - away       |  
            #               |              | - absent     | 
            #               |              |    no if     | 
            #               |              | - deal       | 
            #               |              | - kind=called| 
            # onCall        |    yes       |   yes if     |     no always
            #               |              | - rostered   | 
            #               |              | - away       |  
            # free          |    yes       |  no always   |     no always
            # global        |    no        |              |     
            # allocate      |    no        |              |     
            # park          |    no        |              |
            #-------------------------------------------------------------------
            # Now to look at each lesson in each slot
            if slot['values'].respond_to?(:each) then
              slot['values'].each do |lesson|
                logger.debug "lesson: " + lesson.inspect
                # is this a valid lesson to copy
                next if ['global', 'allocate', 'park'].include?(lesson.status)               
                mylesson = Lesson.new(slot_id: myslotTo.id, status: lesson.status)
                if mylesson.save
                  @results.push "created lesson " + mylesson.inspect
                else
                  @results.push "FAILED creating lesson " + mylesson.inspect + 
                            "ERROR: " + mylesson.errors.messages.inspect
                end
                # for free lesson, do not copy any tutors or students
                next if lesson.status == 'free'
                # At this point, decision to copy tutors or students depends
                # on their kind and status.
                # Now find all the tutors in this lesson
                if lesson.tutors.respond_to?(:each) then
                  lesson.tutors.sort_by {|obj| obj.pname }.each do |tutor|
                    thistutrole = tutor.tutroles.where(lesson_id: lesson.id).first
                    # Check if this tutor-lesson should be copied
                    flagtutorcopy = false
                    flagtutorcopy = true if ['scheduled', 'confirmed', 'notified',
                        'attended', 'away', 'absent'].include?(thistutrole.status)
                    flagtutorcopy = false if thistutrole.kind == 'called'
                    next unless flagtutorcopy
                    mytutrole = Tutrole.new(lesson_id: mylesson.id,
                                            tutor_id: tutor.id, 
                                            status: 'scheduled',
                                            kind: thistutrole.kind)
                    if mytutrole.save
                      @results.push "created tutrole #{tutor.pname} " + mytutrole.inspect 
                    else
                      @results.push "FAILED creating tutrole " + mytutrole.inspect + 
                                    "ERROR: " + mytutrole.errors.messages.inspect
                    end
                  end
                end
  
                # Now find all the students in this lesson
                if lesson.students.respond_to?(:each) then
                  lesson.students.sort_by {|obj| obj.pname }.each do |student|
                    thisrole = student.roles.where(lesson_id: lesson.id).first
                    # check if this student should be copied.
                    # for some lesson types, students are never copied
                    next if ['flexible', 'on_BFL', 'onSetup', 'onCall',
                             'free'].include?(lesson.status)
                    # others depend on their student-lesson status/
                    flagstudentcopy = false
                    flagstudentcopy = true if ['scheduled', 'attended', 'away',
                                      'absent', 'bye'].include?(thisrole.status)
                    next unless flagstudentcopy
                    # if so, copy  this student-lesson
                    myrole = Role.new(lesson_id: mylesson.id,
                                            student_id: student.id, 
                                            status: 'scheduled',
                                            kind: thisrole.kind)
                    if myrole.save
                      @results.push "created role #{student.pname} " + myrole.inspect
                    else
                      @results.push "FAILED creating role " + myrole.inspect + 
                                    "ERROR: " + myrole.errors.messages.inspect
                    end
                  end
                end
              end
            end
          end
        end        
      end
    end
  end

#---------------------------------------------------------------------------
#
#   Copy Term Weeks 
#   - select week (start & end day) you want to copy in the copydaysedit menu
#   - copies content for the selected days based on:
#       . session type 
#       . student/session type
#
#   This will copy the week into a number of consective weeks +
#   plus add one week into the following term at the provided date
#
#---------------------------------------------------------------------------
#-------------------------------------------------------------------
# For copying term info,
# 1. Slots are always copied.
# 2. Determine what tutors and students need to be copied.
# Logic is:
# Lesson status | copy lesson  | copy tutors  | copy students
# routine       |    yes       |    yes if    |      yes if
# (=standard)   |              | - rostered   |  - rostered
#               |              | - away       |  - away
#               |              | - absent     |  - absent
#               |              |              |  - bye
#               |              |    no if     |      no if
#               |              | - deal       |  - deal
#               |              | - kind=called| 
# flexible      |    yes       |    yes if    |     no always
#               |              | - rostered   | 
#               |              | - away       | 
#               |              | - absent     |  
#               |              |    no if     |      
#               |              | - deal       | 
#               |              | - kind=called| 
# on_BFL        |    yes       |   yes if     |     no always
#               |              | - rostered   | 
#               |              | - away       |  
#               |              | - absent     | 
#               |              |    no if     | 
#               |              | - deal       | 
#               |              | - kind=called| 
# onSetup       |    yes       |   yes if     |     no always
#               |              | - rostered   | 
#               |              | - away       |  
#               |              | - absent     | 
#               |              |    no if     | 
#               |              | - deal       | 
#               |              | - kind=called| 
# onCall        |    yes       |   yes if     |     no always
#               |              | - rostered   | 
#               |              | - away       |  
# free          |    yes       |  no always   |     no always
# global        |    no        |              |     
# allocate      |    no        |              |     
# park          |    no        |              |
#-------------------------------------------------------------------
#      Each site has an array
#      @cal{sitename}[0][] -> [0] = {value = site name}
#                             [1] = {value = date}
#      @cal{sitename}[1][] -> [0] = {value = session_time}  e.g. "03-3- PM"
#                             [1] = {slotid = nnnn
#                                    id_dom = "CAL201804041530"
#                                    values[] -> [0] = object #<Lesson>
#                                                [1] = object #<Lesson>
#                                                 ....
#                                   }
#-------------------------------------------------------------------
  # GET /admins/copytermweeks
  def copytermweeks
    logger.debug "entering copytermweeks"
    #logger.debug "copytermweeks_params: " + copytermweeks_params.inspect
    #sf = 5    # signigicant figures
    mystartcopyfromdate = copytermweeks_params["from"].to_date
    myendcopyfromdate   = copytermweeks_params["from"].to_date + copytermweeks_params["num_days"].to_i
    mycopynumweeks      = copytermweeks_params["num_weeks"].to_i
    mystartcopytodate   = copytermweeks_params["to"].to_date
    myendcopytodate     = copytermweeks_params["to"].to_date +
                          copytermweeks_params["num_days"].to_i + (mycopynumweeks + 1) * 7
    myfirstweekdate     = copytermweeks_params["first_week"].to_date
    logger.debug "First week starts on " + myfirstweekdate.to_s
    @options = Hash.new
    @options[:startdate] = mystartcopytodate
    @options[:enddate]   = myendcopytodate
    @cal = calendar_read_display1f(@options)
    unless @cal.empty?
      # destination is not empty - show error and return
      flash[:notice] = "Destination days are not empty - will not copy!!!"
      redirect_to copytermweeksedit_path(copytermweeks_params)
      return
    end
    @options[:startdate] = mystartcopyfromdate
    @options[:enddate]   = myendcopyfromdate
    @cal = calendar_read_display1f(@options)
    if @cal.empty?
      # source is empty - show error and return
      flash[:notice] = "Source days are empty - nothing to copy!!!"
      redirect_to copytermweeksedit_path(copytermweeks_params)
    end
    #--------------------------------------------------------------------
    #---- check that all slots contains a global and allocate lesson ----
    flagAddedLesson = false         # track if one has been added.
    @cal.each do |site, sitevalue| 
      # Now work through the slots for this site and day
      #---- for each  row of slots (all days - each row being a lesson timeslot ----
      sitevalue.each_with_index do |bankslots, bankslotindex|
        if bankslotindex == 0               # column title 
        else
          #---- for each slot in the row - ( one days with one lesson timeslot) ----
          bankslots.each_with_index do |slot, slotindex|
            if slotindex == 0         # row title
              next        # simply holds the slot time - will get from found slot
            end
            thisslotid = slot['slotid']
            # if not a valid slot, go to next iteration.
            if thisslotid == nil
              next
            end
            #---- processing a valid slot (not just a cell in the table) ----
            #---- check this slot ----
            #---- check existing lessons ----
            # Now to look at each lesson in each slot
            # Also check that each slot has lesson types of 'global' and 'allocate'
            if slot['values'].respond_to?(:each) then
              flagMissingGlobal = flagMissingAllocate = true
              slot['values'].each do |lesson|
                flagMissingGlobal   = false if lesson.status == 'global'
                flagMissingAllocate = false if lesson.status == 'allocate'
              end
            end
            # Add lesson if missing global lesson or allocate lesson.
            #result = /^(([A-Z]+\d+l(\d+)))/.match(thisslotid)
            #if result 
            #  slot_dbId = result[3]
            #end
            if flagMissingGlobal
              @lesson_new = Lesson.new(slot_id: thisslotid, status: "global")
              @lesson_new.save
              flagAddedLesson = true
            end
            if flagMissingAllocate
              @lesson_new = Lesson.new(slot_id: thisslotid, status: "allocate")
              @lesson_new.save
              flagAddedLesson = true
            end
          end
        end        
      end
    end
    # if lessons added, then refetch! - should be a rare occurence!
    @cal = calendar_read_display1f(@options)
    #--------------------------------------------------------------------
    #---- copy this week into following weeks ----
    # get to here, we are set up to do a copy
    # @cal contains the info to be copied.
    # First get the number of dayes to advance by ( + or - is valid)
    adddays = mystartcopytodate - mystartcopyfromdate
    adddaysforweekplusone = myfirstweekdate - mystartcopyfromdate
    logger.debug "adddays: " + adddays.inspect
    @results = Array.new   # store detailed feedback to be displayed on user browser.
    #keep track of all copied entities - slots, lessons, roles, tutroles.
    # Used later - to break block links.
    @allCopiedSlotsIds    = Array.new
    @allCopiedLessonsIds  = Array.new
    @allCopiedRolesIds    = Array.new
    @allCopiedTutrolesIds = Array.new
    #---- for each site ----
    @cal.each do |site, sitevalue| 
      # Now work through the slots for this site and day
      siteName = siteDate = ""    # control scope
      #---- for each  row of slots (all days - each row being a lesson timeslot ----
      sitevalue.each_with_index do |bankslots, bankslotindex|
        if bankslotindex == 0               # column title 
          siteName = bankslots[0]['value']
          siteDate = siteDateBankFrom = bankslots[1]['value']
          n = siteDate.match(/(\d+.*)/)
          siteDate = n[1]
          if bankslots[2] == nil
            @results.push "processing #{siteName} #{siteDateBankFrom}"
          else
            siteDateBankTo = bankslots[2]['value']
            @results.push "processing #{siteName} #{siteDateBankFrom} to #{siteDateBankTo}"
          end
        else
          #---- for each slots in the row - ( one days with one lesson timeslot) ----
          bankslots.each_with_index do |slot, slotindex|
            if slotindex == 0         # row title
              next        # simply holds the slot time - will get from found slot
            end
            thisslotid = slot['slotid']
            # if not a valid slot, go to next iteration.
            if thisslotid == nil
              next
            end
            #---- processing a valid slot (not just a cell in the table) ----
            @allCopiedSlotsIds.push thisslotid    # track all copied slots 
            @results.push "Slotid: #{thisslotid}"
            #---- copy run this slot ----
            @blockSlots = Array.new
            @blockSlots[0] = Slot.find(thisslotid)
            @blockSlots[0].first = thisslotid
            # Now need to copy this to the following mycopynumweeks weeks.
            # we are forming a chain with first = first id in chain &
            # next = the following id in the chain.
            slotLocation = @blockSlots[0].location 
            nextTimeslotTo = @blockSlots[0].timeslot + (adddays.to_i - 7) * 86400
            ### adddaysforweekplusone
            (1..mycopynumweeks+1).each do |i|
              nextTimeslotTo += 7 * 86400
              # cater for the week plus one entries
              nextTimeslotTo = @blockSlots[0].timeslot + adddaysforweekplusone * 86400 if i == mycopynumweeks + 1 
              @blockSlots[i] = Slot.new(timeslot: nextTimeslotTo, 
                                        location: slotLocation,
                                        first: thisslotid )
            end
            (0..mycopynumweeks+1).reverse_each do |i|
              # the last entity in chain will have next = nil by default, do not populate.
              @blockSlots[i].next = @blockSlots[i+1].id unless i == mycopynumweeks+1  
              if @blockSlots[i].save
                # weekPlusOne (wpo) will have the wpo field set to self
                if i == mycopynumweeks+1  
                  @blockSlots[i].wpo = @blockSlots[i].id
                  @blockSlots[i].save
                end
                @results.push "created slot " + @blockSlots[i].inspect
              else
                @results.push "FAILED creating slot " + @blockSlots[i].inspect + 
                              "ERROR: " + @blockSlots[i].errors.messages.inspect
              end
            end
            #---- copy any existing lesson that have the desired status ----
            # Now to look at each lession in each slot
            # Also check that each slot has lesson types of 'global' and 'allocate'
            if slot['values'].respond_to?(:each) then
              slot['values'].each do |lesson|
                logger.debug "lesson: " + lesson.inspect
                # is this a valid lesson to copy
                ###next if ['global', 'allocate', 'park'].include?(lesson.status)
                next if ['park'].include?(lesson.status)
                thislessonid = lesson.id
                #---- copy run this lesson ----
                @allCopiedLessonsIds.push thislessonid    # track all copied slots 
                @blockLessons = Array.new
                @blockLessons[0] = lesson
                @blockLessons[0].first = thislessonid
                # Now need to copy this to the following mycopynumweeks weeks.
                # we are forming a chain with first = first id in chain &
                # next = the following id in the chain.
                ### adddaysforweekplusone
                (1..mycopynumweeks+1).each do |i|
                  parentSlotId = @blockSlots[i].id
                  # cater for the week plus one entries
                  @blockLessons[i] = Lesson.new(slot_id: parentSlotId, 
                                            status: lesson.status,
                                            first: thislessonid )
                end
                (0..mycopynumweeks+1).reverse_each do |i|
                  # the last entity in chain will have next = nil by default, do not populate.
                  @blockLessons[i].next = @blockLessons[i+1].id unless i == mycopynumweeks+1  
                  if @blockLessons[i].save
                    @results.push "created lesson " + @blockLessons[i].inspect
                  else
                    @results.push "FAILED creating lesson " + @blockLessons[i].inspect + 
                                  "ERROR: " + @blockLessons[i].errors.messages.inspect
                  end
                end
                #---- some lessons are copied but not their tutor/student content ----
                # for free lesson, do not copy any tutors or students
                next if lesson.status == 'free'
                # At this point, decision to copy tutors or students depends
                # on their kind and status.
                # Now find all the tutors in this lesson
                #---- copy any existing tutors that have the desired status & kind ----
                if lesson.tutors.respond_to?(:each) then
                  lesson.tutors.sort_by {|obj| obj.pname }.each do |tutor|
                    #thistutrole = tutor.tutroles.where(lesson_id: lesson.id).first
                    @blockTutroles = Array.new
                    @blockTutroles[0] = tutor.tutroles.where(lesson_id: lesson.id).first
                    # Check if this tutor-lesson should be copied
                    flagtutorcopy = false
                    flagtutorcopy = true if ['scheduled', 'confirmed', 'notified',
                        'attended', 'away', 'absent'].include?(@blockTutroles[0].status)
                    # do not copy certain kinds!
                    flagtutorcopy = false if ['called', 'training', 'relief'].include?(@blockTutroles[0].kind)
                    #flagtutorcopy = false if @blockTutroles[0].kind == 'called'
                    next unless flagtutorcopy
                    thistutroleid = @blockTutroles[0].id
                    @allCopiedTutrolesIds.push thistutroleid    # track all copied slots 
                    @blockTutroles[0].block = @blockTutroles[0].first = thistutroleid
                    # Now need to copy this to the following mycopynumweeks weeks.
                    # we are forming a chain with first = first id in chain &
                    # next = the following id in the chain.
                    (1..mycopynumweeks+1).each do |i|
                      parentLessonId = @blockLessons[i].id
                      # cater for the week plus one entries
                      @blockTutroles[i] = Tutrole.new(lesson_id: parentLessonId,
                                                      tutor_id: tutor.id, 
                                                      status: 'scheduled',
                                                      kind: @blockTutroles[0].kind,
                                                      first: thistutroleid,
                                                      block: thistutroleid)
                    end
                    (0..mycopynumweeks+1).reverse_each do |i|
                      # the last entity in chain will have next = nil by default, do not populate.
                      @blockTutroles[i].next = @blockTutroles[i+1].id unless i == mycopynumweeks+1  
                      if @blockTutroles[i].save
                        @results.push "created tutrole " + @blockTutroles[i].inspect
                      else
                        @results.push "FAILED creating tutrole " + @blockTutroles[i].inspect + 
                                      "ERROR: " + @blockTutroles[i].errors.messages.inspect
                      end
                      # the last entity in chain is the week + 1 entry. 
                      # block will be set to self. 
                      ### This strategy is now changed.
                      ### Week Plus One (WPO) is now identified in the slots
                      ### Block now picks up all the items in the chain as first
                      ### will change often as moves are done. Block is the only way
                      ### to pick up all historical entries in the chain.
                      ###if i == mycopynumweeks+1
                      ###  @blockTutroles[i].block = @blockTutroles[i].id   
                      ###  if @blockTutroles[i].save
                      ###    @results.push "updated tutrole :block " + @blockTutroles[i].inspect
                      ###  else
                      ###    @results.push "FAILED updating tutrole block " + @blockTutroles[i].inspect + 
                      ###                  "ERROR: " + @blockTutroles[i].errors.messages.inspect
                      ###  end
                      ###end
                    end
                  end
                end
                #---- copy any existing students that have the desired status & kind ----
                # Now find all the students in this lesson
                if lesson.students.respond_to?(:each) then
                  lesson.students.sort_by {|obj| obj.pname }.each do |student|
                    @blockRoles = Array.new
                    @blockRoles[0] = student.roles.where(lesson_id: lesson.id).first
                    # check if this student should be copied.
                    # for some lesson types, students are never copied
                    next if ['flexible', 'on_BFL', 'onSetup', 'onCall',
                             'free'].include?(lesson.status)
                    # others depend on their student-lesson status/
                    flagstudentcopy = false
                    # do not copy certain kinds!
                    flagstudentcopy = true if ['scheduled', 'attended', 'away',
                                      'absent', 'bye'].include?(@blockRoles[0].status)
                    flagstudentcopy = false if ['catchup', 'bonus', 'free'].include?(@blockRoles[0].kind)
                    next unless flagstudentcopy
                    # if so, copy  this student-lesson
                    thisroleid = @blockRoles[0].id
                    @allCopiedRolesIds.push thisroleid    # track all copied slots 
                    @blockRoles[0].block = @blockRoles[0].first = thisroleid
                    # Now need to copy this to the following mycopynumweeks weeks.
                    # we are forming a chain with first = first id in chain &
                    # next = the following id in the chain.
                    (1..mycopynumweeks+1).each do |i|
                      parentLessonId = @blockLessons[i].id
                      # cater for the week plus one entries
                      @blockRoles[i] = Role.new(lesson_id: parentLessonId,
                                                      student_id: student.id, 
                                                      status: 'scheduled',
                                                      kind: @blockRoles[0].kind,
                                                      first: thisroleid,
                                                      block: thisroleid)
                      
                      #byebug
                      if @blockRoles[0].student.status == 'fortnightly'
                        if @blockRoles[0].status == 'bye'
                          @blockRoles[i].status = i.even? ? 'bye' : 'scheduled' 
                        else
                          @blockRoles[i].status = i.odd? ? 'bye' : 'scheduled' 
                        end
                      end
                      logger.debug "@blockRoles ( " + i.to_s + "): " + @blockRoles[i].inspect
                    end
                    (0..mycopynumweeks+1).reverse_each do |i|
                      # the last entity in chain will have next = nil by default, do not populate.
                      @blockRoles[i].next = @blockRoles[i+1].id unless i == mycopynumweeks+1  
                      if @blockRoles[i].save
                        @results.push "created role " + @blockRoles[i].inspect
                      else
                        @results.push "FAILED creating role " + @blockRoles[i].inspect + 
                                      "ERROR: " + @blockRoles[i].errors.messages.inspect
                      end
                      # the last entity in chain is the week + 1 entry. 
                      # block will be set to self.
                      ### This strategy is now changed.
                      ### Week Plus One (WPO) is now identified in the slots
                      ### Block now picks up all the items in the chain as first
                      ### will change often as moves are done. Block is the only way
                      ### to pick up all historical entries in the chain.
                      ###if i == mycopynumweeks+1
                      ###  @blockRoles[i].block = @blockRoles[i].id if i == mycopynumweeks+1  
                      ###  if @blockRoles[i].save
                      ###    @results.push "updated role :block " + @blockTutroles[i].inspect
                      ###  else
                      ###    @results.push "FAILED updating role block " + @blockTutroles[i].inspect + 
                      ###                  "ERROR: " + @blockRoles[i].errors.messages.inspect
                      ###  end
                      ###end
                    end
                  end
                end
              end
            end
          end
        end        
      end
    end

    # Now need to break the chains 
    # Remember that week + 1 is in the old chain.
    # Need to find previous link in the chain and set entity.next to nil.
    #@allCopiedSlotsIds    = Array.new
    #@allCopiedLessonsIds  = Array.new
    #@allCopiedRolesIds    = Array.new
    #@allCopiedTutrolesIds = Array.new
=begin
    Slot.where(next: @allCopiedSlotsIds).update_all(next: nil)
    Lesson.where(next: @allCopiedLessonsIds).update_all(next: nil)
    Role.where(next: @allCopiedRolesIds).update_all(next: nil)
    Tutrole.where(next: @allCopiedTutrolesIds).update_all(next: nil)
=end
  end

#---------------------------------------------------------------------------
#
#   Load Tutors
#
#---------------------------------------------------------------------------
  # GET /admins/loadtutors
  def loadtutors
    #service = googleauthorisation(request)
    returned_authorisation = googleauthorisation(request)
    if returned_authorisation["authorizationurl"]
      redirect_to returned_authorisation["authorizationurl"] and return
    end
    service = returned_authorisation["service"]
    spreadsheet_id = current_user[:ssurl].match(/spreadsheets\/d\/(.*?)\//)[1]
    #spreadsheet_id = '1CbtBqeHyYb9jRmROCgItS2eEaYSwzOMpQZdUWLMvjng'
    logger.debug 'about to read spreadsheet - service ' + service.inspect
    # Need some new code to cater for variation in the spreadsheet columns.
    # Will build an array with 'column names' = 'column numbers'
    # This can then be used to identify columns by name rather than numbers.
    #
    #this function converts spreadsheet indices to column name
    # examples: e[0] => A; e[30] => AE 
    e=->n{a=?A;n.times{a.next!};a}  
    columnmap = Hash.new  # {'column name' => 'column number'}
    range = "TUTORS!A3:LU3"
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    headerrow = response.values[0]
    logger.debug "response: " + headerrow.inspect
    headerrow.each_with_index do |value, index| 
      columnmap[value] = index
    end
    logger.debug "columnmap: " + columnmap.inspect
    #readcolumns = Array.new

    #  pname:     t[1],
    #  subjects:  t[2],
    #  phone:     t[3],
    #  email:     t[4],
    #  sname:     t[5],
    #  comment:   t[6],
    
    # Derived fields
    #  status:        "active" unless prefixed with zz..
    #  firstaid:     "yes" if name has suffix +
    #  firstsesson:  "yes" if name has suffix *

    readcolumns = [   'NAME + INITIAL',
                      'SUBJECTS',
                      'MOBILE',
                      'EMAIL',
                      'SURNAME',
                      'NOTES'
                  ]
    colerrors = ""
    readcolumns.each_with_index do |k, index|
      unless columnmap[k] 
        colerrors += k + ':'
      end  
    end
    # ensure we can read all the required spreadsheet column
    # if not, terminate and provide a user message
    unless colerrors.length == 0   # anything put into error string
      colerrors = "Load Tutors - not all columns are findable: " + colerrors
      redirect_to load_path, notice: colerrors
      return
    end
    # have everything we need, load the tutors from the spreadsheet
    # placing info into @tutors.
    startrow = 4            # row where the loaded data starts    
    flagFirstPass = 1
    readcolumns.each_with_index do |k, index|
        columnid = e[columnmap[k]]
        range = "TUTORS!#{columnid}#{startrow}:#{columnid}"
        response = service.get_spreadsheet_values(spreadsheet_id, range)
        if flagFirstPass == 1
          @tutors = Array.new(response.values.length){Array.new(9)}
          for rowcount in 0..response.values.count-1 
      	    @tutors[rowcount][0] = rowcount + startrow
          end
          flagFirstPass = 0
        end
        #rowcount = 0
        #response.values.each do |r|
        #for rowcount in 0..response.values.count 
        response.values.each_with_index do |c, rowindex|
    	    @tutors[rowindex ][index + 1] = c[0]
    	          #bc = v.effective_format.background_color
    	          #logger.debug  "background color: red=" + bc.red.to_s +
    	          #              " green=" + bc.green.to_s +
    		        #              " blue=" + bc.blue.to_s
        end 
    end

    #logger.debug "tutors: " + @tutors.inspect
    # Now to update the database
    loopcount = 0
    @tutors.each do |t|                 # step through all tutors from the spreadsheet
      t[7] = ""
      pname = t[1]
      logger.debug "pname: " + pname.inspect
      if pname == ""  || pname == nil
        t[7] = t[7] + "invalid pname - do nothing"
        next
      end
      # determine status from name content - been marked by leading z...
      thisstatus = "active"
      if m = pname.match(/(^z+)(.+)$/)   # removing leading z..  (inactive entries)
        pname = m[2].strip
        thisstatus = "inactive"
        #t[1] = pname
      end
      # look for + (firstaid:) * (firstsession) at end of pname 
      # (first aid trained or first session trained)
      thisfirstaid = 'no'
      thisfirstlesson = 'no'
      if m = pname.match(/([+* ]+)$/)
        thisfirstaid    = (m[1].include?('+') ? 'yes' : 'no')
        thisfirstlesson = (m[1].include?('*') ? 'yes' : 'no')
        pname = pname.gsub($1, '') unless $1.strip.length == 0
      end
      pname = pname.strip
      
      db_tutor = Tutor.find_by pname: pname
      if(db_tutor)   # already in the database
        flagupdate = 0                  # detect if any fields change
        updatetext = ""
        if db_tutor.comment != t[6]
          db_tutor.comment   = t[6]
          flagupdate = 1
          updatetext = updatetext + " - comment"  
        end
        if db_tutor.sname != t[5]
          db_tutor.sname   = t[5]
          flagupdate = 1
          updatetext = updatetext + " - sname"  
        end
        if db_tutor.email != t[4]
          db_tutor.email   = t[4]
          flagupdate = 1
          updatetext = updatetext + " - email"  
        end
        if db_tutor.phone != t[3]
          db_tutor.phone   = t[3]
          flagupdate = 1
          updatetext = updatetext + " - phone"  
        end
        if db_tutor.subjects != t[2]
          db_tutor.subjects   = t[2]
          flagupdate = 1
          updatetext = updatetext + " - subjects"  
        end
        if db_tutor.status != thisstatus 
          db_tutor.status   = thisstatus
          flagupdate = 1
          updatetext = updatetext + " - status"  
        end
        if db_tutor.firstaid != thisfirstaid 
          db_tutor.firstaid   = thisfirstaid
          flagupdate = 1
          updatetext = updatetext + " - firstaid"  
        end
        if db_tutor.firstlesson != thisfirstlesson
          db_tutor.firstlesson   = thisfirstlesson
          flagupdate = 1
          updatetext = updatetext + " - firstlesson"  
        end
        logger.debug "flagupdate: " + flagupdate.inspect + " db_tutor: " + db_tutor.inspect
        if flagupdate == 1                   # something changed - need to save
          if db_tutor.save
            logger.debug "db_tutor saved changes successfully"
            t[7] = t[7] + "updated" + updatetext  
          else
            logger.debug "db_tutor saving failed - " + @db_tutor.errors
            t[7] = t[7] + "failed to create"
          end
        else
            t[7] = t[7] + "no changes"
        end
      else
        # This tutor is not in the database - so need to add it.
        @db_tutor = Tutor.new(
                              pname:        pname,
                              subjects:     t[2],
                              phone:        t[3],
                              email:        t[4],
                              sname:        t[5],
                              comment:      t[6],
                              status:       thisstatus,
                              firstlesson:  thisfirstlesson,
                              firstaid:     thisfirstaid
                            )
        #if pname =~ /^zz/                   # the way they show inactive tutors
        #if t[1] =~ /^zz/                   # the way they show inactive tutors
        #  @db_tutor.status = "inactive"
        #end
        logger.debug "new - db_tutor: " + @db_tutor.inspect
        if @db_tutor.save
          logger.debug "db_tutor saved successfully"
          t[7] = t[7] + "created"  
        else
          logger.debug "db_tutor saving failed - " + @db_tutor.errors.inspect
          t[7] = t[7] + "failed to create"
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
    #service = googleauthorisation(request)
    returned_authorisation = googleauthorisation(request)
    if returned_authorisation["authorizationurl"]
      redirect_to returned_authorisation["authorizationurl"] and return
    end
    service = returned_authorisation["service"]
    #spreadsheet_id = '1CbtBqeHyYb9jRmROCgItS2eEaYSwzOMpQZdUWLMvjng'
    spreadsheet_id = current_user[:ssurl].match(/spreadsheets\/d\/(.*?)\//)[1]
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
    @students.each do |t|                 # step through all ss students
      pnameyear = t[1]
      logger.debug "pnameyear: " + pnameyear.inspect
      if pnameyear == ""  || pnameyear == nil
        t[10] = "invalid pnameyear - do nothing"
        next
      end
      #pnameyear[/^zz/] == nil ? status = "active" : status = "inactive"
      name_year_sex = getStudentNameYearSex(pnameyear)
      pname = name_year_sex[0]
      year = name_year_sex[1]
      sex = name_year_sex[2]
      status = name_year_sex[3]
      logger.debug "pname: " + pname + " : " + year + " : " +
                   sex.inspect + " : " + status
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
            updatetext = updatetext + " - sex (" + sex + ")"
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
            t[10] = "updated #{db_student.id} " + updatetext   
          else
            logger.debug "db_student saving failed - " + @db_student.errors
            t[10] = "failed to update"
          end
        else
            t[10] = "no changes"
        end
      else
        # This Student is not in the database - so need to add it.
        #
        # first get the 4 columns - 1. Student's Name + Year, 2. Focus,
        #                           3. study percentages, 4. email
        # now get the 5. perferences and 6. invcode
        # now get the 7. daycode, 8. term 4, 9. daycode
        @db_student = Student.new(
                              pname:        pname,
                              year:         year,
                              comment:      t[2],
                              study:        t[3],
                              email:        t[4],
                              preferences:  t[5],
                              invcode:      t[6],
                              daycode:      usedaycode,
                              status:       status,
                              sex:          sex
                            )
        logger.debug "new - db_student: " + @db_student.inspect
        if @db_student.save
          logger.debug "db_student saved successfully"
          t[10] = "created #{@db_student.id}"  
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
#   Load Students    ---    second version
#   Goggle spreadsheet changed dramatically in  Term 2 2017
#   Dropped out a number of fields -now only has three columns
#
#---------------------------------------------------------------------------
  # GET /admins/loadstudents2
  def loadstudents2
    #service = googleauthorisation(request)
    returned_authorisation = googleauthorisation(request)
    if returned_authorisation["authorizationurl"]
      redirect_to returned_authorisation["authorizationurl"] and return
    end
    service = returned_authorisation["service"]
    #spreadsheet_id = '1CbtBqeHyYb9jRmROCgItS2eEaYSwzOMpQZdUWLMvjng'
    spreadsheet_id = current_user[:ssurl].match(/spreadsheets\/d\/(.*?)\//)[1]
    logger.debug 'about to read spreadsheet'
    startrow = 3
    # first get the 3 columns - Student's Name + Year, Focus, study percentages
    #This is now all that we get
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
    #logger.debug "students: " + @students.inspect

    # Now to update the database
    loopcount = 0                         # limit output during testing
    @students.each do |t|                 # step through all ss students
      pnameyear = t[1]
      logger.debug "pnameyear: " + pnameyear.inspect
      if pnameyear == ""  || pnameyear == nil
        t[10] = "invalid pnameyear - do nothing"
        next
      end
      #pnameyear[/^zz/] == nil ? status = "active" : status = "inactive"
      name_year_sex = getStudentNameYearSex(pnameyear)
      pname = name_year_sex[0]
      year = name_year_sex[1]
      sex = name_year_sex[2]
      status = name_year_sex[3]
      logger.debug "pname: " + pname + " : " + year + " : " +
                   sex.inspect + " : " + status

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
        if db_student.status != status
          db_student.status = status
          flagupdate = 1
          updatetext = updatetext + " - status"  
        end
        logger.debug "flagupdate: " + flagupdate.inspect + " db_student: " + db_student.inspect
        if flagupdate == 1                   # something changed - need to save
          if db_student.save
            logger.debug "db_student saved changes successfully"
            t[10] = "updated #{db_student.id} " + updatetext   
          else
            logger.debug "db_student saving failed - " + @db_student.errors
            t[10] = "failed to update"
          end
        else
            t[10] = "no changes"
        end
      else
        # This Student is not in the database - so need to add it.
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
                              status: status
                            )
        logger.debug "new - db_student: " + @db_student.inspect
        if @db_student.save
          logger.debug "db_student saved successfully"
          t[10] = "created #{@db_student.id}"  
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
#   Load Students  Updates  ---    version to manage updates
#   This can be used on multiple occassions e.g. end of term, end of year
#   to do bulk updtes on students.
#   Also has a student merge capability.
#
#   A spreadsheet has been extracted from the Students index page
#   Michael and Megan has put in their desired updates.
#
#---------------------------------------------------------------------------
  # GET /admins/loadstudentsUpdate
  def loadstudentsUpdates
    @flagDbUpdateRun = false
    if params.has_key?('flagDbUpdate')
      if params['flagDbUpdate']  == 'run'
        @flagDbUpdateRun = true
      end
    end
    logger.debug "@flagDbUpdateRun: " + @flagDbUpdateRun.inspect
    #service = googleauthorisation(request)
    returned_authorisation = googleauthorisation(request)
    if returned_authorisation["authorizationurl"]
      redirect_to returned_authorisation["authorizationurl"] and return
    end
    service = returned_authorisation["service"]
    #spreadsheet_id = '1CbtBqeHyYb9jRmROCgItS2eEaYSwzOMpQZdUWLMvjng'
    spreadsheet_id = current_user[:ssurl].match(/spreadsheets\/d\/(.*?)\//)[1]
    sheet_name = current_user[:sstab]

    #---------------------- Read the spreadsheet --------------------
    logger.debug 'about to read spreadsheet'
    startrow = 1
    # first get the 3 columns - Student's Name + Year, Focus, study percentages
    #This is now all that we get
    range = sheet_name + "!A#{startrow}:U"
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    @students_raw = Array.new(response.values.length){Array.new(11)}
    #logger.debug "students: " + @students_raw.inspect
    basecolumncount = 1    #index for loading array - 0 contains spreadsheet row number
    rowcount = 0			   
    response.values.each do |r|
        #logger.debug "============ row #{rowcount} ================"
        #logger.debug "row: " + r.inspect
        colcount = 0
        @students_raw[rowcount][0] = rowcount + startrow
        r.each do |c|
          #logger.debug "============ cell value for column #{colcount} ================"
    	    #logger.debug "cell value: " + c.inspect
    	    @students_raw[rowcount][basecolumncount + colcount] = c
    		  colcount = colcount + 1
        end
        rowcount = rowcount + 1
    end
    #------------------------ Verify spreadsheet --------------------
    sheetheader = @students_raw[0]
    flagHeaderOK = true
    expectedheader = [1, "ID", "Given Name", "Family Name", "MERGE",
                      "Preferred Name", "UPDATE NAME", "Initials", "Sex", "UPDATE SEX",
                      "Comment", "UPDATE COMMENT", "Status", "UPDATE STATUS",
                      "Year", "UPDATE YEAR", "Study Percentages",
                      "UPDATE STUDY PERCENTAGES", "Email", "Phone",
                      "Inv Code", "Day Code"]
    
    headermessage = "Failed headers: "
    expectedheader.each_with_index do |o, i|
      if o != sheetheader[i]
        flagHeaderOK = false  
        headermessage += "#{i.to_s} => expected (#{o}) got (#{sheetheader[i]})     "
      end
    end
    if flagHeaderOK == false
      @students = Array.new
      @students[0] = Hash.new
      @students[0]['message'] = "spreadsheet error - header is not correct. " +
                               "You have selected the wrong spreadsheet or " +
                               "you have not set it up correctly."
      @students[1] = Hash.new
      @students[1]['message'] = "Correct headers are: " + expectedheader.inspect  
      @students[2] = Hash.new
      @students[2]['message'] = headermessage  
      return
    end
    #---------------------- Scan spreadsheet rows --------------------
    # now build a student hash of field names with field values
    @students = Array.new
    @studentsIndexById = Hash.new
    @students_raw.each_with_index do |s, j|
      #logger.debug "j:: " + j.inspect
      next if j == 0      # don't want the header
      #break if j > 4      # DEBUG ONLY
      i = j-1
      @students[i] = Hash.new
      @students[i]['row']        = s[0]
      if s[1] == ""       # no record in the db according to the spreadsheet
        # Will need to be created. Need main values as opposed to
        # update primary values (ignore spreadsheet 'update' values).
        @students[i]['pname']      = s[5]
        @students[i]['sex']        = s[8]
        @students[i]['comment']    = s[10]
        @students[i]['status']     = s[12]
        @students[i]['year']       = s[14]
        @students[i]['study']      = s[16]
      else  # we only want to update the database
        # this loads the update columns only and only if spreadsheet has content.
        @students[i]['id']         = s[1].to_i    # already know it is there
        @students[i]['oldpname']   = s[5]  if s[5]  && s[5].match(/\w+/)
        @students[i]['pname']      = s[6]  if s[6]  && s[6].match(/\w+/)  
        @students[i]['sex']        = s[9]  if s[9]  && s[9].match(/\w+/)  
        @students[i]['comment']    = s[11] if s[11] && s[11].match(/\w+/)  
        @students[i]['status']     = s[13] if s[13] && s[13].match(/\w+/)  
        @students[i]['year']       = s[15] if s[15] && s[15].match(/\w+/)
        @students[i]['study']      = s[17] if s[17] && s[17].match(/\w+/)
        # possibly a merge is required
        @students[i]['merge']      = s[4] if s[4].match(/\w+/)
      end
      # need to store message for display to the user.
      @students[i]['message']    = ""
      # Build index to be used for finding merged entries.
      @studentsIndexById[@students[i]['id']] = @students[i] if @students[i].has_key?('id')  
    end
    #logger.debug "students: " + @students.inspect
    # --------------- Check ids match pnames in dbvs spreadsheet -------------
    @allDbStudents = Student.all
    @allDbStudentsIndex = Hash.new
    @allDbStudents.each do |a|
      @allDbStudentsIndex[a.id] = a
    end
    idErrors = ""
    flagIdOK = true
    @students.each do |s|
      if s.has_key?('id') && s.has_key?('oldpname')
        unless @allDbStudentsIndex.has_key?(s['id'])  # this spreadsheet id not in the database
                flagIdOK = false
                idErrors += "Failed spreadsheet id not in database row #{s['row']} - #{s['id']}   "
                next
        end
        if s['oldpname'] != @allDbStudentsIndex[s['id']].pname    # Still possibly OK
          # May have already been updated with new pname on previous run
          if s.has_key?('pname') # potentially still OK - check updated pname
            if s['pname'] != @allDbStudentsIndex[s['id']].pname    # not OK unless merged 
                flagIdOK = false
                idErrors += "Failed id check row #{s['row']} db: #{@allDbStudentsIndex[s['id']].pname} - update pname #{s['pname']}"
            end
          elsif s.has_key?('merge') # potentially still OK - check if merged
            m = s['merge'].match(/^Merge.+?(\d+)$/)
            if m[1]   # ensure relevenant info
              merge_into_id = m[1].to_i
              unless @studentsIndexById.has_key?(merge_into_id)  # merge in entry not present
                flagIdOK = false
                idErrors += "Failed id check - merged_into row not present row #{s['row']} db: #{@allDbStudentsIndex[s['id']].pname} - #{s['oldpname']} -> merged "
              else
                mergedPname = "zzzMERGED " + @studentsIndexById[merge_into_id]['oldpname']
                if mergedPname != @allDbStudentsIndex[s['id']].pname    # not OK unless merged 
                  flagIdOK = false
                  idErrors += "Failed id check - not previously merged either row #{s['row']} db: #{@allDbStudentsIndex[s['id']].pname} - #{s['oldpname']} -> merged "
                end
              end
            else
              flagIdOK = false
              idErrors += "Failed id check row on merged pname not present #{s['row']} db: #{@allDbStudentsIndex[s['id']].pname} - #{s['oldpname']} "
            end
          else
            flagIdOK = false
            idErrors += "Failed id check row #{s['row']} db: #{@allDbStudentsIndex[s['id']].pname} - #{s['oldpname']} "
          end
        end
      end
    end
    if flagIdOK == false
      @students = Array.new
      @students[0] = Hash.new
      @students[0]['message'] = "spreadsheet error - ids do not match with pnames. " +
                               "You have selected the wrong spreadsheet or " +
                               "you have downloaded the wrong database."
      @students[1] = Hash.new
      @students[1]['message'] = idErrors  
      return
    end
    #
    # --------------- Now to work through database creation or update -------------
    #@students is a hash of all records from the spreadsheets
    @students.each_with_index do |s, i|
      #logger.debug "i: " + i.inspect + "   s[id]: " + s['id'].inspect
      #break if i > 1     # DEBUGGING ONLY
      # --------------- create record -------------
      if s['id'] == nil  || s['id'] == ""     # not yet created according to the spreadsheet
        logger.debug "creating a record"
        # better check to see if it has been created in a previous run
        if @students[i].has_key?('pname')  # pname field is mandatory
          @checkstudents = Student.where(pname: @students[i]['pname'])
          if @checkstudents.count == 0    # confirmed not in database as spreadsheet expects
            # simply do nothing and let update proceed.
          else
            @students[i]['message'] += "ERROR - record already in the database - row #{(i+1).to_s}"            
            next   # ERROR - record already in the database
          end
        else     # no pname value - ABORT this record!!!
          @students[i]['message'] += "no pname provided to allow db record creation - row #{(i+1).to_s}"            
          next   # ERROR in spreadsheet - cannot do any more with this
        end
        # All OK for record creation
        @student = Student.new(pname: @students[i]['pname'])
        @student.comment =  @students[i]['comment'] if @students[i].has_key?('comment')
        @student.status  =  @students[i]['status']  if @students[i].has_key?('status')
        @student.year    =  @students[i]['year']    if @students[i].has_key?('year')
        @student.study   =  @students[i]['study']   if @students[i].has_key?('study')
        @student.sex     =  @students[i]['sex']     if @students[i].has_key?('sex')
        #logger.debug "create student #{i.to_s}: " + @student.inspect
        if @flagDbUpdateRun
          logger.debug "update option selected - creating record"
          if @student.save
            @students[i]['message'] = "OK - Record created - row #{i.to_s}" + @students[i]['message']
            logger.debug "saved changes to " + @students[i]['message']
          else
            @students[i]['message'] += "ERROR - row #{i.to_s} - problem saving changes to db for " + @students[i]['message']
            logger.debug "problem saving changes to db for " + @students[i]['message']
          end
        else
          @students[i]['message'] = "OK - Record created - row #{i.to_s}" + @students[i]['message']
        end
      else        # spreadsheet says record should be in th database
        # --------------- update record -------------
        #logger.debug "updating the database"
        @student = Student.find(s['id'])   # get the record & update
        if @student    # record exists - now to update
          if s['pname'] && @student.pname != s['pname']
            @students[i]['message'] += "#update pname:" + @student.pname.inspect + "=>" + s['pname']
            @student.pname = s['pname']
          end
          if s['comment'] && @student.comment != s['comment']
            @students[i]['message'] += "#update comment:" + @student.comment.inspect + "=>" + s['comment']
            @student.comment = s['comment']
          end
          if s['status'] && @student.status != s['status']
            @students[i]['message'] += "#update status:" + @student.status.inspect + "=>" + s['status']
            @student.status = s['status']
          end
          if s['year'] && @student.year != s['year']
            @students[i]['message'] += "#update year:" + @student.year.inspect + "=>" + s['year']
            @student.year = s['year']
          end
          if s['study'] && @student.study != s['study']
            @students[i]['message'] += "#update study:" + @student.study.inspect + "=>" + s['study']
            @student.study = s['study']
          end
          if s['sex'] && @student.sex != s['sex']
            @students[i]['message'] += "#update sex:" + @student.sex.inspect + "=>" + s['sex']
            @student.sex = s['sex']
          end
          if @students[i]['message'].length > 0
            #logger.debug "saved changes row #{(i+1).to_s} " + @students[i]['message']
            logger.debug "update student #{i.to_s}: " + @student.inspect
            if @flagDbUpdateRun
              logger.debug "update option selected - updating record"
              if @student.save
                #logger.debug "OK - saved changes to " + @students[i]['message']
                @students[i]['message'] = "OK record updated  - row #{i.to_s} " + @students[i]['message']
              else
                logger.debug "ERROR - row #{i.to_s} - problem saving changes to db for " + @students[i]['message']
              end
            end
          else
            @students[i]['message'] = "INFO no updates required as record is already correct  - row #{i.to_s}" + @students[i]['message']
          end
        else   # record not in database - which was expected.
          @students[i]['message'] += "ERROR - no record found for this entry - row #{(i+1).to_s}"            
          # ABORT this record.
        end
      end
    end
    #--------------------------------------merge------------------------------
    # Merge requires:
    #  1. check both records exist
    #  2. find all roles for the student record being merged
    #  3. Update the student numbers in these to reference the merged_into student
    #  4. Set status of merged student to "inactive"
    #  5. Prepend comment to this student "MERGED into student id xxx pname yyy"
    #  6. Set pname to "zzzMERGED " + pname.
    #---------------------------------------------------------------------=--
    count_merges = 0
    @students.each_with_index do |s, i|
      #logger.debug "i: " + i.to_s  + "   =>   " + s.inspect
      if s.has_key?('merge')     # merge requested
        count_merges += 1          # count the number of merges encounted in the spreadsheet
        #break if count_merges > 1  # DEBUGGING ONLY
        next if s['id'] == 0       # Not a record in the database accordingto the spreadsheet. 
        merge_id = s['id']         # record to be merged
        #logger.debug "merge_id: " + merge_id.inspect + s['merge'].inspect
        m = s['merge'].match(/^Merge.+?(\d+)$/)
        if m[1]   # ensure relevenant info
          merge_into_id = m[1]
        else
          @students[i]['message'] += "  \nError - requesting merge but merge info invalid"
          return
        end
        # now check both records exist
        @student_merge = Student.find(merge_id)
        @students[i]['message'] += "Error - merge record not in db" unless @student_merge
        @student_merge_into = Student.find(merge_into_id)
        @students[i]['message'] += "Error - merge_into record not in db" unless @student_merge_into
        # find all the relevant roles
        @roles = Role.where(student_id: @student_merge)
        # Now check to see if the merge has already been done
        if @student_merge.pname.match(/^zzzMERGED/)
          @students[i]['message'] = "INFO - already merged." + @students[i]['message'] + "   "
          next
        end
        logger.debug "Number of roles found for " + @student_merge.pname + " :" + @roles.count.to_s
        # update the student_id in these roles to now reference merge_into
        @roles.each{|o| o.student_id = @student_merge_into.id}
        # Set merged student with status, comment and pname
        @student_merge.status = "inactive"
        @student_merge.comment = "MERGED into student (#{@student_merge_into.id.to_s})" +
                                      " #{@student_merge_into.pname} " +  
                                      @student_merge_into.comment 
        @student_merge.pname = "zzzMERGED " + @student_merge_into.pname
        # ensure each student stuff is done as a set.
        if @flagDbUpdateRun
          logger.debug "update option selected - merging record"
          begin
            Role.transaction do
              @roles.each do |myrole|
                myrole.save!
              end
              @student_merge.save!
            end
            rescue ActiveRecord::RecordInvalid => exception
              logger.debug "Transaction failed row #{i._to_s} rollback exception: " + exception.inspect
              @students[i]['message'] = "ERROR - Transaction failed!!!" + exception.inspect + @students[i]['message'] + "   "
              next
          end
        end
        @students[i]['message'] = "  OK Record Merged. " + @students[i]['message'] + "   "
      end
    end
  end

#---------------------------------------------------------------------------
#
#   Load Schedule
#
#---------------------------------------------------------------------------
  # GET /admins/loadschedule
  def loadschedule
    logger.debug "in loadschedule"
    # log levels are: :debug, :info, :warn, :error, :fatal, and :unknown, corresponding to the log level numbers from 0 up to 5
    #logger.fatal "1.log level" + Rails.logger.level.inspect
    #service = googleauthorisation(request)
    returned_authorisation = googleauthorisation(request)
    if returned_authorisation["authorizationurl"]
      redirect_to returned_authorisation["authorizationurl"] and return
    end
    service = returned_authorisation["service"]
    #spreadsheet_id = '1CbtBqeHyYb9jRmROCgItS2eEaYSwzOMpQZdUWLMvjng'
    #sheet_name = 'WEEK 1'
    spreadsheet_id = current_user[:ssurl].match(/spreadsheets\/d\/(.*?)\//)[1]
    sheet_name = current_user[:sstab]
    colsPerSite = 7
    # first get sites from the first row
    range = "#{sheet_name}!A3:AP3"
    holdRailsLoggerLevel = Rails.logger.level
    Rails.logger.level = 1 
    response = service.get_spreadsheet_values(spreadsheet_id, range)
    Rails.logger.level = holdRailsLoggerLevel 
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
    # @schedule array holds all the info required for updating 
    # the database and displaying the results
    @schedule = Array.new()
    #These arrays and hashes are used within the sites loop
    #They get cloned and cleared during iterations
    onCall = Array.new()
    onSetup = Array.new()
    requiredSlot = Hash.new()
    thisLesson = Hash.new()
    flagProcessingLessons = false  # need to detect date to start
    # @allColours is used in the view
    # It is used to show all colors used in the google schedule
    # Analysis tool.
    @allColours = Hash.new()
    # work through our sites, reading spreadsheet for each
    # and extract the slots, lessons, tutors and students
    # We also get the lesson notes.
    # At the beginning of each day, we get the on call and
    # setup info
    sites.each do |si, sv|  # site name, {col_start}
      mystartcol = e[sv["col_start"]]
      myendcol = e[sv["col_start"] + colsPerSite - 1]
      #myendcoldates = e[sv["col_start"] + 1] 
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
      
      Rails.logger.level = holdRailsLoggerLevel
      # Now scan each row read from the spreadsheet in turn
      logger.debug "processing data from spreadsheet by rows."
      response.sheets[0].data[0].row_data.map.with_index do |r, ri|
        # r = value[] - contains info for ss cell - content & colour,
        # ri = row index
        #
        # FOR ANALYSIS ONLY - not for loading database
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
          # also, keep location of first occurance
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
        if c0 == week     # e.g. T3W1 - first row of the day 
          storecolours.call(1)
          next
        end
        if c0 == "ON CALL"     # we are on "ON CALL" row
          storecolours.call(1)
          for i in 1..7 do     # keep everything on this row
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
          if colourToStatus(cf1)['colour'].downcase != 'white'
            flagProcessingLessons = false
            next
          else
            flagProcessingLessons = true
          end
          # we are now working with a valid slot
          unless requiredSlot.empty?
            @schedule.push(requiredSlot.clone)
            requiredSlot.clear
          end
          #now get the matching date from the responsedates array
          mydateserialnumber = responsedates.values[ri][0]
          
          begin
            mydate = Date.new(1899, 12, 30) + mydateserialnumber 
            c1 = getvalue(r.values[1])
            n = c1.match(/(\w+)\s+(\d+)\:*(\d{2})/im) # MONDAY 330 xxxxxxx
            # Note: add 12 to hours as these are afternoon sessions.
            # Check for ligimate dates
            myhour = n[2].to_i
            mymin  = n[3].to_i
            #dt1 = DateTime.new(mydate.year, mydate.month, mydate.day,
            #              1, 1)
            #dt2 = DateTime.new(2000, 1, 1,
            #                   myhour + 12, mymin)
            dt = DateTime.new(mydate.year, mydate.month, mydate.day,
                              myhour + 12, mymin)
          rescue 

            errorSite = si
            #errorRow = ri + 3
            myerror = "Load Schedule - data processing error: " +
                      " found in site: " + errorSite +
                      " c0: " + c0.inspect +
                      " c1: " + c1.inspect +
                      " mydateserialnumber: " + mydateserialnumber.inspect +
                      " error message: " + $!.inspect
            logger.debug myerror
            flash[:notice] = myerror
            render action: :load
            return
          end
          requiredSlot["timeslot"] = dt     # adjust from am to pm.
          requiredSlot["location"] = si
          logger.debug "working with " + si.inspect + ' ' + dt.inspect
          # Now that we have a slot created, check if this has been
          # the first one for the day. i.e. there are on call and setup events
          # If so, we make them into a lesson and add them  to the slot.
          # Delete them when done.
          if(!onCall.empty? || !onSetup.empty?)
            requiredSlot["onCall"]  = onCall.clone unless onCall.empty?
            requiredSlot["onSetup"] = onSetup.clone unless onSetup.empty?
            onCall.clear
            onSetup.clear
          end
          next
        end
        # any other rows are now standard lesson rows
        # If no date row yet detected or
        # this is not a valid slot (black background on date row)
        # we ignore
        next if flagProcessingLessons == false
        # Now do normal lession processing.
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
      # at end of last loop - need to keep if valid slot
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
      # These are initialise on a row by row basis
      r["slot_updates"] = ""
      r["onCallupdates"] = ""
      r["onSetupupdates"] = ""
      r["commentupdates"] = ""
      # Process the slot
      mylocation = r["location"]
      mytimeslot = r["timeslot"] 
      thisslot = Slot.where(location: mylocation, timeslot: mytimeslot).first
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
        logger.debug "mylesson - r onCall: " + mylesson.inspect
        mytutornamecontent = findTutorNameComment(mylesson, @tutors)
        # check if there was a tutor found.
        # If not, then we add any comments to the lesson comments.
        lessoncomment = ""
        if mytutornamecontent[0] == nil
          lessoncomment = mylesson[0]
        elsif mytutornamecontent[0]["name"] == "" && 
              mytutornamecontent[0]["comment"].strip != ""
          lessoncomment = mytutornamecontent[0]["comment"]
        end
        if lessoncomment != "" ||
           (
             mytutornamecontent[0] != nil &&
             mytutornamecontent[0]["name"] != ""
           )
          # something to put in lesson so ensure it exists - create if necessary
          thislesson = Lesson.where(slot_id: thisslot.id, status: "onCall").first
          unless thislesson
            thislesson = Lesson.new(slot_id: thisslot.id,
                                    status: "onCall",
                                    comments: lessoncomment)
            if thislesson.save
              r["onCallupdates"] += "|lesson created #{thislesson.id}|"
            else
              r["onCallupdates"] += "|lesson creation failed|"
            end
          end
        end
        # Now load in the tutors - if any
        mytutornamecontent.each do |te|
          logger.debug "mytutornameconent - te: " + te.inspect
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
              if thistutrole.comment == mytutorcomment &&
                 thistutrole.status  == "" &&
                 thistutrole.kind    == "onCall"
                r["onCallupdates"] += "|no change|"
              else
                if thistutrole.comment != mytutorcomment
                  thistutrole.update(comment: mytutorcomment)
                end
                if thistutrole.status != ""
                  thistutrole.update(status: "")
                end
                if thistutrole.kind != "onSetup"
                  thistutrole.update(kind: "onSetup")
                end
                if thistutrole.save
                  r["onCallupdates"] += "|updated tutrole|"
                else
                  r["onCallupdates"] += "|update failed|"
                end
              end
            else                # need to be created
              thistutrole = Tutrole.new(lesson_id: thislesson.id,
                                        tutor_id:   thistutor.id,
                                        comment: mytutorcomment,
                                        status: "",
                                        kind: "onCall")
              if thistutrole.save
                r["onCallupdates"] += "|tutrole created #{thistutrole.id}|"
              else
                r["onCallupdates"] += "|tutrole creation failed|"
              end
            end
          end
        end
      end
      # second up is the "Setup"
      # these will have a lesson status of "onsetup"
      # ["DAVID O\n| E12 M12 S10 |"]
      if(mylesson = r["onSetup"])
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
            if thislesson.save
                r["onSetupupdates"] += "|created lession #{thislesson.id}|"
            else
                r["onSetupupdates"] += "|create lession failed|"
            end
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
              if thistutrole.comment == mytutorcomment &&
                 thistutrole.status  == "" &&
                 thistutrole.kind  == "onSetup"
                r["onSetupupdates"] += "|no change #{thistutrole.id}|"
              else
                if thistutrole.comment != mytutorcomment
                  thistutrole.update(comment: mytutorcomment)
                end
                if thistutrole.status != ""
                  thistutrole.update(status: "")
                end
                if thistutrole.kind != "onSetup"
                  thistutrole.update(kind: "onSetup")
                end
                if thistutrole.save
                  r["onSetupupdates"] += "|updated tutrole #{thistutrole.id}|"
                else
                  r["onSetupupdates"] += "|update failed|"
                end
              end
            else                # need to be created
              thistutrole = Tutrole.new(lesson_id: thislesson.id,
                                        tutor_id:   thistutor.id,
                                        comment: mytutorcomment,
                                        status: "",
                                        kind: "onSetup")
              if thistutrole.save
                r["onSetupupdates"] += "|tutrole created #{thistutrole.id}|"
              else
                r["onSetupupdates"] += "|tutrole creation failed|"
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
      #         and all the role records for this slot
      alltutroles = Tutrole.where(lesson_id: thislessons.ids).
                       where.not(kind: ['onSetup', 'onCall'])
      allroles    = Role.where(lesson_id: thislessons.ids)
      # Step 3:
      if(mylessons = r["lessons"])   # this is all the standard
                                     # ss lessons in this slot
        mylessons.each do |mysess|   # treat lesson by lesson from ss
                                     # process each ss lesson row
          thislesson = nil           # ensure all reset
          mylessoncomment = ""
          mylessonstatus = "standard"  # default unless over-ridden
          #
          #   Process Tutors, then students, then comments
          #   A sesson can have only comments without tutors & students
          #
          # Step 3a - check if tutors present
          # if so, this is the lesson to hang onto.
          # Will check later if the students are in the same lesson.
          flagtutorpresent = flagstudentpresent = FALSE
          #
          #   Process tutor
          #
          mytutor = mysess["tutor"]   # only process if tutor exists
                                      # mytutor[0] is ss name string,
                                      # mytutor[1] is colour
                                      # mytutor[2] will record the view feedback
          mytutorcomment = ""         # provide full version in comment
          tutroleupdates = ""         # feedback for display in view
          if mytutor               
            mytutorcomment = mytutor[0]
            mytutornamecontent = findTutorNameComment(mytutor[0], @tutors) 
            mytutorstatus = colourToStatus(mytutor[1])["tutor-status"]
            mytutorkind   = colourToStatus(mytutor[1])["tutor-kind"]
            if mytutorkind == 'BFL'
              mylessonstatus = 'on_BFL'
            end
            if mytutornamecontent.empty?  ||  # no database names found for this tutor
               mytutornamecontent[0]['name'] == ""
                 # put ss name cell content into lesson comment
                 mylessoncomment += mytutor[0] 
            else
              flagtutorpresent = TRUE
              # We have this tutor
              # Find all the tutroles this tutor - this will link
              # to all the lessons this tutor is in.
              # thisslot is the slot we are current populating
              thistutor = Tutor.where(pname: mytutornamecontent[0]["name"]).first
              thistutroles = alltutroles.where(tutor_id: thistutor.id)
              if thistutroles.empty?   # none there, so create one
                # Step 4ai: Create a new lesson containing
                thislesson = Lesson.new(slot_id: thisslot.id,
                                        status: mylessonstatus)
                if thislesson.save
                  tutroleupdates += "|lesson created #{thislesson.id}|"
                else
                  tutroleupdates += "|lesson creation failed"
                end
                thistutrole = Tutrole.new(lesson_id: thislesson.id,
                                          tutor_id:   thistutor.id,
                                          comment: mytutorcomment,
                                          status: mytutorstatus,
                                          kind: mytutorkind)
                if thistutrole.save
                  tutroleupdates += "|tutrole created #{thistutrole.id}|"
                else
                  tutroleupdates += "|tutrole creation failed|"
                end
              else  # already exist
                thistutroles.each do |thistutrole1|
                  # get the lesson they are in
                  thislesson = Lesson.find(thistutrole1.lesson_id)
                  if thislesson[:status] != mylessonstatus
                    thislesson[:status] = mylessonstatus
                    if thislesson.save
                      tutroleupdates += "|updated lesson status #{thislesson.id}|"
                    else                      
                      tutroleupdates += "|lesson status update failed|"
                    end
                  end
                  if thistutrole1.comment == mytutorcomment &&
                     thistutrole1.status  == mytutorstatus &&
                     thistutrole1.kind  == mytutorkind
                    tutroleupdates += "|no change #{thistutrole1.id}|"
                  else
                    if thistutrole1.comment != mytutorcomment
                      #thistutrole1.update(comment: mytutorcomment)
                      thistutrole1.comment = mytutorcomment                end
                    if thistutrole1.status != mytutorstatus
                      #thistutrole1.update(status: mytutorstatus)
                      thistutrole1.status = mytutorstatus
                    end
                    if thistutrole1.kind != mytutorkind
                      #thistutrole1.update(status: mytutorkind)
                      thistutrole1.status = mytutorkind
                    end
                    if thistutrole1.save
                      tutroleupdates += "|updated tutrole #{thistutrole1.id}|"
                    else
                      tutroleupdates += "|update failed|"
                    end
                  end
                end     # thistutroles.each 
              end   # if thistutroles.emepty?
              mytutor[2] = tutroleupdates
            end
          end
          #
          #   Process students
          #
          mystudents = mysess["students"]
          unless mystudents == nil || mystudents.empty?   # there are students in ss
            mystudents.each do |mystudent|                # precess each student
              roleupdates = ""          # records changes to display in view
              mystudentcomment = ""
              mystudentstatus  = colourToStatus(mystudent[1])["student-status"]
              mystudentkind    = colourToStatus(mystudent[1])["student-kind"]
              mystudentnamecontent = findStudentNameComment(mystudent[0], @students) 
              if mystudentnamecontent.empty?  ||  # no database names found for this student
                 mystudentnamecontent[0]['name'] == ""
                # put ss name string into lesson comment
                mylessoncomment += mystudent[0] 
              else
                flagstudentpresent = TRUE    # we have students
                thisstudent = Student.where(pname: mystudentnamecontent[0]["name"]).first
                #logger.debug "thisstudent: " + thisstudent.inspect
                thisroles = allroles.where(student_id: thisstudent.id)
                # CHECK if there is already a lesson from the tutor processing 
                # Step 4ai: Create a new lesson ONLY if necessary
                unless thislesson
                  thislesson = Lesson.new(slot_id: thisslot.id,
                                          status: mylessonstatus)
                  if thislesson.save
                    roleupdates += "|created lesson #{thislesson.id}|"
                  else
                    roleupdates += "|lesson creation failed|"
                  end
                end
                if thisroles.empty?   # none there, so create one
                  thisrole = Role.new(lesson_id: thislesson.id,
                                      student_id:   thisstudent.id,
                                      comment: mystudentcomment,
                                      status: mystudentstatus,
                                      kind: mystudentkind)
                  if thisrole.save
                    roleupdates += "|role created #{thisrole.id}|"
                  else
                    roleupdates += "|role creation failed|"
                  end
                else  # already exist
                  thisroles.each do |thisrole1|
                    # An additional check for students
                    # If a student is allocated to a different tutor
                    # in the db, then we will move them to this tutor
                    # as per the spreadsheet.
                    # Note that a student cannot be in a lesson twice.
                    if thislesson.id != thisrole1.lesson_id
                      # move this student - update the role
                      # student can only be in one lesson for a given slot.
                      if thisrole1.update(lesson_id: thislesson.id)
                        roleupdates += "|role move updated #{thisrole1.id}|"
                      else
                        roleupdates += "|role move failed|"
                      end
                    end
                    if thisrole1.comment == mystudentcomment &&
                       thisrole1.status  == mystudentstatus &&
                       thisrole1.kind    == mystudentkind
                      roleupdates += "|no change #{thisrole1.id}|"
                    else
                      if thisrole1.comment != mystudentcomment
                        #thisrole1.update(comment: mystudentcomment)
                        thisrole1.comment = mystudentcomment
                      end
                      if thisrole1.status != mystudentstatus
                        #thisrole1.update(status: mystudentstatus)
                        thisrole1.status = mystudentstatus
                      end
                      if thisrole1.kind != mystudentkind
                        #thisrole1.update(status: mystudentkind)
                        thisrole1.kind = mystudentkind
                      end
                      if thisrole1.save
                        #r["roleupdates"] += "|role updated #{thisrole1.id}|"
                        roleupdates += "|role updated #{thisrole1.id}|"
                      else
                        #r["roleupdates"] += "|role update failed #{thisrole1.id}|"
                        roleupdates += "|role update failed #{thisrole1.id}|"
                      end
                    end
                  end     # thisroles.each 
                end   # if thisroles.emepty?
              end
              mystudent[2]= roleupdates
            end
          end
          #
          #   Process comments
          #
          if mysess["comment"]
            mycomments = mysess["comment"].strip
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
              # Need the sesson that have no tutor or student - already done
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
            #r["commentupdates"] = ""
            unless thislesson
              thislesson = Lesson.new(slot_id: thisslot.id,
                                        status: 'standard')
              if thislesson.save
                r["commentupdates"] += "|created session for comments #{thislesson.id}|"
              else
                r["commentupdates"] += "|created session for comments failed|"
              end
            end
            if mylessoncomment == thislesson.comments
                r["commentupdates"] += "|no change #{thislesson.id}|"
            else
              thislesson.update(comments: mylessoncomment)
              if thislesson.save
                r["commentupdates"] += "|updated lesson comment #{thislesson.id}|"
              else
                r["commentupdates"] += "|lesson comment update failed #{thislesson.id}|"
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
  # GET /admins/loadtest
  def loadtest
    returned_authorisation = googleauthorisation(request)
    if returned_authorisation["authorizationurl"]
      redirect_to returned_authorisation["authorizationurl"] and return
    end
    service = returned_authorisation["service"]
    #service = googleauthorisation(request)
    spreadsheet_id = '10dXs-AT-UiFV1OGv2DOZIVYHEp81QSchFbIKZkrNiC8'
    sheet_name = 'New Sheet Name'
    range = "#{sheet_name}!A7:C33"
    holdRailsLoggerLevel = Rails.logger.level
    Rails.logger.level = 1 
    response = service.get_spreadsheet(
      spreadsheet_id,
      ranges: range,
      fields: "sheets(data.rowData.values" + 
      "(formattedValue,effectiveFormat.backgroundColor))"
    )
    Rails.logger.level = holdRailsLoggerLevel
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
  
#---------------------------------------------------------------------------
#
#   Load Test 2
#
#   This is simply to allow some testing
#   Create a new spreadsheet from scratch
#
#---------------------------------------------------------------------------
  # GET /admins/loadtest2
  def loadtest2
    returned_authorisation = googleauthorisation(request)
    if returned_authorisation["authorizationurl"]
      redirect_to returned_authorisation["authorizationurl"] and return
    end
    service = returned_authorisation["service"]
#-----------------------------------------------------------------
# Create a new spreadsheet -works and tested
    #request_body = Google::Apis::SheetsV4::Spreadsheet.new
    #response = service.create_spreadsheet(request_body)
    #ss = response
    #spreadsheet_id = ss.spreadsheet_id
#-----------------------------------------------------------------


#-----------------------------------------------------------------
# Use an existing previously created spreadsheet
# Only need the id to make use of this.
    spreadsheet_id = '1VHNfTl0Qxok1ZgBD2Rwby-dqxihgSspA0InqS5dTXNI'
#-----------------------------------------------------------------
    sheet_name = "Sheet1"

# ************ update spreadsheet title  ************************
# https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets/batchUpdate 
    spreadsheet_title = "Testing Updates from BIT Server"
    request_body = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new
    myussp = {"properties": {"title": spreadsheet_title}, "fields": "*" }
    request_body.requests = [{"update_spreadsheet_properties": myussp }]
    result = service.batch_update_spreadsheet(spreadsheet_id, request_body, {})




# ************ delete all cells (rows) in a sheet ****************************
# https://www.rubydoc.info/github/google/google-api-ruby-client/Google/Apis/SheetsV4/Request#delete_range-instance_method 
  	gridrange =  {
    	          sheet_id: 0,
    	          start_row_index: 0,
#    	          end_row_index: 1,
    	          start_column_index: 0,
#    	          end_column_index: 2
    	        }
    requests = []
    requests.push(
      {
        delete_range:{
                        range: gridrange,
                        shift_dimension: "ROWS"
                     }
      }
    )
    body = {requests: requests}
    result = service.batch_update_spreadsheet(spreadsheet_id, body, {})

# ************ update values using update_spreadsheet_value ****************************
# doco: https://www.rubydoc.info/github/google/google-api-ruby-client/Google%2FApis%2FSheetsV4%2FSheetsService%3Aupdate_spreadsheet_value 
    range = "#{sheet_name}!A1:B1"
    request_body = Google::Apis::SheetsV4::ValueRange.new
    request_body.values = [["update_spreadsheet_value","test data - this row will get a background colour"]]
    request_body.major_dimension = "ROWS"
    result = service.update_spreadsheet_value(spreadsheet_id, range, request_body, 
                                              {value_input_option: 'USER_ENTERED'})
    logger.debug "update_spreadsheet_value completed"

# ************ update values using update_spreadsheet_value ****************************
    range = "#{sheet_name}!A2:B3"
        mydata = [
      {
        range: range,
        majorDimension: 'ROWS',
        values: [
                 ["spreadsheet_values_batchUpdate", "test data"],
                 ["spreadsheet_values_batchUpdate", "third row"]
                ]
      }
    ]
    request_body = Google::Apis::SheetsV4::BatchUpdateValuesRequest.new
    request_body.value_input_option = 'USER_ENTERED'
    request_body.data = mydata
    result = service.batch_update_values(spreadsheet_id, request_body, {})

# ******** update background colours using batch_update_spreadsheet ********
  	gridrange =  {
    	          sheet_id: 0,
    	          start_row_index: 0,
    	          end_row_index: 1,
    	          start_column_index: 0,
    	          end_column_index: 2
    	        }
    requests = []
    requests.push(
      {
        repeat_cell: {
  	      range: gridrange,
          cell:
            {
    	        user_entered_format:
    	        {
    		        text_format: {bold: true},
    		        background_color:
    		        {
    			        red: 0.0,
    			        green: 1.0,
    			        blue: 0.0
    		        }
    	        }
  	        },
          fields: "user_entered_format(background_color, text_format.bold)"
        }
      }
    )
    body = {requests: requests}
    result = service.batch_update_spreadsheet(spreadsheet_id, body, {})

# ******** autorezise columns using batch_update_spreadsheet ********
# https://developers.google.com/sheets/api/samples/rowcolumn 
    requests = []
    requests.push(
      {
        auto_resize_dimensions: {
          dimensions:
            {
    	        dimension: "COLUMNS",
    	        sheet_id: 0,
              end_index: 2,
    	        start_index: 0
  	        },
        }
      }
    )
    body = {requests: requests}
    result = service.batch_update_spreadsheet(spreadsheet_id, body, {})

# ******** adjust columns width using batch_update_spreadsheet ********
# https://developers.google.com/sheets/api/samples/rowcolumn 
    requests = []
    requests.push(
      {
        update_dimension_properties: {
          range:
            {
    	        dimension: "COLUMNS",
    	        sheet_id: 0,
              end_index: 2,
    	        start_index: 0
  	        },
  	        properties: {
  	          pixel_size: 160
  	        },
  	        fields: "pixelSize"
        }
      }
    )
    body = {requests: requests}
    result = service.batch_update_spreadsheet(spreadsheet_id, body, {})

  end

#---------------------------------------------------------------------------
#
#   googleroster
#
#   This is simply to allow some testing
#   Create a new spreadsheet from scratch
#
#---------------------------------------------------------------------------
# Some key doco
# https://www.rubydoc.info/github/google/google-api-ruby-client/Google/Apis/SheetsV4
# https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets/request
# This one has the console
# https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets/batchUpdate


  # GET /admins/googleroster
  def googleroster
    returned_authorisation = googleauthorisation(request)
    if returned_authorisation["authorizationurl"]
      redirect_to returned_authorisation["authorizationurl"] and return
    end
    service = returned_authorisation["service"]
#-----------------------------------------------------------------
# Create a new spreadsheet -works and tested
    #request_body = Google::Apis::SheetsV4::Spreadsheet.new
    #response = service.create_spreadsheet(request_body)
    #ss = response
    #spreadsheet_id = ss.spreadsheet_id
#-----------------------------------------------------------------

#-----------------------------------------------------------------
# Use an existing previously created spreadsheet
# Only need the id to make use of this.
   #spreadsheet_id = '1VHNfTl0Qxok1ZgBD2Rwby-dqxihgSspA0InqS5dTXNI'
    spreadsheet_id = '1mfS0V2IRS1x18otIta1kOdfFvRMu6NltEe-edn7MZMc'
#-----------------------------------------------------------------

#-----------------------------------------------------------------
# Use the spreadsheet configured in user profiles
# = Roster Google Spreadsheet URL  
    spreadsheet_id = current_user[:rosterssurl].match(/spreadsheets\/d\/(.*?)\//)[1]

    # Get URL of spreadsheet
    response = service.get_spreadsheet(spreadsheet_id)
    @spreadsheet_url = response.spreadsheet_url

    # Sheet we are working on.
    sheet_name = "Sheet1"
    sheet_id = 0

    #this function converts spreadsheet indices to column name
    # examples: e[0] => A; e[30] => AE 
    e =->n{a=?A;n.times{a.next!};a}  

# ************ update spreadsheet title  ************************
# https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets/batchUpdate
    spreadsheet_title = "Google Roster" 
    request_body = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new
    myussp = {"properties": {"title": spreadsheet_title}, "fields": "*" }
    request_body.requests = [{"update_spreadsheet_properties": myussp }]
    result = service.batch_update_spreadsheet(spreadsheet_id, request_body, {})

# ************ add sheet  ************************
    googleAddSheet = lambda{ |mytitle, mysheetproperties|
      request_body = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new
      myas = {"properties": {"title": mytitle}}
      request_body.requests = [{"add_sheet": myas }]
      result = service.batch_update_spreadsheet(spreadsheet_id, request_body, {})
      mysheetproperties.push({'index'    => result.replies[0].add_sheet.properties.index,
                            'sheet_id' => result.replies[0].add_sheet.properties.sheet_id,
                            'title'    => result.replies[0].add_sheet.properties.title})
    }
    
# ************ delete sheets  ************************
    googleSheetDelete = lambda{
      result = service.get_spreadsheet(spreadsheet_id)
      mysheets = result.sheets
      request_body = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new
      mysheets.each_with_index do |o, i|
        next if i == 0
        request_body.requests == nil ?
          request_body.requests =   [{"delete_sheet": {"sheet_id": o.properties.sheet_id}}] :
          request_body.requests.push({"delete_sheet": {"sheet_id": o.properties.sheet_id}})
      end
      unless request_body.requests == nil
        result = service.batch_update_spreadsheet(spreadsheet_id, request_body, {})
      end
    }

# ************ get spreadsheet properties  ************************
    googleSheetProperties = lambda{
      result = service.get_spreadsheet(spreadsheet_id)
      mysheets = result.sheets
      mysheetproperties = mysheets.map{|p| {'index'    => p.properties.index, 
                                            'sheet_id' => p.properties.sheet_id,
                                            'title'    => p.properties.title } }
    
    }

# ************ update sheet title  ************************
# https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets/batchUpdate
    googleSetSheetTitle = lambda{ |mytitle|
      request_body = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new
      myusp = {"properties": {"title": mytitle }, "fields": "title" }
      request_body.requests = [{"update_sheet_properties": myusp }]
      result = service.batch_update_spreadsheet(spreadsheet_id, request_body, {})
    }

# ************ delete all cells (rows) in a sheet ****************************
# https://www.rubydoc.info/github/google/google-api-ruby-client/Google/Apis/SheetsV4/Request#delete_range-instance_method 
    googleClearSheet = lambda{|passed_sheet_id|
      requests = [{ delete_range:{
        range: {sheet_id: passed_sheet_id, start_row_index: 0, start_column_index: 0 },
        shift_dimension: "ROWS"}}]
      body = {requests: requests}
      result = service.batch_update_spreadsheet(spreadsheet_id, body, {})
    }
    

# ******** set vertical alignment using batch_update_spreadsheet ********
    # googleVertAlignAll.call(palign "TOP | MIDDLE | BOTTOM")
    googleVertAlignAll = lambda{ |passed_sheet_id, palign|
      requests = [{repeat_cell: {
                  	  range: {sheet_id: passed_sheet_id,
                  	          start_row_index: 0,
                  	          start_column_index: 0
                  	  },
                      cell: {user_entered_format: {vertical_alignment: palign} },
                      fields: "user_entered_format(vertical_alignment)"
                    }
      }]
      body = {requests: requests}
      result = service.batch_update_spreadsheet(spreadsheet_id, body, {})
    }

# ****************** calls batch_update_spreadsheet ******************
    # googlebatchdataitem.call(passed_items [googlebackgroundcolouritem, ...])
    googleBatchUpdate = lambda{|passeditems|
      if passeditems.count > 0
        body = {requests: passeditems}
        result = service.batch_update_spreadsheet(spreadsheet_id, body, {})
      end
    }

# ******** update background colours using batch_update_spreadsheet ********
    # googleBGColourItem.call(rowStart, colStart, numberOfRows, numberOfCols,
    #                          colour[red_value, geen_value, blue_value])
    googleBGColourItem = lambda{|passed_sheet_id, rs, cs, nr, nc, pcolour|
      {repeat_cell: {
    	  range: {sheet_id: passed_sheet_id,
    	          start_row_index: rs - 1,
    	          end_row_index: rs - 1 + nr,
    	          start_column_index: cs - 1,
    	          end_column_index: cs - 1 + nc},
        cell:{user_entered_format:
        	     {background_color: {red: pcolour[0], green: pcolour[1], blue: pcolour[2]}}},
                fields: "user_entered_format(background_color)"}}}
                
# ******** set vertical alignment using batch_update_spreadsheet ********
    # googleVertAlign.call(rowStart, colStart, numberOfRows, numberOfCols,
    #                          palign "TOP | MIDDLE | BOTTOM")
    googleVertAlign = lambda{|passed_sheet_id, rs, cs, nr, nc, palign|
      pad = 5
      result = {repeat_cell: {
                  	  range: {sheet_id: passed_sheet_id,
                  	          start_row_index: rs - 1,
                  	          start_column_index: cs - 1 },
                      cell:{user_entered_format: {vertical_alignment: palign,
                                                    padding: {
                                                      top: pad,
                                                      right: pad,
                                                      bottom: pad,
                                                      left: pad
                                                    }
                                                  } 
                           },
                      fields: "user_entered_format(vertical_alignment,padding)"
                    }
      }
      if nr != nil then
        result[:repeat_cell][:range][:end_row_index] = rs - 1 + nr 
      end
      if nc != nil then
        result[:repeat_cell][:range][:end_column_index] = cs - 1 + nc 
      end
      return result
    }

# ******** set wrap text using batch_update_spreadsheet ********
    # googleWrapText.call(rowStart, colStart, numberOfRows, numberOfCols,
    #                          wrap "OVERFLOW_CELL | LEGACY_WRAP | CLIP | WRAP")
    googleWrapText = lambda{|passed_sheet_id, rs, cs, nr, nc, pwrap|
      result = {repeat_cell: {
                  	  range: {sheet_id: passed_sheet_id,
                  	          start_row_index: rs - 1,
                  	          start_column_index: cs - 1 },
                      cell:{user_entered_format: {wrap_strategy: pwrap} },
                      fields: "user_entered_format(wrap_strategy)"
                    }
      }
      if nr != nil then
        result[:repeat_cell][:range][:end_row_index] = rs - 1 + nr 
      end
      if nc != nil then
        result[:repeat_cell][:range][:end_column_index] = cs - 1 + nc 
      end
      return result
    }

# ******** update borders using batch_update_spreadsheet ********
# https://developers.google.com/sheets/api/samples/formatting
    # googleBorder.call(sheet_id, rowStart, colStart, numberOfRows, numberOfCols,
    #                          {left: color, right: .., top: .., bottom: ..}, width)
    googleBorder = lambda{|passed_sheet_id, rs, cs, nr, nc, pcolour, passedStyle |
      {
        update_borders: {
    	      range:  { sheet_id: passed_sheet_id,
          	          start_row_index: rs - 1,
          	          end_row_index: rs - 1 + nr,
          	          start_column_index: cs - 1,
          	          end_column_index: cs - 1 + nc },
            top:    { style: passedStyle,
        	            color: {red: pcolour[0], green: pcolour[1], blue: pcolour[2]}},
            left:   { style: passedStyle,
        	            color: {red: pcolour[0], green: pcolour[1], blue: pcolour[2]}},
            right:  { style: passedStyle,
        	            color: {red: pcolour[0], green: pcolour[1], blue: pcolour[2]}},
            bottom: { style: passedStyle,
        	            color: {red: pcolour[0], green: pcolour[1], blue: pcolour[2]}},
        }
      }
    }

# ******** update borders using batch_update_spreadsheet ********
# https://developers.google.com/sheets/api/samples/formatting
    # googleBorder.call(sheet_id, rowStart, colStart, numberOfRows, numberOfCols,
    #                          {left: color, right: .., top: .., bottom: ..}, width)
    googleRightBorder = lambda{|passed_sheet_id, rs, cs, nr, nc, pcolour, passedStyle |
      {
        update_borders: {
    	      range:  { sheet_id: passed_sheet_id,
          	          start_row_index: rs - 1,
          	          end_row_index: rs - 1 + nr,
          	          start_column_index: cs - 1,
          	          end_column_index: cs - 1 + nc },
            right:  { style: passedStyle,
        	            color: {red: pcolour[0], green: pcolour[1], blue: pcolour[2]}}
        }
      }
    }

# ******** adjust columns width using batch_update_spreadsheet ********
# https://developers.google.com/sheets/api/samples/rowcolumn 

    # googlecolwidthitem.call(colStart, numberOfCols,
    #                          width_pixels)
    googleColWidthItem = lambda{|passed_sheet_id, cs, nc, passedpw|
      {
        update_dimension_properties: {
          range: { dimension: "COLUMNS",
    	             sheet_id: passed_sheet_id,
    	             start_index: cs - 1,
                   end_index: cs - 1 + nc },
  	      properties: { pixel_size: passedpw },
  	      fields: "pixelSize"
        }
      }
    }

# ******** autoresize columns using batch_update_spreadsheet ********
# https://developers.google.com/sheets/api/samples/rowcolumn 

    # googlecolautowidthitem.call(passed_sheet_id, colStart, numberOfCols)
    googleColAutowidthItem = lambda{|passed_sheet_id, cs, nc|
      {
        auto_resize_dimensions: { dimensions: { dimension: "COLUMNS",
                                      	        sheet_id: passed_sheet_id,
                                      	        start_index: cs - 1,
                                                end_index: cs - 1 + nc }
                                }
      }
    }
    
# ******** merge cells using batch_update_spreadsheet ********
# https://developers.google.com/sheets/api/samples/formatting 
    # googleMergeCells.call(passed_sheet_id, rowStart, numOfRows, colStart, numberOfCols)
    googleMergeCells = lambda{|passed_sheet_id, rs, nr, cs, nc|
      {
        merge_cells: { range: { sheet_id: passed_sheet_id,
                                start_row_index: rs - 1,
                                end_row_index: rs - 1 + nr,
                                start_column_index: cs - 1,
                                end_column_index: cs - 1 + nc },
                       merge_type: "MERGE_ALL"
                     }
      }
    }

# ******** format header cells using batch_update_spreadsheet ********
# https://developers.google.com/sheets/api/samples/formatting 
    # googlefomratCells.call(passed_sheet_id, rowStart, numOfRows, colStart, numberOfCols, fontSize)
    googleFormatCells = lambda{|passed_sheet_id, rs, nr, cs, nc, fs|
      {
        repeat_cell: { range: { sheet_id: passed_sheet_id,
                                start_row_index: rs - 1,
                                end_row_index: rs - 1 + nr,
                                start_column_index: cs - 1,
                                end_column_index: cs - 1 + nc },
                       cell:  { user_entered_format: {
                                     horizontal_alignment: "CENTER",
                                     text_format: {
                                          font_size: fs,
                                          bold: true
                                     }
                                }
                              },
                       fields: "userEnteredFormat(textFormat, horizontalAlignment)"
                     }
      }
    }

# ************ update values using update_spreadsheet_value ****************************
# doco: https://www.rubydoc.info/github/google/google-api-ruby-client/Google%2FApis%2FSheetsV4%2FSheetsService%3Aupdate_spreadsheet_value 
# call using

#   googlevalues.call(rowStartIndex, columnStartIndex, numberOfRows, numberOfColumns, values[[]])
# Indexes start at 1 for both rows and columns
    googleValues = lambda{|rs, cs, nr, nc, values| 
    range = "#{sheet_name}!" + e[cs - 1] + rs.to_s + ":" +
                               e[cs + nc - 1] + (rs + nr).to_s
    request_body = Google::Apis::SheetsV4::ValueRange.new
    request_body.values = values
    request_body.major_dimension = "ROWS"
    service.update_spreadsheet_value(spreadsheet_id, range, request_body, 
                                              {value_input_option: 'USER_ENTERED'})
    }
    
# ************ update values using batch_update_values ****************************
    # googlebatchdataitem.call(rowStart, colStart, numberOfRows, numberOfCols,
    #                          values[[]])
    googleBatchDataItem = lambda{|passed_sheet_name, rs, cs, nr, nc, values|
      range = "#{passed_sheet_name}!" + e[cs - 1] + rs.to_s + ":" +
                               e[cs + nc - 1] + (rs + nr).to_s
      {
        range: range,
        majorDimension: 'ROWS',
        values: values
      }
    }

# ************ execute batch update of values - [data items] ****************************
    # googlebatchdataitem.call(spreadsheet_id, 
    #                          passed in batch data [gppg;ebatcjdataote, ...])
    googleBatchDataUpdate = lambda{|ss_id, dataitems |
      if dataitems.count > 0
        request_body = Google::Apis::SheetsV4::BatchUpdateValuesRequest.new
        request_body.value_input_option = 'USER_ENTERED'
        request_body.data = dataitems
        service.batch_update_values(ss_id, request_body, {})
      end
    }

# ************ text format run using batch_update_values ****************************
    # googlebatchTextFormatRunItem.call(rowStart, colStart, 
    #                                   text, breakPointToChangeFormat[])
    googleTextFormatRun = lambda{|passed_sheet_id, rs, cs, myText, myBreaks|
      result = 
        {
            update_cells: {
          	  start: {sheet_id: passed_sheet_id,
          	          row_index: rs - 1,
          	          column_index: cs - 1
          	  },
              rows: [ 
                      { values: [ 
                                  {
                                    user_entered_value: {
                                      string_value: myText
                                    },
                                    user_entered_format: {
                                      text_format: {
                                        fontFamily: "Arial"
                                      }
                                    },
                                    text_format_runs: [
                                      {
                                        start_index: myBreaks[0],
                                        format: {
                                          bold: true,
                                          font_size: 10
                                        }
                                      }
                                    ]
                                  }
                                ]
                      }
                      
              ],
              fields: "userEnteredValue, userEnteredFormat.textFormat.bold, textFormatRuns.format.(bold, fontSize, fontFamily)"
            }
        }
        if myBreaks[1] < myText.length then
          secondRun = {
                  start_index: myBreaks[1],
                  format: {
                    bold: false,
                    font_size: 10
                  }
                }
          result[:update_cells][:rows][0][:values][0][:text_format_runs].push(secondRun)
        end
        return result
    }
                
                
# ************ batch update of data items ****************************
    # googlebatchdataitem.call(spreadsheet_id, 
    #                          passed in batch data [gppg;ebatcjdataote, ...])
    googleBatchDataUpdate = lambda{|ss_id, dataitems |
      if dataitems.count > 0
        request_body = Google::Apis::SheetsV4::BatchUpdateValuesRequest.new
        request_body.value_input_option = 'USER_ENTERED'
        request_body.data = dataitems
        service.batch_update_values(ss_id, request_body, {})
      end
    }

#-------- To test or not to test ------------------------------
testing = false    # true or false
if testing then

#--------------------- Test Data -------------------------------
# Clear the sheet
    googleClearSheet.call(sheet_id)
    
# Some test formatting
    batchitems = []

    batchitems.push(googleBGColourItem.call(sheet_id, 1,1,1,2,[0,1,0]))
    batchitems.push(googleBGColourItem.call(sheet_id, 6,1,1,2,[1,0,0]))
    batchitems.push(googleBGColourItem.call(sheet_id, 7,1,1,2,[0,0,1]))

    batchitems.push(googleBorder.call(sheet_id, 2,1,2,2, [0,0,0], "SOLID_MEDIUM"))
    
    batchitems.push(googleVertAlign.call(sheet_id,2,1,2,2, "TOP"))

    batchitems.push(googleWrapText.call(sheet_id, 2,1,2,2, "WRAP"))

    batchitems.push(googleColWidthItem.call(sheet_id, 1,3,160))
    
    googleBatchUpdate.call(batchitems)    

# Some test cellvalues - individual update
    myvalues = [["update_spreadsheet_value","test data - this row will get a background colour"]]
    googleValues.call(1, 1, 1, 2, myvalues)

# Some test value data - batch update
    mydata = []
    mydata.push(googleBatchDataItem.call(sheet_name,2,1,2,2,
      [
       ["spreadsheet_values_batchUpdate", "test data"],
       ["spreadsheet_values_batchUpdate", "third row"]
      ])
    )
    mydata.push(googleBatchDataItem.call(sheet_name,6,1,2,2,
      [
       ["spreadsheet_values_batchUpdate2", "test data"],
       ["spreadsheet_values_batchUpdate2", "seventh row"]
      ])
    )
    googleBatchDataUpdate.call(spreadsheet_id, mydata)

    #Note: need to do values first so autoformat works.
    batchitems = []  # reset
    batchitems.push(googleColAutowidthItem.call(sheet_id, 1, 1))
    googleBatchUpdate.call(batchitems)    
    
    logger.debug "about to try out googleTextFormatRun"
    batchitems = []
    batchitems.push(googleTextFormatRun.call(sheet_id, 10,2, "123456789\n1234567890123456789", [0,10]))
    googleBatchUpdate.call(batchitems)    
    logger.debug "done googleTextFormatRun"

else      # Not to test.

# let does some processing - writing rosters to google sheets.
    #@sf = 5   # number of significant figures in dom ids for lesson,tutor, etc.

    #mystartdate = current_user.daystart
    #myenddate = current_user.daystart + current_user.daydur.days
    @options = Hash.new
    #@options[:startdate] = current_user.daystart
    #@options[:enddate] = current_user.daystart + current_user.daydur.days
    @options[:startdate] = current_user.rosterstart
    @options[:enddate] = current_user.rosterstart + current_user.rosterdays.days
    
    #*****************************************************************
    # Set these to control what is displayed in the roster
    
    @tutorstatusforroster   = ["scheduled", "dealt", "confirmed", "attended"]
    @studentstatusforroster = ["scheduled", "dealt", "attended"]
    
    #*****************************************************************
    
    # call the library in controllers/concerns/calendarutilities.rb
    #@cal = calendar_read_display2(@sf, mystartdate, myenddate)
    #calendar_read_display1f(sf, mystartdate, myenddate, options)
    
    # @tutors and @students are used by the cal
    @tutors = Tutor
              .where.not(status: "inactive")
              .order('pname')
    @students = Student
                .where.not(status: "inactive")
                .order('pname')
    
    #@cal = calendar_read_display1f(@sf, mystartdate, myenddate, {})
    #@cal = calendar_read_display1f(@sf, @options)
    @cal = calendar_read_display1f(@options)
    # Clear the first sheet - the rest are deleted.
    googleClearSheet.call(sheet_id)
    #googleVertAlignAll.call("TOP")

    # kinds will govern the background colours for tutors and students.
    kindcolours = Hash.new
=begin
    kindcolours = {
                    'tutor-kind-training'     => [244, 164, 96],
                    'tutor-kind-called'       => [135, 206, 250],
                    'tutor-kind-standard'     => [0, 250, 154],
                    'tutor-kind-relief'       => [245, 222, 179],
                    'tutor-kind-BFL'          => [255, 255, 0],
                    'tutor-kind-onCall'       => [0, 255, 255],
                    'tutor-kind-onSetup'      => [234, 209, 220],
                    'student-kind-free'       => [0, 255, 0],
                    'student-kind-first'      => [182, 215, 168],
                    'student-kind-catchup'    => [173, 216, 230],
                    'student-kind-fortnightly' => [70, 130, 180], 
                    'student-kind-onetoone'   => [250, 128, 114],
                    'student-kind-standard'   => [0, 250, 154],
                    'tutor-kind-'             => [255, 255, 255],
                    'tutor-student-'          => [255, 255, 255]
                  }
=end
    kindcolours.default = [255, 255, 255]   # result if called with missing key
    
    # clear unused sheets & get sheet properties
    googleSheetDelete.call
    # sets mysheetproperties = [{'index', 'sheet_id', 'title'}, ..]
    mysheetproperties = googleSheetProperties.call    

    # will increment to 1 on stepping into loops => 1..n
    # Note: both rows and column indexes spreadsheets start at 1
    # Following counters used to track loactions in the spreadsheet
    timeData = ''
    baseSiteRow  = 1 
    baseSlotRowInSite = 1
    baseLessonRowInSlot = 0
    currentTutorRowInLesson = 0
    currentStudentRowInLesson = 0
    currentStudentInLesson = 0
    maxPersonRowInAnySlot = 0
    maxPersonRowInAnySlot = 0
    currentCol = 1
    currentRow = 1
    baseSiteRow  = 1                        # first site 
    baseSiteRowAll  = 1                     # for the 'all' tab 
    locationindex = 0                       # index into the sites
    
    # to compress or not - remove unused days
    @compress = false    # can be true or false

    # have an all tab in google sheets to show all sites in that page
    # this is for tutors to seach for their name across all sites.
    # We still have a separate tab for each site
    googleSetSheetTitle.call("All")
    mysheetproperties[locationindex]['title'] = "All"
    sheet_name_all = mysheetproperties[locationindex]['title']
    sheet_id_all   = mysheetproperties[locationindex]['sheet_id']
    ###----------------------------------------------------------------------
    ###------------------- step through the sites ---------------------------
    ###----------------------------------------------------------------------
    @cal.each do |location, calLocation|    # step through sites
      if @compress   # remove days with no valid slot for this site
        usedColumns = calLocation[0][0]["days"].keys
        usedColumnsIndex = [0]
        for i in 1..(calLocation[0].length-1)
          if usedColumns.include?(calLocation[0][i]["value"]) then
            usedColumnsIndex.push(i)
          end
        end 
      end

      mydata   = []     # google batch data writter at end of processing a site
      myformat = []

      # make separate sheet entry for each site
      baseSiteRow = 1               # reset when new sheet for each site.
                                    # baseSiteRowAll continues across all sites.
      if locationindex == 0         # set up the all tab - contains all sites
        #  googleSetSheetTitle.call(location)
        #  mysheetproperties[locationindex]['title'] = location
        # General formatting for the 'all' sheet - done once
        myformat.push(googleVertAlign.call(sheet_id_all, 1, 1, nil, nil, "TOP"))
        myformat.push(googleWrapText.call(sheet_id_all, 1, 1, nil, nil, "WRAP"))
        myformat.push(googleColWidthItem.call(sheet_id_all, 1,100,200))
        myformat.push(googleColWidthItem.call(sheet_id_all, 1,1,0))
      end
      # now have a sheet for each site.
      mysheetproperties = googleAddSheet.call(location, mysheetproperties)       # add a sheet
      # mysheets = result.sheets
      # mysheetproperties = mysheets.map{|o| {'index'    => o.properties.index, 
      #                                       'sheet_id' => o.properties.sheet_id,
      #                                       'title'    => o.properties.title } }
      locationindex += 1
      sheet_name = mysheetproperties[locationindex]['title']
      sheet_id   = mysheetproperties[locationindex]['sheet_id']

      # This function formats a lesson row
      # myformal and mydata are global to this google roster function
      # we are passing in values to ensure they are in the correct context.
      formatLesson = lambda { |baseLessonRowInSlot, baseSlotRowInSite, baseSiteRow, baseSiteRowAll, currentCol, maxPersonRowInLesson|
        borderRowStart    = baseLessonRowInSlot + baseSlotRowInSite + baseSiteRow
        borderRowStartAll = baseLessonRowInSlot + baseSlotRowInSite + baseSiteRowAll
        borderColStart = currentCol
        borderRows = maxPersonRowInLesson
        borderCols = 4    # one tutor col and 2 student cols + lesson commment col.
        # merge the cells within the comment section of a single session
        # googleMergeCells.call(passed_sheet_id, rowStart, numOfRows, colStart, numberOfCols)
        myformat.push(googleMergeCells.call(sheet_id, borderRowStart, borderRows,
                                                  borderColStart + borderCols - 1, 1))
        myformat.push(googleMergeCells.call(sheet_id_all, borderRowStartAll, borderRows,
                                                  borderColStart + borderCols - 1, 1))
        myformat.push(googleBorder.call(sheet_id,     borderRowStart,    borderColStart, borderRows, borderCols, [0, 0, 0], "SOLID_MEDIUM"))
        myformat.push(googleBorder.call(sheet_id_all, borderRowStartAll, borderColStart, borderRows, borderCols, [0, 0, 0], "SOLID_MEDIUM"))
        myformat.push(googleRightBorder.call(sheet_id,     borderRowStart,    borderColStart, borderRows, 1, [0, 0, 0], "SOLID"))
        myformat.push(googleRightBorder.call(sheet_id_all, borderRowStartAll, borderColStart, borderRows, 1, [0, 0, 0], "SOLID"))
        myformat.push(googleRightBorder.call(sheet_id,     borderRowStart,    borderColStart+2, borderRows, 1, [0, 0, 0], "SOLID"))
        myformat.push(googleRightBorder.call(sheet_id_all, borderRowStartAll, borderColStart+2, borderRows, 1, [0, 0, 0], "SOLID"))
        myformat.push(googleWrapText.call(sheet_id,     borderRowStart,    borderColStart, borderRows, borderCols, "WRAP"))
        myformat.push(googleWrapText.call(sheet_id_all, borderRowStartAll, borderColStart, borderRows, borderCols, "WRAP"))
        # want to put timeslot time (timeData) in first column of each lesson row.
        for i in borderRowStart..borderRowStart+borderRows-1 do
          mydata.push(googleBatchDataItem.call(sheet_name,    i,1,1,1,[[timeData]]))
        end
        for i in borderRowStartAll..borderRowStartAll+borderRows-1 do
          mydata.push(googleBatchDataItem.call(sheet_name_all,i,1,1,1,[[timeData]]))
        end
      }
      #------------- end of lambda function: formatLesson ---------

      render flexibledisplay
      
      # General formatting for each site sheet
      myformat.push(googleVertAlign.call(sheet_id, 1, 1, nil, nil, "TOP"))
      myformat.push(googleWrapText.call(sheet_id, 1, 1, nil, nil, "WRAP"))
      myformat.push(googleColWidthItem.call(sheet_id, 1,100,350))
      myformat.push(googleColWidthItem.call(sheet_id, 1,1,0))

      #<table id=site-<%= location %> >
      baseSlotRowInSite = 0                   # first slot
      currentRow    = baseSlotRowInSite + baseSiteRow
      currentRowAll = baseSlotRowInSite + baseSiteRowAll
      ###----------------------------------------------------------------------
      ###-- step through each time period for this site e.g. 3:30, 4:30, etc. - 
      ###-- (entry 0 = title info: 1. site 2. populated days by date) 
      ###----------------------------------------------------------------------
      calLocation.each do |rows|          # step through slots containing multiple days (fist row is actually a header row!)
        timeData = rows[0]["value"] 
        #<tr>
        maxPersonRowInAnySlot = 0           # initialised to 1 to step a row even if no tutor or student found.
        currentCol = 1
        ###--------------------------------------------------------------------
        ###------- step through each day for this time period -----------------
        ###        (entry 0 = time of lesson)
        ###--------------------------------------------------------------------
        rows.each_with_index do |cells, cellIndex|  # step through each day (first column is head column - for time slots!)
          if @compress 
            unless usedColumnsIndex.include?(cellIndex) then
               next
            end 
          end
          awaystudents = ""
          ###-------------------------------------------------------------------------------------------
          ###------------------- step through each lesson in this slot ---------------------------------
          ###-------------------------------------------------------------------------------------------
          if cells.key?("values") then      # lessons for this day in this slot      
            if cells["values"].respond_to?(:each) then    # check we have lessons?
              # This is a slot with lessons, do I need to output a title.
              #byebug
              # First column for each day needs to have the width set
              # googlecolwidthitem.call(sheet_id, colStart, numberOfCols, width_pixels)
              myformat.push(googleColWidthItem.call(sheet_id, currentCol, 1, 130))
              myformat.push(googleColWidthItem.call(sheet_id_all, currentCol, 1, 130))
              myformat.push(googleColWidthItem.call(sheet_id, currentCol+3, 1, 200))
              myformat.push(googleColWidthItem.call(sheet_id_all, currentCol+3, 1, 200))
              title = calLocation[0][0]['value'] +                                           # site name
                      calLocation[0][cellIndex]['datetime'].strftime("  %A %e/%-m/%y  ")  +  # date
                      rows[0]['value']                                                       # sesson time 
              mydata.push(googleBatchDataItem.call(sheet_name,
                                                   baseSiteRow + baseSlotRowInSite - 1,   
                                                   currentCol,1,1,[[title]]))
              mydata.push(googleBatchDataItem.call(sheet_name_all,
                                                   baseSiteRowAll + baseSlotRowInSite - 1,
                                                   currentCol,1,1,[[title]]))
              # googleMergeCells.call(passed_sheet_id, rowStart, numOfRows, colStart, numberOfCols)
              myformat.push(googleMergeCells.call(sheet_id, baseSiteRow + baseSlotRowInSite - 1, 1,
                                                            currentCol, 4))
              myformat.push(googleMergeCells.call(sheet_id_all, baseSiteRowAll + baseSlotRowInSite - 1, 1,
                                                                currentCol, 4))
              # Format the header line (merged cells)
              # googlefomratCells.call(passed_sheet_id, rowStart, numOfRows, colStart, numberOfCols, fontSize)
              myformat.push(googleFormatCells.call(sheet_id, baseSiteRow + baseSlotRowInSite - 1, 1,
                                                             currentCol, 4, 16))
              myformat.push(googleFormatCells.call(sheet_id_all, baseSiteRowAll + baseSlotRowInSite - 1, 1,
                                                                 currentCol, 4, 16))
              baseLessonRowInSlot = 0       # index of first lesson in this slot for this day
              cells["values"].sort_by {|obj| [valueOrderStatus(obj),valueOrder(obj)] }.each do |entry| # step thru sorted lessons
                next if (entry.status != nil && ["global", "park"].include?(entry.status))
                currentTutorRowInLesson = 0
                if entry.tutors.respond_to?(:each) then
                  entry.tutors.sort_by {|obj| obj.pname }.each do |tutor|
                    if tutor then
                      thistutrole = tutor.tutroles.where(lesson_id: entry.id).first
                      if @tutorstatusforroster.include?(thistutrole.status) then       # tutors of interest
                        currentRow    = currentTutorRowInLesson + baseLessonRowInSlot + baseSlotRowInSite + baseSiteRow
                        currentRowAll = currentTutorRowInLesson + baseLessonRowInSlot + baseSlotRowInSite + baseSiteRowAll
                        #<div class="tutorname tutorinline <%= set_class_status(tutor, entry) %>">tutor: <%= tutor.pname %></div>
                        tutorData    = tutor.pname
                        tutorDataAll = tutor.pname
                        formatBreakPoints    = []
                        formatBreakPointsAll = []
                        formatBreakPoints.push(0)
                        formatBreakPointsAll.push(0)
                        formatBreakPoints.push(tutor.pname.length)
                        formatBreakPointsAll.push(tutor.pname.length)
                        # tutor.subjects
                        mysubjects = tutor.subjects
                        mysubjects = mysubjects ? mysubjects : ""
                        # thistutrole.comment
                        # tutor.comment
                        # Status: thistutrole.status Kind: thistutrole.kind
                        mykind = thistutrole.kind
                        mykind = mykind ? mykind : ""
                        # don't diaplay subjects or kind for tutors on setup
                        unless (entry.status == 'onSetup' && mykind == 'onSetup') ||
                               (entry.status == 'onCall' && mykind == 'onCall')
                          tutorData    += ((mysubjects == "") ? "" : ("\n" + mysubjects)) 
                          tutorData    += ((mykind == "")     ? "" : ("\n" + mykind)) unless ["standard"].include?(mykind)
                          tutorDataAll += ((mykind == "")     ? "" : ("\n" + mykind)) unless ["standard"].include?(mykind)
                        end
                        if thistutrole.comment != nil && thistutrole.comment != ""
                          tutorData += "\n" + thistutrole.comment
                        end
                        mycolour = kindcolours['tutor-kind-' + mykind]
                        mycolour = mycolour.map {|p| p/255.0} 
                        myformat.push(googleTextFormatRun.call(sheet_id,     currentRow,    currentCol,
                                                               tutorData, formatBreakPoints))
                        myformat.push(googleTextFormatRun.call(sheet_id_all, currentRowAll, currentCol,
                                                               tutorDataAll, formatBreakPointsAll))
                        ###myformat.push(googleBGColourItem.call(sheet_id,     currentRow,    currentCol, 1, 1, mycolour))
                        ###myformat.push(googleBGColourItem.call(sheet_id_all, currentRowAll, currentCol, 1, 1, mycolour))
                        currentTutorRowInLesson += 1
                      end       # tutors of interest
                    end
                    #break
                  end
                  # keep track of the largest count of tutors or students in lesson.
                  maxPersonRowInAnySlot = maxPersonRowInAnySlot > currentTutorRowInLesson + baseLessonRowInSlot ?
                                      maxPersonRowInAnySlot : currentTutorRowInLesson + baseLessonRowInSlot
                end
                currentStudentRowInLesson = 0
                currentStudentInLesson    = 0
                studentLessonComments = ""
                if entry.students.respond_to?(:each) then
                  entry.students.each do |student|
                    if student then
                      logger.debug "student: " + student.pname
                      thisrole = student.roles.where(lesson_id: entry.id).first
                      #logger.debug "thisrole: " + thisrole.inspect
                      if ['away', 'awaycourtesy', 'bye', 'absent'].include?(thisrole.status) then 
                        displayname = student.pname + " (" + thisrole.status + ")"
                        awaystudents += awaystudents.length > 0 ?  "\n" + displayname : displayname
                      end
                      if @studentstatusforroster.include?(thisrole.status) then    # students of interest
                        #logger.debug "*************processing student: " + student.pname
                        #logger.debug "currentStudentInLesson: " + currentStudentInLesson.inspect
                        #logger.debug "currentStudentRowInLesson + baseLessonRowInSlot + baseSlotRowInSite: " +
                        #              currentStudentRowInLesson.to_s + ", " + baseLessonRowInSlot.to_s + ", " + baseSlotRowInSite.to_s
                        currentRow    = currentStudentRowInLesson + baseLessonRowInSlot + baseSlotRowInSite + baseSiteRow
                        currentRowAll = currentStudentRowInLesson + baseLessonRowInSlot + baseSlotRowInSite + baseSiteRowAll
                        #<div class="studentname studentinline <%= set_class_status(student, entry) %>">student: <%= student.pname %></div>
                        #logger.debug "DataItem parameters: " + currentRow.to_s + ", " + currentCol.to_s + ", 1, 1, " + student.pname 
                        formatBreakPoints = []
                        formatBreakPoints.push(0)
                        studentData = student.pname
                        studentSex = student.sex == nil ? "" :
                             (student.sex.downcase.include?("female") ? "(F) " : (student.sex.downcase.include?("male") ? "(M) " : ""))
                        studentData += " " + studentSex
                        #logger.debug "student.pname: " + student.pname 
                        #logger.debug "lesson_id: " + entry.id.to_s
                        #formatBreakPoints.push(student.pname.length)
                        #studentSubjects = " Yr: " + (student.year == nil ? "   " : student.year.rjust(3)) +
                        #                  " | " +  (student.study == nil ? "" : student.study)
                        #studentYear      = " Yr:" + (student.year == nil ? student.year.rjust(3))
                        studentYear      = " Yr:" + (student.year == nil ? "" : student.year)
                        studentSubjects  = student.study == nil ? "" : student.study
                        studentData += studentYear
                        studentDataAll = studentData
                        formatBreakPointsAll = formatBreakPoints
                        studentData += "\n" + studentSubjects
                        formatBreakPoints.push(studentData.length)
                        # thisrole.comment
                        # student.comment
                        # Status: thisrole.status Kind: thisrole.kind
                        mykind = thisrole.kind
                        mykind = mykind ? mykind : ""
                        studentData += " (" + mykind + ")" unless ["standard"].include?(mykind)
                        if thisrole.comment != nil && thisrole.comment != ""
                          studentLessonComments += student.pname + ":\n" + thisrole.comment + "\n"
                          #studentData += "\n" + thisrole.comment
                        end
                        if student.comment != nil && student.comment != ""
                          studentData += "\n" + student.comment
                        end
                        mycolour = kindcolours['student-kind-' + mykind]
                        mycolour = mycolour.map {|p| p/255.0}
                        #myformat.push(googleTextFormatRun.call(sheet_id, currentRow, currentCol + 1,
                        #                                       studentData, formatBreakPoints))
                        colOffset = 1 + (currentStudentInLesson % 2)
                        myformat.push(googleTextFormatRun.call(sheet_id,     currentRow,    currentCol + colOffset,
                                                               studentData, formatBreakPoints))
                        myformat.push(googleTextFormatRun.call(sheet_id_all, currentRowAll, currentCol + colOffset,
                                                               studentDataAll, formatBreakPointsAll))
                        ###myformat.push(googleBGColourItem.call(sheet_id,     currentRow,    currentCol + colOffset, 1, 1, mycolour))
                        ###myformat.push(googleBGColourItem.call(sheet_id_all, currentRowAll, currentCol + colOffset, 1, 1, mycolour))
                        
                        #byebug 
                        currentStudentRowInLesson += 1 if (currentStudentInLesson % 2) == 1  # odd
                        currentStudentInLesson += 1
                      end           # students of interest
                    end
                  end
                  # Need to get correct count of rows (rounding up is necessary)
                  # derive currentStudentRowInLesson from the currentStudentInLesson
                  currentStudentRowInLesson = (currentStudentInLesson % 2) == 0 ? 
                  currentStudentInLesson / 2 : (currentStudentInLesson / 2) + 1 
                  
                  # keep track of the largest count of tutors or students in lesson.
                  maxPersonRowInAnySlot = maxPersonRowInAnySlot > currentStudentRowInLesson + baseLessonRowInSlot ?
                                          maxPersonRowInAnySlot : currentStudentRowInLesson + baseLessonRowInSlot
                end
                maxPersonRowInLesson = currentTutorRowInLesson > currentStudentRowInLesson ? 
                                       currentTutorRowInLesson : currentStudentRowInLesson 
                # put a border around this lesson if there were lessons with people
                if maxPersonRowInLesson > 0 then
                  # put in lesson comments if there were tutors or students.
                  #<div class="lessoncommenttext"><% if entry.comments != nil && entry.comments != "" %><%= entry.comments %><% end %></div>
                  #<div class="lessonstatusinfo"><% if entry.status != nil && entry.status != "" %>Status: <%= entry.status %> <% end %></div>
                  mylessoncomment = ''
                  if entry.status != nil && entry.status != ''
                    unless ["standard", "routine", "flexible"].include?(entry.status)   # if this is a standard lesson 
                      mylessoncomment = entry.status + "\n"      # don't show the lesson status (kind)
                    end
                  end
                  mylessoncommentAll = mylessoncomment
                  if entry.comments != nil && entry.comments != ""
                    mylessoncomment += entry.comments
                  end
                  mylessoncomment += studentLessonComments
                  if mylessoncomment.length > 0
                    mylessoncomment = mylessoncomment.sub(/\n$/, '')  # remove trailing new line
                    mydata.push(googleBatchDataItem.call(sheet_name,    currentRow,   currentCol+3,1,1,[[mylessoncomment]]))
                    mydata.push(googleBatchDataItem.call(sheet_name_all,currentRowAll,currentCol+3,1,1,[[mylessoncommentAll]]))
                  end
                  # ----- formatting of the lesson row within the slot ---------
                  formatLesson.call(baseLessonRowInSlot, baseSlotRowInSite, baseSiteRow, baseSiteRowAll, currentCol, maxPersonRowInLesson)
                end
                ###baseLessonRowInSlot += maxPersonRowInLesson
                baseLessonRowInSlot += maxPersonRowInLesson
                #currentRow = maxPersonRowInAnySlot + baseLessonRowInSlot + baseSlotRowInSite + baseSiteRow  # next empty row 
              end     # end looping sorted lessons within a day/slot
            end    # responds to cell["values"]
          elsif cells.key?("value") then     # just holds cell info (not lessons) to be shown
            currentRow    = baseSlotRowInSite + baseSiteRow
            currentRowAll = baseSlotRowInSite + baseSiteRowAll
            #timeData = cells["value"].to_s #if currentCol == 1 &&
                                           #   cells["value"] != nil  # pick up the time
            #mydata.push(googleBatchDataItem.call(sheet_name,    currentRow,   currentCol,1,1,[[cells["value"].to_s]]))
            #mydata.push(googleBatchDataItem.call(sheet_name_all,currentRowAll,currentCol,1,1,[[cells["value"].to_s]]))
          end
          # Now add a dummy row at end of slot to show students who are away
          if awaystudents.length > 0
            currentRow    = baseLessonRowInSlot + baseSlotRowInSite + baseSiteRow
            currentRowAll = baseLessonRowInSlot + baseSlotRowInSite + baseSiteRowAll
            mydata.push(googleBatchDataItem.call(sheet_name,     currentRow,    currentCol,1,1,[["Students Away"]]))
            mydata.push(googleBatchDataItem.call(sheet_name_all, currentRowAll, currentCol,1,1,[["Students Away"]]))
            myformat.push(googleFormatCells.call(sheet_id, currentRow, 1, currentCol, 1, 10))
            myformat.push(googleFormatCells.call(sheet_id_all, currentRowAll, 1, currentCol, 1, 10))
            mydata.push(googleBatchDataItem.call(sheet_name,     currentRow,    currentCol + 1,1,1,[[awaystudents]]))
            mydata.push(googleBatchDataItem.call(sheet_name_all, currentRowAll, currentCol + 1,1,1,[[awaystudents]]))
            maxPersonRowInLesson = 1
            formatLesson.call(baseLessonRowInSlot, baseSlotRowInSite, baseSiteRow,
                              baseSiteRowAll, currentCol, maxPersonRowInLesson)                    # apply the standard formatting
            baseLessonRowInSlot += 1               # add another row for this
            # update tracking of the largest count of tutors or students in lesson.
            maxPersonRowInAnySlot = maxPersonRowInAnySlot > currentStudentRowInLesson + baseLessonRowInSlot ?
                                    maxPersonRowInAnySlot : currentStudentRowInLesson + baseLessonRowInSlot
            maxPersonRowInAnySlot = maxPersonRowInAnySlot > currentTutorRowInLesson   + baseLessonRowInSlot ?
                                    maxPersonRowInAnySlot : currentTutorRowInLesson   + baseLessonRowInSlot
          end
          #</td>
          currentCol += currentCol == 1 ? 1 : 4       # first column is title, rest have adjacent tutors & students.
        end       # end looping days within slots
        #</tr>
        #byebug
        baseSlotRowInSite += maxPersonRowInAnySlot      # set ready for next slot (row of days)
        if baseLessonRowInSlot == 0 && maxPersonRowInAnySlot == 0 then
          baseSlotRowInSite += 1                # cater for when no lessons with tutors or students of interest
        end
        # Add an extra row between slots - except the  first title slot
        # Jasmine wanted no rows between slots so reduced from 2 to 1.
        baseSlotRowInSite += 1 unless baseSlotRowInSite == 1
      end       # end looping slots
      holdRailsLoggerLevel = Rails.logger.level
      Rails.logger.level = 1 
      googleBatchDataUpdate.call(spreadsheet_id, mydata)
      googleBatchUpdate.call(myformat)    
      Rails.logger.level = holdRailsLoggerLevel

      #</table>
      baseSiteRow    += baseSlotRowInSite + 1    # +1 adds blank row between sites
      baseSiteRowAll += baseSlotRowInSite + 1    # +1 adds blank row between sites
      #<br>
    end       # end looping sites
end           # end of testing option.
    return      # return without rendering.
  end


  private
    # Never trust parameters from the scary internet, only allow the white list through.
    def copytermweeks_params
      params.require(:copy).permit(:from, :to, :num_days, :num_weeks, :first_week)
    end

    def copytermdays_params
      params.require(:copy).permit(:from, :to, :num_days)
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def copydays_params
      params.require(:copy).permit(:from, :to, :num_days)
    end

    def deletedays_params
      params.require(:delete).permit(:from, :num_days)
    end

    def deleteolddata_params
      params.require(:delete).permit(:to)
    end

    def set_user_for_models
      Thread.current[:current_user_id] = current_user.id
    end
    
    def reset_user_for_models
      Thread.current[:current_user_id] = nil
    end

  # Sort the values in display2 (cell of lessons/sessions) by status and then by tutor name
  # as some lessons have no tutor, this returns the tutor name if available.
  # This can then be used as the second attribute in the sort.
  # --
  # We make an eaxception to the sort by name if the tutor is actually on BFL or BFLassist
  def valueOrder(obj)
    if obj.tutors.exists?
      obj.tutors.sort_by {|t| t.pname }.first.pname
    else
      "_"
    end
  end

  def valueOrderTutorKindBFL(thistutor) 
    t = ["BFL", "BFLassist"].index(thistutor.kind)
    if t != nil
      return 1 + t
    end
    return 0
  end
        


  def valueOrderStatus(obj)
    mylist = ["onCall", "onSetup", "free",  "on_BFL", "standard", "routine", "flexible", "allocate", "global", "park"]
    if obj.status != nil
      t = mylist.index(obj.status)
      if t != nil
        return t 
      end
    end
    return 0
  end

  
end
