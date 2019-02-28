class RolesController < ApplicationController
  include Calendarutilities
  include ChainUtilities

  before_action :set_role, only: [:show, :edit, :update, :destroy], except: [:catchups]
  before_filter :authenticate_user!, :set_user_for_models
  after_filter :reset_user_for_models

  # GET /roles
  # GET /roles.json
  def index
    @roles = Role
             .order(:id)
             .page(params[:page])
  end

  def catchupoptions
    logger.debug "called roles conroller - catchup options"
  end


  #==================================================================
  # GET /catchups
  # GET /catchups.json
  def catchups
    wantedkind = Array.new
    wantedstatus = Array.new
    params.each do |k, v|
     logger.debug "key: " + k.inspect + " value: " + v.inspect
     if m = k.match(/^select_status_(.*)$/)
     #if m
       wantedstatus.push(m[1])
     end
     if m = k.match(/^select_kind_(.*)$/)
       wantedkind.push(m[1])
     end
    end
    if ! params[:daystart].blank?           # use date parameters provided in catchup options
      @mystartdate = params[:daystart].to_date
    else                                    # use preferences for calendar display
      @mystartdate = current_user.daystart
    end
    if ! params[:daydur].blank?             # use period parameters providedin catchup options
      mydaydur = params[:daydur].to_i
    else                                    # use preferences for calendar display
      mydaydur = current_user.daydur
    end
    @myenddate = @mystartdate + mydaydur.days
    
    @roles = Role
             .includes( :student, lesson: :slot)
             .where(kind: wantedkind, status: wantedstatus, lesson: Lesson.where(slot: Slot.where("timeslot >= :start_date AND timeslot < :end_date", {start_date: @mystartdate, end_date: @myenddate})))
             .order(:id)

    # Now I need to get all the copied from roles
    copied_from_ids = @roles.map{|o| o.copied}
    #@copied_from_roles = Role.find(copied_from_ids)
    @copied_from_roles = Role
                         .where(id: copied_from_ids)
                         .includes(lesson: :slot)
    @copied_from_roles_index = Hash.new
    @copied_from_roles.each do |role|
      @copied_from_roles_index[role.id] = role
    end
  end

  #==================================================================
  # GET /roles/1
  # GET /roles/1.json
  def show
  end

  #==================================================================
  # GET /roles/new
  def new
    @role = Role.new
  end

  #==================================================================
  # GET /roles/1/edit
  def edit
  end

  #==================================================================
  # POST /roles
  # POST /roles.json
  def create
    @role = Role.new(role_params)
    respond_to do |format|
      if @role.save
        format.html { redirect_to @role, notice: 'Role was successfully created.' }
        format.json { render :show, status: :created, location: @role }
      else
        format.html { render :new }
        format.json { render json: @role.errors.full_messages, status: :unprocessable_entity }
        logger.debug "unprocessable entity(line 43): " + @role.errors.full_messages.inspect 
      end
    end
  end

  #==================================================================
  # POST /removestudentfromlesson.json
  def removestudentfromlesson
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    this_error = ""
    # need to ensure object passed is just the student dom id 
    result = /^(([A-Z]+\d+l\d+)n(\d+)([st])(\d+))$/.match(@domchange['object_id'])
    if result
      @domchange['object_id'] = result[1]  # student_dom_id where lesson is to be placed
      @domchange['object_type'] = result[4] == 's' ? 'student' : 'tutor'
      #person_type = @domchange['object_type']
      student_id = result[5]
      #person_id = result[5]
      lesson_id = result[3]
      slot_id = result[2]
      @role = Role.includes(:student).where(:student_id => student_id, :lesson_id => lesson_id).first
    end
    if( @domchange['action'] == 'removerun')   # multiple deletions.
      # Processing the chain.
      this_error = runremovepersonfromlesson(@role)
      if this_error.length > 0
        respond_to do |format|
          format.json { render json: this_error, status: :unprocessable_entity }
        end
        logger.debug "unprocessable entity(line 78): " + this_error 
        return
      end
      return
    else  # single deletion
      # prevent mistakes - front end should never let you get to here.
      if @role.first != nil
        this_error = "You cannot do a single element deletion on a chain element!!"
        respond_to do |format|
          format.json { render json: this_error, status: :unprocessable_entity }
        end
        logger.debug "unprocessable entity(line 89): " + this_error 
        return
      end        
      if @role.destroy
        respond_to do |format|
          format.json { render json: @domchange, status: :ok }
          #ActionCable.server.broadcast "calendar_channel", { json: @domchange }
          ably_rest.channels.get('calendar').publish('json', @domchange)
          # collect the set of stat updates and send through Ably as single message
          statschanges = Array.new
          statschanges.push(get_slot_stats(slot_id))
          ably_rest.channels.get('stats').publish('json', statschanges)
        end
      else
        respond_to do |format|
          format.json { render json: @lesson.errors, status: :unprocessable_entity  }
        end
        logger.debug "unprocessable entity(line 142): " + @role.errors.inspect
      end
    end
  end

  #******************************************************************
  #---------------- Service Function = doAllocation --------------------
  #            *** Not called from the calendar page ***
  # This function will do the required moves when allocating students
  # from the stats page.
  #
  # Input: dom_id of the clicked on element - the one to be extended.
  #        dom_id of the destination lesson - for the source clicked on element.
  # Output: "" if all OK
  #         error message if not OK. Calling code to handle the error.
  #----------------------------------------------------------------------------
  def doAllocation(object_domid, dest_domid)      # element to be moved
    logger.debug "entering doAllocation"
    # We have a set of lambda functions here
    # 1. extend_chain_blocks
    # 2. extend_chain_doms
    # 3. extend_chain_dbUpdates
    # 4. extend_chain_screenUpdates
    #------------------------- build the blocks ------------------------
    # 1. builds @block_roles  
    #    (all the roles to be updated - in sequence if a chain)
    # 2. builds @lessons_roles
    #    Match the @block_roles 
    this_error = ""
    # Extract relevant details from source
    if(result = /^(([A-Z]+\d+l\d+)n(\d+))([st])(\d+)$/.match(object_domid))
      student_id = result[5].to_i
      old_lesson_id = result[3].to_i
      #old_slot_id = result[2]
      @domchange['object_type'] = result[4] == 's' ? 'student':'tutor'
      @domchange['from'] = result[1]
    else
      return "passed clicked_domid parameter to moverun function is incorrect - #{clicked_domid.inspect}"
    end      
    # Extract relevant details from destination
    # The destination lesson (allocate) is determined and placed in @domchange['to']
    # before this function is called.
    if(result = /^(([A-Z]+\d+l\d+)n(\d+))/.match(@domchange['to']))  # destination
      new_lesson_id = result[3].to_i
      #new_slot_id = result[2]
    else
      return "passed dest parameter to moverun function is incorrect - #{dest_domid.inspect}"
    end      
    #---- Do some initial checks on type of allocation ----
    # There are a number of restrictions: They can only come from
    # 1. global (first scheduling of a student)
    # 2. allocate (rescheduling already scheduled student) i.e. parent changed
    #             their minds.
    # There are a number of options based on kind of lesson/student (i.e. role)
    # 1. catchup - only a single element is moved.
    # 2. other types - element is moved to chosen designation, then that element 
    #                  is extended into the rest of the term.
    # Member of 1 & 2 above needs to be refined!!!
    # Logical considerations
    # If moving from global to allocate (lesson.status)
    #   Note: no chains are valid in global!!
    #   If catchup (role.kind)
    #     1. move element from global to allocate (simply a relink to new lesson)
    #   If other than catchup (role.kind)
    #     1. move element from global to allocate
    #     2. turn element into a chain
    #     3. extend this chain to the rest of the term.
    #
    # If moving from allocate to allocate (lesson.status)
    #   If single element
    #     1. Move element to different allocate slot
    #   If link in a chain
    #     If week of year is identical
    #       1. MoveRun the chain.
    #     If week of year is different
    #       1. Determine if role chains becomes longer or shorter
    #       2. Lengthen or shorten the role chain
    #       3. Copy the updated chain (remove roles in db when shortened).
    #
    # Keep a list of all the elements that require a database update
    @block_roles = Array.new
    @block_lessons = Array.new
    #  ** old_lesson_id  ** holds the old lesson_id => so can update @role.lesson_id
    # Get the element we want to move
    @role = Role.includes([:student, lesson: :slot]).where(:student_id => student_id, :lesson_id => old_lesson_id).first
    @new_lesson = Lesson.includes(:slot).find(new_lesson_id)
    return "Allocation Error - Parent lesson is not a part of a chain" if @new_lesson.first == nil 
    if(@role.lesson.status == 'global')    # coming from global 
      logger.debug " in stats moving from global"
      if @role.first != nil                # error if not a single element (not a chain).
        return "Allocation Error - Global elements must not be chains!" 
      end                                  # Guaranteed single element at this point
      if ['first','fortnightly','onetoone','standard', ].include?(@role.kind)    # they become a chain after dropping into allocate
        @role.first = @role.id                # make into a chain
        @role.block = @role.id                # .next defaults to nil - terminates chain.
        # moveing from global to allocate, role status changes from queued to scheduled
        @role.status = 'scheduled'
        this_error = extend_chain_blocks(@new_lesson.id) # Extend the chain to the end of term -> @block_roles 
        return this_error if this_error.length > 0
      else                                 # rest remain single elements (free, catchup, bonus)
        @role.status = 'scheduled'
        @block_roles.push(@role)           # and store for later update (as db transaction)
        @block_lessons.push(@new_lesson)   # the matching lesson
      end
      this_error = extend_chain_doms()
      return this_error if this_error.length > 0
      @domchange['object_id_old'] = @domchangerun[0]['object_id_old']
      @domchange['object_id'] = @domchangerun[0]['object_id']
      @domchange['to'] = @domchangerun[0]['to']
      this_error = extend_chain_relinkrole()
      return this_error if this_error.length > 0
      this_error = extend_chain_dbUpdates()
      return this_error if this_error.length > 0
      this_error = extend_chain_doms_post_db_update()
      return this_error if this_error.length > 0
      this_error = extend_chain_screenUpdates()
      return this_error if this_error.length > 0
    elsif(@role.lesson.status == 'allocate')
      logger.debug " in stats moving from allocate"
      if @role.first == nil                     # single element  
        logger.debug "dealing with a single element"
        @block_roles.push(@role)           # and store for later update (as db transaction)
        @block_lessons.push(@new_lesson)   # the matching lesson
        #this_error = extend_chain_doms.call
        this_error = extend_chain_doms()
        return this_error if this_error.length > 0
        @domchange['object_id_old'] = @domchangerun[0]['object_id_old']
        @domchange['object_id'] = @domchangerun[0]['object_id']
        @domchange['to'] = @domchangerun[0]['to']
        this_error = extend_chain_relinkrole()
        return this_error if this_error.length > 0
        this_error = extend_chain_dbUpdates()
        return this_error if this_error.length > 0
        this_error = extend_chain_doms_post_db_update()
        return this_error if this_error.length > 0
        this_error = extend_chain_screenUpdates()
        return this_error if this_error.length > 0
      else                                  # Moving chain
        logger.debug "dealing with a chain"
        # This chain move is different as it can be moved into a different 
        # starting week of year
        # Step 1 - get the destination chain that matches the destination roles
        logger.debug "get_all_parent_lesson_chain_and_block"
        get_all_parent_lesson_chain_and_block(@role, @new_lesson.id)
        #Step 2 - get the existing role chain requested to be moved.
        logger.debug "get_role_chain_and_block"
        get_role_chain_and_block(@role, {})
        # Step 3 - do they match.
        return "" if @block_roles[0].lesson_id == @block_lessons[0].id # same lesson
        woy_role   = @block_roles[0].lesson.slot.timeslot.to_datetime.cweek
        woy_lesson =      @block_lessons[0].slot.timeslot.to_datetime.cweek
        if woy_role == woy_lesson   # starting on the same week -> standard move
          logger.debug "standard move"
        else                        # move needs to extended or shortened.
          logger.debug "tricky move"
          if @block_roles[0].lesson.slot.timeslot > @block_lessons[0].slot.timeslot
            # roles are moving to an earlier lesson (by at least a week)
            # Week                1 2 3 4 5 6 7 
            # @block_lessons      _ 1 2 3 4 5 6
            # @block_roles        _ _ _ 1 2 3 4   (current)
            # @block_roles        _ 1 2 3 4 + +   (becomes)
            # Beed ti extebd the role block 
            logger.debug "earlier in the term"
            # will need to match up the lesson block to the role block
            @num_elements_added = @block_lessons.count - @block_roles.count
            (0..@num_elements_added-1).each do
              @block_roles.push(@block_roles[0].dup)
            end
          else   # roles have moved to later in term (by at least a week)
            logger.debug "later in the term"
            # Week                1 2 3 4 5 6 7
            # @block_lessons      _ _ _ 1 2 3 4
            # @block_roles        _ 1 2 3 4 5 6       (current)
            # @block_roles        _ _ _ 1 2 3 4 - -   (becomes)
            # Need to shorten the role block.
            numBlocksToRemove = @block_roles.count - @block_lessons.count
            @block_roles_remove = Hash.new if @block_roles_remove == nil  # create if none there
            @block_roles_remove = @block_roles.pop(numBlocksToRemove)
            #@block_roles_remove = @block_roles.shift(numBlocksToRemove)
          end
        end
        #logger.debug "extend_chain_doms"
        this_error = extend_chain_doms()
        return this_error if this_error.length > 0
        @domchange['object_id_old'] = @domchangerun[0]['object_id_old']
        @domchange['object_id'] = @domchangerun[0]['object_id']
        @domchange['to'] = @domchangerun[0]['to']
        #logger.debug "calling relinkrole"
        this_error = extend_chain_relinkrole()
        return this_error if this_error.length > 0
        #logger.debug "extend_chain_dbUpdates"
        this_error = extend_chain_dbUpdates()
        return this_error if this_error.length > 0
        #logger.debug "extend_chain_screenUpdates"
        this_error = extend_chain_doms_post_db_update()
        return this_error if this_error.length > 0
        this_error = extend_chain_screenUpdates()
        return this_error if this_error.length > 0
      end
    end
    return ''
  end
    
  #----------------End of Service Function = doAllocation --------------------

  #******************************************************************
  #---------------- Supporting Functions for doAllocation --------------------
  #------------------------- extend chain blocks ------------------------
  def extend_chain_blocks(new_lesson_id)
    this_error = ""
    @block_roles.push(@role)
    #----------------------- parent extension ----------------------------
    # Now need to find the parent chain
    # We find the existing parent for this role - and get the rest of the run.
    this_error = get_all_parent_lesson_chain_and_block(@role, new_lesson_id)
    return this_error if this_error.length > 0
    # Now copy the roles hortzontally.
    # block_roles[0] is the existing entitiy
    # block_roles[1] is the first one to be created.
    # block_roles[block_roles.length - 1]  is the last one to be created &
    #                                      the last link in the chain.
    @allCopiedSlotsIds = Array.new    # track slots for updating stats
    #thisroleid = @block_roles[0].id
    # Now need to copy this to the following mycopynumweeks weeks.
    # we are forming a chain with first = first id in chain &
    # next = the following id in the chain.
    (1..@block_lessons.length - 1).each do |i|
      parentLessonId = @block_lessons[i].id
      # Not checking for week of year as this is a know new chain as started
      # with a non-chain element.
      # cater for the week plus one entries
      @block_roles[i] = Role.new(lesson_id: parentLessonId,
                                      student_id: @role.student.id, 
                                      status:     @role.status,
                                      kind:       @role.kind,
                                      first:      @role.first,
                                      block:      @role.block)
      if @block_roles[0].student.status == 'fortnightly'
        if @block_roles[0].status == 'bye'
          @block_roles[i].status = i.even? ? 'bye' : 'scheduled' 
        else+
          @block_roles[i].status = i.odd? ? 'bye' : 'scheduled' 
        end
      end
      if @block_roles[0].kind == 'first'
        if i > 0  # leave first item in chain as 'first', change remainder
          if @block_roles[0].student.status == 'standard'
            @block_roles[i].kind = 'standard'
          elsif @block_roles[0].student.status == 'onetoone'
            @block_roles[i].kind = 'onetoone'
          elsif @block_roles[0].student.status == 'fortnightly'
            @block_roles[i].kind = 'fortnightly'
            @block_roles[i].status = i.odd? ? 'bye' : 'fortnightly' 
          end
        end
      end
      @allCopiedSlotsIds.push @block_lessons[i].slot.id    # track all copied slots
      #@domchangerun[i] = @domchangerun[0].dup if @domchangerun[i] == nil 
      #@domchangerun[i]['role']    = @block_roles[i]
      logger.debug "@block_roles ( " + i.to_s + "): " + @block_roles[i].inspect
    end
    return this_error       # be empty if no errors
  end

  #------------------------- perform dom updates ------------------------
  def extend_chain_doms
    # Build the @domchange(domchangerun for each element in the chain
    # Note: In this scenario, there is actually one element in this role chain
    #
    this_error = ""
    @domchangerun = Array.new
    @trackslots = Hash.new    # track and slots that need status updated
    @block_roles.each_with_index do |o, i|
      #logger.debug "block_role (" + i.to_s + "): " + o.inspect
      @domchangerun[i] = Hash.new
      # @domchange['action'] for the element depends on if they are moved, added
      # or deleted.
      # move    is the normal mode for all preexisting elements.
      # remove  is for elements that have been deleted - handled in
      #         block_roles_remove processing 
      # copy    is for elements that have been added - detected by checking
      #         @blocksToAdd which is the number of added elements
      @domchangerun[i]['action']         = 'move'                 # default.
      if @num_elements_added != nil && @num_elements_added > 0    # elements have been added         
        if @block_roles.count - @num_elements_added <= i          # detect added elements
          @domchangerun[i]['action']         = 'copy'
        end
      end
      @domchangerun[i]['object_type']    = @domchange['object_type']
      @domchangerun[i]['old_slot_domid'] = o.lesson.slot.location[0,3] +
                                           o.lesson.slot.timeslot.strftime("%Y%m%d%H%M") +
                                    'l' +  o.lesson.slot_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['from']           = @domchangerun[i]['old_slot_domid'] +
                                    'n' +  o.lesson_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['old_slot_id']   = o.lesson.slot_id
      @trackslots[@domchangerun[i]['old_slot_domid']]     = 1
      @domchangerun[i]['role']          = o
      @domchangerun[i]['student']       = o.student
      @domchangerun[i]['name']          = o.student.pname  # for sorting in the DOM display
      @domchangerun[i]['object_id_old'] = @domchangerun[i]['from'] +
                                    's' + o.student.id.to_s.rjust(@sf, "0")
    end
    # complete with destination info
    @block_lessons.each_with_index do |o, i|
      @domchangerun[i]['new_slot_domid']  = o.slot.location[0,3] +
                                            o.slot.timeslot.strftime("%Y%m%d%H%M") +
                                     'l' +  o.slot_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['to']              = @domchangerun[i]['new_slot_domid'] +
                                     'n' +  o.id.to_s.rjust(@sf, "0")
      @trackslots[@domchangerun[i]['new_slot_domid']] = 1
      #@domchangerun[i]['html_partial']    = 
      #  render_to_string("calendar/_schedule_student.html",
      #                  :formats => [:html], :layout => false,
      #                  :locals => {:student  => @role.student, 
      #                              :thisrole => @domchangerun[i]['role'], 
      #                              :slot     => @domchangerun[i]['new_slot_domid'],                     # new_slot_id, 
      #                              :lesson   => o.id                               # new_lesson_id
      #                             })
      @domchangerun[i]['object_id'] = @domchangerun[i]['to'] +
                                      's' + @role.student_id.to_s.rjust(@sf, "0")
    end
    # # sometimes, we need to remove students on the display
    if @block_roles_remove != nil        # if deletions are required.
       @domchangeremove = Array.new      # build the version to manage display deletes
      (0..@block_roles_remove.length-1).each do |i|
        o = @block_roles_remove[i]                # shorten chain in db
        @domchangeremove[i] = Hash.new if @domchangeremove[i] == nil
        @domchangeremove[i]['action']     = 'remove'
        slot_dom_id                       = o.lesson.slot.location[0,3] +
                                            o.lesson.slot.timeslot.strftime("%Y%m%d%H%M")
        @trackslots[slot_dom_id]          = 1
        #@domchangeremove[i]['object_id']  =        o.lesson.slot.location[0,3] +
        #                                           o.lesson.slot.timeslot.strftime("%Y%m%d%H%M") +
        @domchangeremove[i]['object_id']  = slot_dome_id +
                                            'l' +  o.lesson.slot_id.to_s.rjust(@sf, "0") +
                                            'n' +  o.lesson_id.to_s.rjust(@sf, "0")
        #if o.is_a?('Role')                            
          @domchangeremove[i]['object_id'] += 's' +  o.student_id.to_s.rjust(@sf, "0")
        #elsif o.is_a?('Tutor')
          #@domchangeremove[i]['object_id'] += 't' +  o.tutor_id.to_s.rjust(@sf, "0")
        #end
      end
    end
    # Now provide the new 'object_id' which governs the new display name
    #logger.debug "@domchange['object_id'] : " + @domchange['object_id'].inspect
    @domchange['object_id'] = @domchangerun[0]['object_id']
    #logger.debug "@domchange['object_id'] : " + @domchange['object_id'].inspect
    # Now remove keys not needed
    ###@domchangerun.delete('role')
    ###@domchangerun.delete('student')
    return this_error     # be empty if no errors
  end


  #------------------------ perform dom updates Part 2 -----------------------
  def extend_chain_doms_post_db_update
    # Build the @domchange(domchangerun for each element in the chain
    # This step redoes the rendering after the db is updated.
    #
    this_error = ""
    # redo the steps for the rendering
    @block_lessons.each_with_index do |o, i|
      @domchangerun[i]['html_partial']    = 
        render_to_string("calendar/_schedule_student.html",
                        :formats => [:html], :layout => false,
                        :locals => {:student  => @role.student, 
                                    :thisrole => @domchangerun[i]['role'], 
                                    :slot     => @domchangerun[i]['new_slot_domid'],  # new_slot_id, 
                                    :lesson   => o.id                                 # new_lesson_id
                                   })
    end
    # Now remove keys not needed
    @domchangerun.delete('role')
    @domchangerun.delete('student')
    return this_error     # be empty if no errors
  end

  #---------- relink roles from old_lessons to new_lessons ----------------
  def extend_chain_relinkrole
    @block_roles.each_with_index do |o, i|
      @block_roles[i].lesson_id = @block_lessons[i].id
    end
    return ""
  end

  #------------------------- perform the db update ------------------------
  def extend_chain_dbUpdates
    #------------------------- perform the db update ----------------------
    # block_role now contains all the (block of) elements we need to move
    # Need to step through this chain.
    # Let role be the controlling chain - lesson being the secondary chain
    # transactional code.
    #(0..@block_roles.length-1).each do |i|
    #  @block_roles[i].first = @role.id if @role_breakchainclast         # breaking the chain.
    #  @block_roles[i].lesson_id = @block_lessons[i].id   # change to the database
    #end
    this_error = ""
    flagChain = (@block_roles[0].first == nil) ? false : true 
    begin
      Role.transaction do
        if @block_roles_remove != nil    # sometimes, we need to rmove roles as well as add them
          (0..@block_roles_remove.length-1).each do |i|
            @block_roles_remove[i].destroy!                # shortend chain in db
          end
        end
        flagLengtheningBlock = (@block_roles_remove == nil ? true : false)
        # updateing left to right lengthening the array, else right to left
        processOrder = (0..@block_roles.length-1).map{|o| o}          #elements being added.
        processOrder.reverse! unless flagLengtheningBlock #elements being deleted
        @block_roles[0].save! if @block_roles[0].id == nil  # ensure first link has an id
        processOrder.each do |i|
          if flagChain
            if flagLengtheningBlock      # when adding elements
              # need to save unsaved elements so we can pick up id for next.
              #processOrder.each do |j|
              #  @block_roles[j].save! if @block_roles[j].id == nil
              #end
            end
            if i == @block_roles.length-1            # end the chain.
              @block_roles[i].next = nil
            else
              # db rules prevent a student from being in the same lesson twice.
              if @block_roles[i+1].id == nil  # nothing to copy next from
                @block_roles[i].save!         # need to move this out of the way first
                @block_roles[i+1].save!       # so we can get this id
              end        
              @block_roles[i].next = @block_roles[i+1].id
            end
            ###@block_roles[i].block = @block_roles[0].id
            @block_roles[i].first = @block_roles[0].id
          end
          @block_roles[i].save!                                      # change to the database
          # handle the last entry for week + 1 where block has to set to self
          # this has to be done after the save!!!
          ###if i == @block_roles.length-1
          ###  @block_roles[i].update!(block: @block_roles[i].id)
          ###end
        end
      end
      rescue ActiveRecord::RecordInvalid => exception
        logger.debug "rollback exception: " + exception.inspect
        #this_exception = exception
        logger.debug "Transaction failed!!!"
        this_error = "Transaction failed!!!" + exception.inspect
    end
    return this_error     # be empty if no errors
  end
  
  def extend_chain_screenUpdates()
    # saved safely, now need to update the browser display (using calendar messages)
    # May be some sceen items to remove
    # order of updating sceen elements is important.
    # if lengthing, send left most element first
    # if shortening, delete extras, then send right most elements first
    # First delete elements that are being removed from the end of the chain.
    if @block_roles_remove != nil    # sometimes, we need to rmove roles as well as add them
      (0..@block_roles_remove.length-1).each do |i|
        ably_rest.channels.get('calendar').publish('json', @domchangeremove[i])
      end
    end
    # Now move remaining elements in correct order
    flagLengtheningBlock = (@block_roles_remove == nil ? true : false)
    processOrder = (0..@block_roles.length-1).map{|o| o}          #elements being added.
    processOrder.reverse! unless flagLengtheningBlock #elements being deleted
    processOrder.each do |i|
      ably_rest.channels.get('calendar').publish('json', @domchangerun[i])
    end
    # Now send out the updates to the stats screen - order does not matter.
    # collect the set of stat updates and send through Ably as single message
    statschanges = Array.new
=begin
    (0..@block_roles.length-1).each do |i|
      statschanges.push(get_slot_stats(@domchangerun[i]['new_slot_domid']))
      if(@domchangerun[i].has_key?('old_slot_domid'))
        if(@domchangerun[i]['new_slot_domid'] != @domchangerun[i]['old_slot_domid'])
          statschanges.push(get_slot_stats(@domchangerun[i]['old_slot_domid']))
        end
      end
    end
=end
    @trackslots.each do |k,v|
      statschanges.push(get_slot_stats(k))
    end
    ably_rest.channels.get('stats').publish('json', statschanges)
    # everything is completed successfully.
    return ""
  end

  #--------------End of Support Functions for doAllocation -----------------

  #==================================================================
  # PATCH/PUT /studentmovecopylesson.json
  # this is the ** updated ** function to replace
  # studentmovelesson and studentcopylesson.
  def studentmovecopylesson
    options = {}       # pass options when necessary
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    this_error = ""
    #===#source_chain = false   # track if source is a chain element
    #===#dest_chain = false     # track if moving to a chain
    # from / source
    # need to check if it is from index area or schedule area
    # identified by the id
    # id = t11111     ->  index
    # id = GUN2018... -> schedule
    if((result = /^(([A-Z]+\d+l\d+)n(\d+))s(\d+)$/.match(@domchange['object_id'])))
      student_id = result[4].to_i
      old_lesson_id = result[3].to_i
      #old_slot_id = result[2]
      @domchange['object_type'] = 'student'
      @domchange['from'] = result[1]
      #===#thisrole = Role.where(student_id: student_id, lesson_id: old_lesson_id)
      #===#source_chain = true if thisrole.first
    elsif((result = /^s(\d+)/.match(@domchange['object_id'])))  #index area
      student_id = result[1].to_i
      @domchange['object_type'] = 'student'
      @domchange['action'] = 'copy'    # ONLY a copy allowed from index area.
    else
      this_error += "Source area cannot be identified! "
      logger.debug "neither index or schedule found!!!"
      #return
    end
    #------------------------------------------------------------------------
    # Handle the different destination scenarios.
    #------------------------------------------------------------------------
    # to / destination
    # destination is normally a session, however, there is the special case
    # of moving a catchup to a slot into a 'allocate' session. An 'allocate' 
    # session may or  may not be present - if not present, then we need to
    # create one. From this to_slot parameter, we must derive the 'allocate'
    # session_id.
    #
    # 'extendrun' has no parent 'to' destingation
    # it simply continues the run to the end of the block
    # as defined by the parent.
    if(@domchange['action'] == "extendrun")
      #===#source_chain = true if source_chain     # must be ok to be able to exten
      # Nothing to do here - must ignore - no destination sought.
    elsif(@domchange.has_key?("to_global"))
      #logger.debug "to_global present in parameters"
      # need to find first global lesson after this point in time
      nowdate = DateTime.now.beginning_of_day
      if Rails.env.development?
        nowdate = Date.strptime("18/6/2018", "%d/%m/%Y")
      end
      ###myslots = Slot.where('timeslot > :sd', {sd: nowdate}).order(:timeslot)
      #myslotsids = myslots.map{ |o| o.id}
      #@lesson_new = Lesson.joins(:slot).where({slot_id: myslots, status: 'global'}).order('timeslot').first
      ###@lesson_new = Lesson.joins(:slot)
      ###                    .where({slot_id: myslots, status: 'global'})
      ###                    .order('timeslot')
      ###                    .first
      @lesson_new = Lesson.joins(:slot)
                          .where('status = :st AND timeslot >= :sd', {st: 'global', sd: nowdate})
                          .first
      #===#dest_chain = true if @lesson_new.first   # a chain element
      @domchange['to'] = @lesson_new.slot.location[0..2].upcase
      @domchange['to'] += @lesson_new.slot.timeslot.strftime("%Y%m%d%H%M")
      @domchange['to'] += 'l' + @lesson_new.slot_id.to_s.rjust(@sf, "0")
      @domchange['to'] += 'n' + @lesson_new.id.to_s.rjust(@sf, "0")
      options['to_global'] = @domchange['to_global']
      #new_parent_date = @domchange['to_slot'][3,11]
    elsif(@domchange.has_key?("to_slot"))
      #logger.debug "to_slot present in parameters"
      result = /^(([A-Z]+\d+l(\d+)))/.match(@domchange['to_slot'])
      if result 
        new_slot_dbId = result[3].to_i
        new_slot_id = result[2]
        # Need to find the 'allocate' lesson for this slot.
        @lesson_new = Lesson.where(:slot_id => new_slot_dbId, :status => "allocate" )
                            .first
        #===#if @lesson_new.first
        #===#  dest_chain = true
        #===#end
        unless @lesson_new
          # need to create a new lesson with status 'allocatae'
          @lesson_new = Lesson.new(slot_id: new_slot_dbId, status: "allocate")
          @lesson_new.save
        end
        new_lesson_id = @lesson_new.id
        @domchange['to'] = new_slot_id + 'n' + @lesson_new.id.to_s
      end
    else  # the normal to destination
      result = /^(([A-Z]+\d+l\d+)n(\d+))/.match(@domchange['to'])
      if result 
        new_lesson_id = result[3].to_i
        new_slot_id = result[2]
        @domchange['to'] = result[1]
        #===#thislesson = Lesson.find(new_lesson_id)
        #===#dest_chain = true if thislesson.first
      end
    end
    # to prevent user errors, this check legimate move within
    # the chaining environment. Does impose the expense of a db read.
    #===#if source_chain     # moving a chain element
    #===#  if dest_chain == false   # destination is not a chain
    #===#    this_error += "Student chain element can only be moved into a parent lesson chain"
    #===#  end
    #===#end
    # Intercept and do nothing if parent is the same.
    if new_lesson_id != nil && 
       old_lesson_id == new_lesson_id
      # Nothing to do - just say OK to caller.
      respond_to do |format|
        format.json { render json: @domchange, status: :ok }
      end
      return
    end
    #------------------------------------------------------------------------
    # Now handle the different types of moves or copies.
    #------------------------------------------------------------------------
    if(this_error.length > 0)
      # don't do any more processing, skip to error handling
    #---------------------------- start of extendrun ------------------------
    elsif( @domchange['action'] == 'extendrun')
      # offload extend run to it's own function
      # we must handle any errors here
      this_error = doExtendRun(@domchange['object_id'])
    #---------------------------- start of moverun --------------------------
    elsif( @domchange['action'] == 'moverun')
      this_error = doMoveRun(@domchange['object_id'], @domchange['to'], {})      # element dom_id to be moved, destination dom_id

    #----------------------- start of moverunsingle --------------------------
    # moves a single element in the chain - able to break chain at both sides of element 
    elsif( @domchange['action'] == 'moverunsingle')
      this_error = doMoveRun(@domchange['object_id'], @domchange['to'], {'single' => true})      # element dom_id to be moved, destination dom_id
    #------------------------ Stats Screen Allocation ----------------------
    elsif(@domchange.has_key?('allocation'))
      @domchange['object_id_old'] = @domchange['object_id']
      this_error = doAllocation(@domchange['object_id'], @domchange['to'])      # 
    #------------------------ Single Element operation ----------------------
    elsif(@domchange['action'] == 'move' ||
          @domchange['action'] == 'copy')
      this_error = doSingleMoveCopy(@domchange['action'],     # action - move or copy 
                                    @domchange['object_id'],  # source element
                                    @domchange['to'],         # destination element
                                    options)                 # pass any options
    end
    # If an error, simply report it and end
    if this_error.length > 0
      respond_to do |format|
        format.json { render json: this_error, status: :unprocessable_entity }
      end
      logger.debug "unprocessable entity(line 478): " + this_error.inspect 
      return
    end
    # All OK if you get to here.
    respond_to do |format|
      format.json { render json: @domchange, status: :ok }
    end
  end

  #==================================================================
  # PATCH/PUT /studentupdateskc.json
  # ajax updates skc = status kind comment
  def studentupdateskc
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end

    # from / source
    # need to check if is from index area or schedule area
    # identified by the id
    # id = t11111     ->  index
    # id = GUN2018... -> schedule
    if((result = /^(([A-Z]+\d+l\d+)n(\d+))s(\d+)$/.match(params[:domchange][:object_id])))
      slot_id = result[2]
      student_dbId = result[4].to_i
      lesson_dbId = result[3].to_i
      @domchange['object_type'] = 'student'
      @domchange['from'] = result[1]
    end

    @role = Role  .includes(:student)
                  .where(:student_id => student_dbId, :lesson_id => lesson_dbId)
                  .first

    flagupdate = flagupdatestats = false
    case @domchange['updatefield']
    when 'status'
      if @role.status != @domchange['updatevalue']
        @role.status = @domchange['updatevalue']
        flagupdate = flagupdatestats = true
      end
    when 'kind'
      if @role.kind != @domchange['updatevalue']
        @role.kind = @domchange['updatevalue']
        flagupdate = flagupdatestats = true
      end
    when 'comment'
      if @role.comment != @domchange['updatevalue']
        @role.comment = @domchange['updatevalue']
        flagupdate = true
      end
    end
    
    @domchange['html_partial'] = render_to_string("calendar/_schedule_student.html",
                                :formats => [:html], :layout => false,
                                :locals => {:student => @role.student, 
                                            :thisrole => @role, 
                                            :slot => slot_id, 
                                            :lesson => lesson_dbId
                                           })

    #Thread.current[:current_user_id] = current_user.id
    @updateValues = "test"
    
    #Process if student/lesson status is set to 'away'
    if @role.status_changed? && (@role.status == 'away' ||
                                 @role.status == 'awaycourtesy')
      away_response = action_to_away_controller(@role)
    end
    begin
      Role.transaction do
        @role.save!
        away_response['copied_role'].save! if away_response
      end
      rescue ActiveRecord::RecordInvalid => exception
        this_exception = exception
        respond_to do |format|
          format.json { render json: this_exception, status: :unprocessable_entity }
        end
        logger.debug "unprocessable entity(line 905): " + this_exception.inspect 
        return
    end
    ably_rest.channels.get('calendar').publish('json', @domchange)
    ably_rest.channels.get('calendar').publish('json', away_response['global_lesson_domchange']) if away_response
    if flagupdatestats
      # collect the set of stat updates and send through Ably as single message
      statschanges = Array.new
      statschanges.push(get_slot_stats(slot_id))
      ably_rest.channels.get('stats').publish('json', statschanges)
    end
    respond_to do |format|
      format.json { render json: @domchange, status: :ok }
    end
  end

  #==================================================================
  # PATCH/PUT /roles/1
  # PATCH/PUT /roles/1.json
  def update
    respond_to do |format|
      if @role.update(role_params)
        format.html { redirect_to @role, notice: 'Role was successfully updated.' }
        format.json { render :show, status: :ok, location: @role }
      else
        format.html { render :edit }
        format.json { render json: @role.errors, status: :unprocessable_entity }
        logger.debug "unprocessable entity(line 927): " + @role.errors.inspect 
      end
    end
  end

  #==================================================================
  # DELETE /roles/1
  # DELETE /roles/1.json
  def destroy
    @role.destroy
    respond_to do |format|
      format.html { redirect_to roles_url, notice: 'Role was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
  

  #---------------- Service Function = action_to_away_controller ------------
  # This function will move or copy a single entity
  # WARNING - This will be aborted if this element is a link in a chain.
  #
  # Input: action = 'move' or 'copy'
  #        object_domid = element ot be moved or copied.
  #        dest_domid = destionation location.
  # Output: "" if all OK
  #         error message if not OK. Calling code to handle the error.
  #----------------------------------------------------------------------------

  # This procedure is called when the student status is updated to away.
  # When this is called, the 'role' is already loaded and the status updated, but
  # not yet saved.
  # This procedure now creates a 'global lesson' if not already present,
  # so the global lesson get loaded as @global_lesson.
  # We then copy the '@role' to '@copied_role' to be saved into '@global_lesson'.
  # Web sockets is used to send the updates to the browsers.
  def action_to_away_controller(thisrole)
    logger.debug("+++++++++++++++++++role status has changed" )
    thisrole_lesson = Lesson.includes(:slot).find(thisrole.lesson_id)
    #new_slot_time = @self_lesson.slot.datetime
    #new_slot_location = @self_lesson.slot.location

    # the dom id for the slot are in two different forms
    # GUN201802301530l0001 = when used in the slot itself
    # GUN201802301530      = when used in any dom objects sitting within the slot.
    slot_dom_id_base  = thisrole_lesson.slot.location[0,3].upcase + 
                        thisrole_lesson.slot.timeslot.strftime("%Y%m%d%H%M")            
    slot_dom_id       = slot_dom_id_base + 
                        'l' + thisrole_lesson.slot.id.to_s.rjust(@sf, "0") 
    @global_lessons = Lesson.where(slot_id: thisrole_lesson.slot_id, status: 'global')
    unless(@global_lesson = Lesson.where(slot_id: thisrole_lesson.slot_id, status: 'global').first)
      # No Global Lesson present - so need to create one.
      @global_lesson = Lesson.new(slot_id: thisrole_lesson.slot_id, status: 'global')
      if @global_lesson.save
        # {"action"=>"addLesson", "object_id"=>"GUN201805281530n29174",
        #  "object_type"=>"lesson", "status"=>"flexible"}
        @global_lesson_domchange = {
          'action' => 'addLesson',
          'object_id' => slot_dom_id_base + 
                         'n' + @global_lesson.id.to_s.rjust(@sf, "0"),
          "object_type"=>"lesson", 
          "status"=>"global",
          'to' => slot_dom_id
        }
        @global_lesson_domchange['html_partial'] = render_to_string("calendar/_schedule_lesson_ajax.html", 
                                    :formats => [:html], :layout => false,
                                    :locals => {:slot => slot_dom_id,
                                                :lesson => @global_lesson,
                                                :thistutroles => [],
                                                :thisroles => []
                                               })
  
        
        #ActionCable.server.broadcast "calendar_channel", { json: @global_lesson_domchange }
        ably_rest.channels.get('calendar').publish('json', @global_lesson_domchange)
      else
        return      # if no global, then no point continuing.
      end
    end
    @copied_role = @role.dup
    @copied_role.lesson_id = @global_lesson.id
    # for copied roles when students are changed to away, need to change kind to 'catchup'
    if @role.status == 'away'
      @copied_role.kind = 'catchup'
    elsif @role.status == 'awaycourtesy'
      @copied_role.kind = 'catchupcourtesy'
    end
    #@copied_role.kind = 'catchup'
    @copied_role.status = 'queued'
    @copied_role.copied = @role.id               # remember where copied from.
    @copied_role.first = nil                     # not linked to current chain.
    @copied_role.next  = nil                     # but is in the batch.
    global_lesson_dom_id = slot_dom_id +
                           'n' + @global_lesson.id.to_s.rjust(@sf, "0")
    @global_lesson_domchange = {
      'action'        => 'copy',
      'object_id'     => slot_dom_id + 
                         'n' + @global_lesson.id.to_s.rjust(@sf, "0") +
                         's' + @copied_role.id.to_s.rjust(@sf, "0"),
      "object_type"   =>"student", 
      'to'            => global_lesson_dom_id,
      'object_id_old' => 'xxx',
      "status"        =>@copied_role.status,
      'name'          => @copied_role.student.pname
    }
    @global_lesson_domchange['html_partial'] = render_to_string("calendar/_schedule_student.html", 
                                :formats => [:html], :layout => false,
                                :locals => {:student => @copied_role.student,
                                            :thisrole => @copied_role,
                                            :slot => slot_dom_id,
                                            :lesson => @global_lesson.id
                                           })
    return {'copied_role'             => @copied_role,
            'global_lesson_domchange' => @global_lesson_domchange }

  end
  #---------- end of Service Function = action_to_away_controller ------------



  # Use callbacks to share common setup or constraints between actions.
  def set_role
    @role = Role.find(params[:id])
  end

  def set_user_for_models
    Thread.current[:current_user_id] = current_user.id
  end
  
  def reset_user_for_models
    Thread.current[:current_user_id] = nil
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def role_params
    params.require(:role).permit(:lesson_id, :student_id, :new_sesson_id, :old_lesson_id, :status, :kind,
      :domchange => [:action, :ele_new_parent_id, :ele_old_parent_id, :move_ele_id, :element_type,
                     :to, :to_slot, :allocation]
    )
  end
end