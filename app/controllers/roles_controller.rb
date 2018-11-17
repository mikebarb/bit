class RolesController < ApplicationController
  include Calendarutilities
  
  before_action :set_role, only: [:show, :edit, :update, :destroy]
  before_filter :authenticate_user!, :set_user_for_models
  after_filter :reset_user_for_models

  # GET /roles
  # GET /roles.json
  def index
    @roles = Role
             .order(:id)
             .page(params[:page])
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
    result = /^(([A-Z]+\d+l\d+)n(\d+)s(\d+))$/.match(@domchange['object_id'])
    if result
      @domchange['object_id'] = result[1]  # student_dom_id where lesson is to be placed
      @domchange['object_type'] = 'student'
      student_id = result[4]
      lesson_id = result[3]
      slot_id = result[2]
      @role = Role.where(:student_id => student_id, :lesson_id => lesson_id).first
    end
    if( @domchange['action'] == 'removerun')   # multiple deletions.
      #--------------------------- role ---------------------------------
      this_error = get_role_chain_and_block(@role)
      if this_error.length > 0
        respond_to do |format|
          format.json { render json: this_error, status: :unprocessable_entity }
        end
        logger.debug "unprocessable entity(line 74): " + this_error 
        return
      end
      #  now delete these elements as a single transaction.
      @domchangerun = Array.new
      @block_roles.each_with_index do |o, i|
        logger.debug "block_role (" + i.to_s + "): " + o.inspect
        @domchangerun[i] = Hash.new
        @domchangerun[i]['action']         = 'remove'
        @domchangerun[i]['object_type']    = @domchange['object_type']
        @domchangerun[i]['slot_domid']     = o.lesson.slot.location[0,3] +
                                             o.lesson.slot.timeslot.strftime("%Y%m%d%H%M") +
                                      'l' +  o.lesson.slot.id.to_s.rjust(@sf, "0")
        @domchangerun[i]['object_id']      = @domchangerun[i]['slot_domid'] +      
                                      'n' +  o.lesson_id.to_s.rjust(@sf, "0") +
                                      's' +  o.student_id.to_s.rjust(@sf, "0")
      end
      begin
        Role.transaction do
          (0..@block_roles.length-1).each do |i|
            #@block_roles[i].update!(lesson_id: block_lessons[i].id)   # change to the database
            @block_roles[i].destroy!                                      # change to the database
              # all saved safely, now need to update the browser display (using calendar messages)
              # the object_id will now change (for both move and copy as the inbuild
              # lesson number will change.
          end
          if @role_breakchainlast # break the chain.
            @role_breakchainlast.update!(next: nil)
          end
        end
        rescue ActiveRecord::RecordInvalid => exception
          logger.debug "rollback exception: " + exception.inspect
          this_exception = exception
          logger.debug "Transaction failed!!!"
          this_error = "Transaction failed!!!"
      end
      if this_error.length > 0
        respond_to do |format|
          format.json { render json: this_exception, status: :unprocessable_entity }
        end
        logger.debug "unprocessable entity(line 114): " + this_error 
        return
      end
      # saved safely, now need to update the browser display (using calendar messages)
      (0..@block_roles.length-1).each do |i|
        ably_rest.channels.get('calendar').publish('json', @domchangerun[i])
      end
      # Now send out the updates to the stats screen
      (0..@block_roles.length-1).each do |i|
        get_slot_stats(@domchangerun[i]['slot_domid'])
      end
      # everything is completed successfully.
      respond_to do |format|
        format.json { render json: @domchange, status: :ok }
      end
      return
    else  # single deletion
      if @role.destroy
        respond_to do |format|
          format.json { render json: @domchange, status: :ok }
          #ActionCable.server.broadcast "calendar_channel", { json: @domchange }
          ably_rest.channels.get('calendar').publish('json', @domchange)
          get_slot_stats(slot_id)
        end
      else
        respond_to do |format|
          format.json { render json: @lesson.errors, status: :unprocessable_entity  }
        end
        logger.debug "unprocessable entity(line 142): " + @lesson.errors.inspect 
      end
    end
  end

  #******************************************************************
  #----------------- Helper Function = get_role_and_block_chain ---------------
  # @role_chain contains all the elemets for this chain - even if they have
  # been broken into fragments
  # @block_chain contains all the elements in this fragment of the chain - if 
  # no fragmented, then contains th whole chain.
  def get_role_chain_and_block(role)
    # build the chain for roles.
    @role_chain = Role.where(first: role.first).includes([:student, lesson: :slot])
    # build index (by lesson id) into chain
    @role_chain_index  = Hash.new
    @role_chain_date_index  = Hash.new
    @role_breakchainlast = nil
    @role_chain.each_with_index do |o, i|
      @role_chain_index[o.id] = i
      return fix_lessonMissingSlot(o.lesson) unless o.lesson.slot
      @role_chain_date_index[o.lesson.slot.timeslot.to_datetime.cweek] = o
      # only found if role is not first in chain - so also acts as a flag
      # of needing to break the chain.
      @role_breakchainlast = o if o.next == role.id 
    end
    # now gernerate the block chain that we propagate as the updated elements (roles)
    @block_roles = Array.new
    #option 2: start at the destination element - can be part way through chain
    this_role = @role_chain[@role_chain_index[role.id]]
    ### start_role_week = this_role.lesson.slot.timeslot.cweek
    loop do
      @block_roles.push(this_role)
      break if this_role.next == nil
      if @role_chain_index[this_role.next]    # next role in chain exists?
        this_role = @role_chain[@role_chain_index[this_role.next]]
      else
        # have a problem
        logger.debug "chain is broken - will call the fixing program"
        return fix_broken_chain(@role_chain)
      end
      #check for a loop - elements pointing to another element already present
      @block_roles.each do |o|
        if o.id == this_role.id   # this element is already in the block
          logger.debug "chain points to itself - will call the fixing program"
          return fix_looping_chain(@role_chain)
        end
      end
    end
    return ""
  end
  #------------ End of Helper Function = get_role_and_block_chain -------------

  #******************************************************************
  #----------------- Helper Function = fix_looping_chain -----------------------
  def fix_looping_chain(chain)
    # this chain is broken - must find the break and fix
    unless (chain[0].is_a?(Role) || chain[0].is_a?(Role))
      return "Error - can only fix looping chains for students and tutors"
    end
    # by checking the first & next linkages
    # build indexes (by lesson id) into chain
    full_lesson_index = Array.new
    lesson_first_id = chain[0].lesson.first
    full_lesson_chain = Lesson.where(first: chain[0].lesson.first)
    this_lesson = nil
    full_lesson_chain.each_with_index do |o, i|
      full_lesson_index[o.id] = i
      if o.id == lesson_first_id
        this_lesson = o
      end
    end
    return "Error - Cannot fix looping chain (parent corrupted)!!!" if this_lesson == nil
    # this_lesson is first link in the chain
    lesson_block = Array.new
    loop do
      lesson_block.push(this_lesson)
      break if this_lesson.next == nil   # end of chain
      #check for a loop - elements pointing to another element already present
      this_lesson = full_lesson_chain[full_lesson_index[this_lesson.next]]
      lesson_block.each do |o|
        if o.id == this_lesson.id   # this element is already in the block
          logger.debug "chain points to itself - parent chain so cannot fix"
          return "Error - Cannot fix looping chain (parent looping)!!!"
        end
      end
    end
    # parent chain (lesson_block) is now in chain links order
    # now put the chain elements in the same order
    # first create hash index into the chain by lesson_id (parent)
    chain_index = Hash.new    
    chain.each do |o|
      chain_index[o.lesson_id] = o
    end
    # now build the chain_block
    chain_block = Array.new
    lesson_block.each do |o|
      chain_block.push(chain_index[o.id]) if chain_index.has_key?(o.id)
    end
    # lesson_block is now in chain link order
    # now fix up the linkages
    (0..chain_block.length-1).reverse_each do |i|
      if i == chain.length-1
        chain_block[i].next = nil
      else
        chain_block[i].next = chain_block[i+1].id 
      end
    end
    # Now update the database
    begin
      Role.transaction do
        chain_block.each do |link|
          link.save!                                      # change to the database
            # all saved safely, now need to update the browser display (using calendar messages)
            # the object_id will now change (for both move and copy as the inbuild
            # lesson number will change.
        end
      end
      rescue ActiveRecord::RecordInvalid => exception
        logger.debug "rollback exception: " + exception.inspect
        this_error = "Transaction failed fixing the looping chain!!!" + exception.inspect
    end
    return "--- WARNING --- \n looping chain has been fixed.\n"
  end
  #---------------- End of Helper Function = fix_looping_chain -----------------




  #******************************************************************
  #----------------- Helper Function = fix_broken_chain -----------------------
  def fix_broken_chain(chain)
    # this chain is broken - must find the break and fix
    # by dividing into two chains, one each side of the break
    this_error = ""
    chain_index = Hash.new
    chain_reverse_index = Hash.new
    #block_seq    # track which block we are processing
    blocks = Array.new   # multiple blocks
    # create the chain.
    chain.each_with_index do |o, i|
      chain_index[o.id] = i
      chain_reverse_index[o.next] = o.id
      # only found if role is not first in chain - so also acts as a flag
      # of needing to break the chain.
    end
    #chain_index_processing can be destroyed during processing
    chain_index_proc = chain_index.dup
    while chain_index_proc.length > 0 do
      thislink = chain[chain_index[chain_index_proc.first[0]]]
      loop do 
        if previouslink = chain_reverse_index.has_key?(thislink.id) # there is a previous link
          previouslink = chain(chain_reverse_index(thislink.id))
          thislink = previouslink     # loop again using this link
        else
          # we are at the start of this chain fragment
          break
        end
      end
      start_id = thislink.id  # break and process this fragment.
      # now process this fragment
      myblock = Array.new
      blocks.push(myblock)
      loop do
        # remove this link from the chain_index_proc - as already processed.
        chain_index_proc.delete(thislink.id)
        thislink.first = start_id
        myblock.push(thislink)
        if thislink.next != nil &&
           chain_index.has_key?(thislink.next) # there is a following link
          nextlink = chain[chain_index[thislink.next]]
          #### thislink.next = nextlink.id   # already set. 
          thislink = nextlink
        else    # no next link so terminate chain fragment
          thislink.next = nil
          break                    # break the loop
        end
      end
    end
    # blocks now cotains all the fragments.
    begin
      Role.transaction do
        chain.each do |link|
          link.save!                                      # change to the database
            # all saved safely, now need to update the browser display (using calendar messages)
            # the object_id will now change (for both move and copy as the inbuild
            # lesson number will change.
        end
      end
      rescue ActiveRecord::RecordInvalid => exception
        logger.debug "rollback exception: " + exception.inspect
        this_error = "Transaction failed fixing the broken chain!!!" + exception.inspect
    end
    logger.debug "blocks: " + blocks.inspect 
    return "--- WARNING --- \n fragmented chain has been fixed." +
           " Each fragment is now a separate chain.\n" +
           this_error
  end
  #---------------- End of Helper Function = fix_broken_chain -----------------


  #******************************************************************
  #------------------- Helper Function = fix_lessonMissingSlot ----------------
  def fix_lessonMissingSlot(mylesson)
    myerror = "--- WARNING ---\n"
    myerror += "Removing lesson #{mylesson.id.to_s} that has no slot - created #{mylesson.created_at.to_s}\n"
    thislesson = Lesson.includes([:tutroles, :roles]).find(mylesson.id) 
    thislesson.roles.each do |myrole|
      myerror += "removing attached role with role #{myrole.id.to_s}\n"
      myrole.destroy
    end
    thislesson.tutroles.each do |mytutrole|
      myerror += "removing attached tutrole with role #{mytutrole.id.to_s}\n"
      mytutrole.destroy
    end
    thislesson.destroy
    return myerror
  end
  #------------- End of Helper Function = fix_lessonMissingSlot ---------------

  #---------- Helper Function = get_matching_parent_lesson_chain_and_block -------------
  # WARNING - @block_roles MUST be defined before calling this function.
  #
  # @role_chain contains all the elemets for this chain - even if they have
  # been broken into fragments
  # @block_chain contains all the elements in this fragment of the chain - if 
  # no fragmented, then contains th whole chain.
  # paramenter passed as could be getting either:
  # 1. old or existing parent chain
  # 2. new or move to parent chain.
  # returns: error message - empty if blank.
  #
  # WARNING - @block_roles MUST be defined before calling this function.
  def get_matching_parent_lesson_chain_and_block(new_lesson_id)
    new_lesson = Lesson.includes(:slot).find(new_lesson_id)
    @new_lesson_chain = Lesson.where(first: new_lesson.first).includes([:slot])
    # build index (by lesson id) into chain
    @new_lesson_chain_index  = Hash.new
    @new_lesson_chain_date_index  = Hash.new
    @new_lesson_chain.each_with_index do |o, i|
      @new_lesson_chain_index[o.id] = i
      #fix_lessonMissingSlot(o) unless o.lesson.slot
      return fix_lessonMissingSlot(o) unless o.slot
      @new_lesson_chain_date_index[o.slot.timeslot.to_datetime.cweek] = o
    end
    # now generate the block chain that we propagate as the new parent
    @block_lessons = Array.new
    #option 2: start at the destination element - can be part way through chain
    this_lesson = @new_lesson_chain[@new_lesson_chain_index[new_lesson_id]]
    (0..@block_roles.length-1).each do |i|    # only want to match the roles
      @block_lessons[i] = this_lesson
      break if this_lesson.next == nil     # end of the lesson chain.
      this_lesson = @new_lesson_chain[@new_lesson_chain_index[this_lesson.next]]
    end
    # Now to check if role and lesson block chains match.
    if @block_lessons.length !=  @block_roles.length     # must be same length
      if @block_lessons.length < @block_roles.length
        return "moverun error: role chain is longer than the (parent) lesson chain"
      else
        return "moverun error: role chain is shorter than the (parent) lesson chain"
      end
    end
    #check that roles and lessons are in step - check week of year (woy) for each.
    (0..@block_lessons.length-1).each do |i|
      woy_role   = @block_roles[i].lesson.slot.timeslot.to_datetime.cweek
      woy_lesson =      @block_lessons[i].slot.timeslot.to_datetime.cweek
      if woy_role != woy_lesson   # out of step
        return "moverun error: role and lessons not matching for each week"
      end
      break if this_lesson.next == nil     # at end of chain.
      this_lesson = @new_lesson_chain[@new_lesson_chain_index[this_lesson.next]]
    end
    return ""     # no errors
  end
  #------- End of Helper Function = get_parent_lesson_chain_and_block ---------

  #******************************************************************
  #---------- Helper Function = get_all_parent_lesson_chain_and_block ----------
  # Beginning at the passed lesson, gets all remaining links in chain.
  #
  # modified version of get_matching_parent_lesson_chain_and_block
  # only difference is that ALL the parent block chain from the matching
  # starting role is returned AS OPPOSED to just the matching portion.
  # return: nothing is returned.
  def get_all_parent_lesson_chain_and_block(new_lesson_id)
    new_lesson = Lesson.includes(:slot).find(new_lesson_id)
    @new_lesson_chain = Lesson.where(first: new_lesson.first).includes([:slot])
    # build index (by lesson id) into chain
    @new_lesson_chain_index  = Hash.new
    @new_lesson_chain_date_index  = Hash.new
    @new_lesson_chain.each_with_index do |o, i|
      @new_lesson_chain_index[o.id] = i
      return fix_lessonMissingSlot(o) unless o.slot
      @new_lesson_chain_date_index[o.slot.timeslot] = o
    end
    # now generate the block chain that we propagate as the new parent
    @block_lessons = Array.new
    #option 2: start at the destination element - can be part way through chain
    this_lesson = @new_lesson_chain[@new_lesson_chain_index[new_lesson_id]]
    #option 2: start at the destination element - can be part way through chain
    loop do
      @block_lessons.push(this_lesson)
      break if this_lesson.next == nil
      this_lesson = @new_lesson_chain[@new_lesson_chain_index[this_lesson.next]]
    end
    return ""
  end
  #------- End of Helper Function = get_parent_lesson_chain_and_block ---------

  #******************************************************************
  #--------------------- Service Function = doExtendRun -----------------------
  # This function will extend a chain from the clicked on element through
  # to the rest of the term and into the week + 1.
  # The chain goes all the way through to week + 1 inclusive
  # The chain block is only for the term.
  # Thus the chain "block" does not include week +1.
  # WARNING - if the schecule is not set up with week+1, you will get
  #           incorrect results.
  #
  # Input: dom_id of the clicked on element - the one to be extended.
  # Output: "" if all OK
  #         error message if not OK. Calling code to handle the error.
  #----------------------------------------------------------------------------
  def doExtendRun(clicked_domid)      # element to be extended
    if(result = /^(([A-Z]+\d+l\d+)n(\d+))s(\d+)$/.match(clicked_domid))
      student_id = result[4].to_i
      old_lesson_id = result[3].to_i
      old_slot_id = result[2]
      @domchange['object_type'] = 'student'
      @domchange['from'] = result[1]
    else
      return "passed parameter to extend run function isincorrect - #{clicked_domid.inspect}"
    end      
    #--------------------------- role ---------------------------------
    # .includes([:student , lesson: :slot])
    @role = @role = Role.where(:student_id => student_id, :lesson_id => old_lesson_id).first
    # build the chain for roles - contains all elements of the original chain - even when fragmented.
    # and the block chain that we propagate as the updated elements (roles)
    #
    # First check if this role is part of a chain. Make a chain if not.
    if @role.block == nil
      @role.block = @role.id
      @role.first = @role.id
      @role.next = nil
    end
    this_error = get_role_chain_and_block(@role)
    return this_error if this_error.length > 0
    # Build the @domchange(domchangerun for each element in the chain
    @domchangerun = Array.new
    @block_roles.each_with_index do |o, i|
      logger.debug "block_role (" + i.to_s + "): " + o.inspect
      @domchangerun[i] = Hash.new
      @domchangerun[i]['action']         = 'copy'                 # extendrun of individual elements. 
      @domchangerun[i]['object_type']    = @domchange['object_type']
      @domchangerun[i]['old_slot_domid'] = o.lesson.slot.location[0,3] +
                                           o.lesson.slot.timeslot.strftime("%Y%m%d%H%M") +
                                    'l' +  o.lesson.slot_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['from']           = @domchangerun[i]['old_slot_domid'] +
                                    'n' +  o.lesson_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['old_slot_id']   = o.lesson.slot_id
      @domchangerun[i]['role']          = o
      @domchangerun[i]['student']       = o.student
      @domchangerun[i]['name']          = o.student.pname  # for sorting in the DOM display
      @domchangerun[i]['object_id_old'] = @domchangerun[i]['from'] +
                                    's' + o.student.id.to_s.rjust(@sf, "0")
    end
    #--------------------------- parent extension ---------------------------------
    # Now need to find the parent chain
    # We find the existing parent for this role - and get the rest of the run.
    this_error = get_all_parent_lesson_chain_and_block(@role.lesson_id)
    return this_error if this_error.length > 0
    # Now copy the roles hortzontally.
    # block_roles[0] is the existing entitiy
    # block_roles[1] is the first one to be created.
    # block_roles[block_roles.length - 1]  is the last one to be created &
    #                                      the last link in the chain.
    #@block_lessons <= @blockLessons
    #@block_roles   <= @blockRoles
    @allCopiedSlotsIds = Array.new    # track slots for updating stats
    thisroleid = @block_roles[0].id
    # Now need to copy this to the following mycopynumweeks weeks.
    # we are forming a chain with first = first id in chain &
    # next = the following id in the chain.
    (1..@block_lessons.length - 1).each do |i|
      parentLessonId = @block_lessons[i].id
      # Need to check if there is an role with the same week of year
      # as this parent lesson.
      woy_lesson = @block_lessons[i].slot.timeslot.to_datetime.cweek
      if @role_chain_date_index.has_key?(woy_lesson)
        # we already have a role in this week - not valid.
        this_error = "error extendrun -  already an entry for this role in this week (week #{woy_lesson})"
        break
      end
      # cater for the week plus one entries
      @block_roles[i] = Role.new(lesson_id: parentLessonId,
                                      student_id: @role.student.id, 
                                      status: 'scheduled',
                                      kind: @role.kind,
                                      first: @role.first,
                                      block: @role.block)
      if @block_roles[0].student.status == 'fortnightly'
        if @block_roles[0].status == 'bye'
          @block_roles[i].status = i.even? ? 'bye' : 'scheduled' 
        else
          @block_roles[i].status = i.odd? ? 'bye' : 'scheduled' 
        end
      end
      @allCopiedSlotsIds.push @block_lessons[i].slot.id    # track all copied slots
      @domchangerun[i] = @domchangerun[0].dup if @domchangerun[i] == nil 
      @domchangerun[i]['role']    = @block_roles[i]
      logger.debug "@block_roles ( " + i.to_s + "): " + @block_roles[i].inspect
    end
    # Deal with errors found & terminate
    return this_error if this_error.length > 0
    (0..@block_roles.length - 1).reverse_each do |i|
      # the last entity in chain will have next = nil by default, do not populate.
      @block_roles[i].next = @block_roles[i+1].id unless i == @block_roles.length - 1  
    end
    @block_lessons.each_with_index do |o, i|
      #@domchangerun[i] = @domchangerun[0].dup if @domchangerun[i] == nil  
      @domchangerun[i]['new_slot_domid']  = o.slot.location[0,3] +
                                            o.slot.timeslot.strftime("%Y%m%d%H%M") +
                                     'l' +  o.slot_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['to']              = @domchangerun[i]['new_slot_domid'] +
                                     'n' +  o.id.to_s.rjust(@sf, "0")
      #@domchangerun[i]['new_slot_id']     = o.slot_id
      #@domchangerun[i]['lesson_id']      = o.lesson_id
      @domchangerun[i]['html_partial']    = 
        render_to_string("calendar/_schedule_student.html",
                        :formats => [:html], :layout => false,
                        :locals => {:student  => @role.student, 
                                    :thisrole => @domchangerun[i]['role'], 
                                    :slot     => @domchangerun[i]['new_slot_domid'],                     # new_slot_id, 
                                    :lesson   => o.id                               # new_lesson_id
                                   })
      @domchangerun[i]['object_id'] = @domchangerun[i]['to'] +
                                      's' + @role.student_id.to_s.rjust(@sf, "0")
      #@domchangerun[i]['object_id'] = 's' + @role.student_id.to_s.rjust(@sf, "0")

    end
    #------------------------- perform the db update ------------------------
    # block_role now contains all the (block of) elements we need to move
    # Need to step through this chain.
    # Let role be the controlling chain - lesson being the secondary chain
    # transactional code.
    #(0..@block_roles.length-1).each do |i|
    #  @block_roles[i].first = @role.id if @role_breakchainclast         # breaking the chain.
    #  @block_roles[i].lesson_id = @block_lessons[i].id   # change to the database
    #end
    begin
      Role.transaction do
        (0..@block_roles.length-1).reverse_each do |i|
          @block_roles[i].next = @block_roles[i+1].id unless i == @block_roles.length-1  # end the chain.
          @block_roles[i].save!                                      # change to the database
          # handle the last entry for week + 1 where block has to set to self
          # this has to be done after the save!!!
          if i == @block_roles.length-1
            @block_roles[i].update!(block: @block_roles[i].id)
          end
        end
      end
      rescue ActiveRecord::RecordInvalid => exception
        logger.debug "rollback exception: " + exception.inspect
        this_error = "Transaction failed!!!"+ exception.inspect
    end
    return this_error if this_error.length > 0
    # saved safely, now need to update the browser display (using calendar messages)
    (1..@block_roles.length-1).each do |i|
      ably_rest.channels.get('calendar').publish('json', @domchangerun[i])
    end
    # Now send out the updates to the stats screen
    (1..@block_roles.length-1).each do |i|
      get_slot_stats(@domchangerun[i]['new_slot_domid'])
      #if(@domchangerun[i]['new_slot_domid'] != @domchangerun[i]['old_slot_domid'])
      #  get_slot_stats(@domchangerun[i]['old_slot_domid'])
      #end
    end
    # everything is completed successfully.
    #respond_to do |format|
    #  format.json { render json: @domchange, status: :ok }
    #end
    return ""
  end
  #-----------------End of Service Function = doExtendRun ---------------------

  #******************************************************************
  #---------------- Service Function = doMoveRun --------------------
  # This function will extend a chain from the clicked on element through
  # to the rest of the term and into the week + 1.
  # The chain goes all the way through to week + 1 inclusive
  # The chain block is only for the term.
  # Thus the chain "block" does not include week +1.
  # WARNING - if the schecule is not set up with week+1, you will get
  #           incorrect results.
  #
  # Input: dom_id of the clicked on element - the one to be extended.
  # Output: "" if all OK
  #         error message if not OK. Calling code to handle the error.
  #----------------------------------------------------------------------------
  def doMoveRun(object_domid, dest_domid)      # element to be extended
    this_error = ""
    if(result = /^(([A-Z]+\d+l\d+)n(\d+))([st])(\d+)$/.match(object_domid))
      student_id = result[5].to_i
      old_lesson_id = result[3].to_i
      old_slot_id = result[2]
      @domchange['object_type'] = result[4] == 's' ? 'student':'tutor'
      @domchange['from'] = result[1]
    else
      return "passed clicked_domid parameter to moverun function is incorrect - #{clicked_domid.inspect}"
    end      
    if(result = /^(([A-Z]+\d+l\d+)n(\d+))/.match(dest_domid))
      new_lesson_id = result[3].to_i
      new_slot_id = result[2]
      @domchange['from'] = result[1]
    else
      return "passed dest parameter to moverun function is incorrect - #{dest_domid.inspect}"
    end      
    # Before we start any database operations,
    # check that dates on the old parent and new parents match.
    # moverun must always START on the SAME week.
    # First = get object_id date (element being moved)
    mm = /^[A-Za-z]+(\d\d\d\d)(\d\d)(\d\d)/.match(object_domid)
    role_date = DateTime.new(mm[1].to_i, mm[2].to_i, mm[3].to_i);
    # Second = get destination date
    mm = /^[A-Za-z]+(\d\d\d\d)(\d\d)(\d\d)/.match(dest_domid)
    new_parent_date = DateTime.new(mm[1].to_i, mm[2].to_i, mm[3].to_i);
    if role_date.cweek != new_parent_date.cweek
      this_error = "moverun must copy entities within the same week"
      logger.debug "moverun is not on the same day!!!"
    end
    if new_lesson_id == old_lesson_id
      this_error += "\n" + "moverun must copy to a different parent lesson"
      logger.debug "moverun must copy to a different parent lesson!!!"
    end
    return this_error if this_error.length > 0
    #---- Chain of elements operation ----
    # As this is a move, we simply need to relink the lesson from old to new
    # for each member of the chain.
    # I need to get the destination (dropped) element to get 'start' for
    # finding the chain.
    
    # need to produce the matching block chain for the roles
    # get the chain of existing roles - so that we can change the parent
    # in each of these. The roles are actually only updated
    #--------------------------- role ---------------------------------
    # .includes([:student , lesson: :slot])
    @role = Role.where(:student_id => student_id, :lesson_id => old_lesson_id).first
    #role = @role
    # build the chain for roles - contains all elements of the original chain - even when fragmented.
    # and the block chain that we propagate as the updated elements (roles)
    this_error = ""
    this_error = get_role_chain_and_block(@role)
    if this_error.length > 0
      respond_to do |format|
        format.json { render json: this_error, status: :unprocessable_entity }
      end
      logger.debug "unprocessable entity(line 685): " + this_error 
      return
    end
    # Build the @domchange(domchangerun for each element in the chain
    @domchangerun = Array.new
    @block_roles.each_with_index do |o, i|
      logger.debug "block_role (" + i.to_s + "): " + o.inspect
      @domchangerun[i] = Hash.new
      #@domchangerun[i]['action']        = @domchange['action'] 
      @domchangerun[i]['action']         = 'move'                 # moverun of individual elements. 
      @domchangerun[i]['object_type']    = @domchange['object_type']
      @domchangerun[i]['old_slot_domid'] = o.lesson.slot.location[0,3] +
                                           o.lesson.slot.timeslot.strftime("%Y%m%d%H%M") +
                                    'l' +  o.lesson.slot_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['from']           = @domchangerun[i]['old_slot_domid'] +
                                    'n' +  o.lesson_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['old_slot_id']   = o.lesson.slot_id
      @domchangerun[i]['role']          = o
      @domchangerun[i]['student']       = o.student
      @domchangerun[i]['name']          = o.student.pname  # for sorting in the DOM display
      @domchangerun[i]['object_id_old'] = @domchangerun[i]['from'] +
                                    's' + o.student.id.to_s.rjust(@sf, "0")
    end
    #--------------------------- new parent ---------------------------------
    # Now need to find the parent chain
    this_error = get_matching_parent_lesson_chain_and_block(new_lesson_id)
    if this_error.length > 0
      respond_to do |format|
        format.json { render json: this_error, status: :unprocessable_entity }
      end
      logger.debug "unprocessable entity(line 715): " + this_error 
      return
    end
    @block_lessons.each_with_index do |o, i|
      @domchangerun[i]['new_slot_domid']  = o.slot.location[0,3] +
                                            o.slot.timeslot.strftime("%Y%m%d%H%M") +
                                     'l' +  o.slot_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['to']              = @domchangerun[i]['new_slot_domid'] +
                                     'n' +  o.id.to_s.rjust(@sf, "0")
      @domchangerun[i]['new_slot_id']     = o.slot_id
      #@domchangerun[i]['lesson_id']      = o.lesson_id
      @domchangerun[i]['html_partial']    = 
        render_to_string("calendar/_schedule_student.html",
                        :formats => [:html], :layout => false,
                        :locals => {:student  => @domchangerun[i]['student'], 
                                    :thisrole => @domchangerun[i]['role'], 
                                    :slot     => @domchangerun[i]['new_slot_domid'],                     # new_slot_id, 
                                    :lesson   => o.id                         # new_lesson_id
                                   })
      @domchangerun[i]['object_id'] = @domchangerun[i]['to'] +
                                          's' + @domchangerun[i]['student'].id.to_s.rjust(@sf, "0")
    end
    #------------------------- perform the db update ------------------------
    # block_role now contains all the (block of) elements we need to move
    # Need to step through this chain.
    # Let role be the controlling chain - lesson being the secondary chain
    # transactional code.
    (0..@block_roles.length-1).each do |i|
      @block_roles[i].first = @role.id if @role_breakchainlast         # breaking the chain.
      @block_roles[i].lesson_id = @block_lessons[i].id   # change to the database
    end
    begin
      Role.transaction do
        (0..@block_roles.length-1).each do |i|
          #@block_roles[i].update!(lesson_id: @block_lessons[i].id)   # change to the database
          @block_roles[i].save!                                      # change to the database
            # all saved safely, now need to update the browser display (using calendar messages)
            # the object_id will now change (for both move and copy as the inbuild
            # lesson number will change.
        end
        if @role_breakchainlast # break the chain.
          @role_breakchainlast.update!(next: nil)
        end
      end
      rescue ActiveRecord::RecordInvalid => exception
        logger.debug "rollback exception: " + exception.inspect
        this_exception = exception
        logger.debug "Transaction failed!!!"
        this_error = "Transaction failed!!!"
    end
    if this_error.length > 0
      respond_to do |format|
        format.json { render json: this_exception, status: :unprocessable_entity }
      end
      logger.debug "unprocessable entity(line 769): " + this_error 
      return
    end
    # saved safely, now need to update the browser display (using calendar messages)
    (0..@block_roles.length-1).each do |i|
      ably_rest.channels.get('calendar').publish('json', @domchangerun[i])
    end
    # Now send out the updates to the stats screen
    (0..@block_roles.length-1).each do |i|
      get_slot_stats(@domchangerun[i]['new_slot_domid'])
      if(@domchangerun[i]['new_slot_domid'] != @domchangerun[i]['old_slot_domid'])
        get_slot_stats(@domchangerun[i]['old_slot_domid'])
      end
    end
    # everything is completed successfully.
    #respond_to do |format|
    #  format.json { render json: @domchange, status: :ok }
    #end
    return ""
  end
  #------------------End of Service Function = doMoveRun ---------------------


  #******************************************************************
  #--------------------- Service Function = doSingleMoveCopy -----------------------
  # This function will move or copy a single entity
  # WARNING - This will be aborted if this element is a link in a chain.
  #
  # Input: action = 'move' or 'copy'
  #        object_domid = element ot be moved or copied.
  #        dest_domid = destionation location.
  # Output: "" if all OK
  #         error message if not OK. Calling code to handle the error.
  #----------------------------------------------------------------------------
  #------------------------ Single Element operation ----------------------
  def doSingleMoveCopy(action, object_domid, dest_domid)
    #parse source for details
    if((result = /^(([A-Z]+\d+l\d+)n(\d+))(s)(\d+)$/.match(object_domid)))
      student_id = result[5].to_i
      old_lesson_id = result[3].to_i
      old_slot_id = result[2]
      @domchange['object_type'] = result[4] == 's' ? 'student' : 'tutor'
      @domchange['from'] = result[1]
    elsif((result = /^(s)(\d+)/.match(object_domid)))  #index area
      student_id = result[2].to_i
      @domchange['object_type'] = result[1] == 's' ? 'student' : 'tutor'
      @domchange['action'] = 'copy'    # ONLY a copy allowed from index area.
    else
      logger.debug "neither index or schedule found!!! #{object_domid}"
      return "doSingleMoveCopy -- neither index or schedule found!!! #{object_domid}"
    end
    #parse destination for details
    if((result = /^(([A-Z]+\d+l\d+)n(\d+))/.match(dest_domid)))
      new_lesson_id = result[3].to_i
      new_slot_id = result[2]
    else
      logger.debug "doSingleMoveCopy -- invalid destination found!!!#{dest_domid.inspect}"
      return "doSingleMoveCopy -- invalid destination found!!! #{dest_domid.inspect}"
    end
    #refine destination details
    if( @domchange['action'] == 'move')
      @role = Role
                  .includes(:student)
                  .where(:student_id => student_id, :lesson_id => old_lesson_id)
                  .first
      @role.lesson_id = new_lesson_id
    elsif( @domchange['action'] == 'copy')    # copy
      @role = Role.new(:student_id => student_id, :lesson_id => new_lesson_id)
      # copy relevant info from old role (status & kind)
      if old_lesson_id
        @role_from = Role.where(:student_id  => student_id,
                                :lesson_id => old_lesson_id).first
        @role.status = @role_from.status
        @role.kind   = @role_from.kind
      end
    end
    @domchange['html_partial'] = render_to_string("calendar/_schedule_student.html",
                                    :formats => [:html], :layout => false,
                                    :locals => {:student => @role.student, 
                                                :thisrole => @role, 
                                                :slot => new_slot_id, 
                                                :lesson => new_lesson_id
                                               })
    # the object_id will now change (for both move and copy as the inbuild
    # lesson number will change.
    @domchange['object_id_old'] = @domchange['object_id']
    @domchange['object_id'] = new_slot_id + "n" + new_lesson_id.to_s.rjust(@sf, "0") +
                    "s" + student_id.to_s.rjust(@sf, "0")
    # want to hold the name for sorting purposes in the DOM display
    @domchange['name'] = @role.student.pname
    if @role.save
      # no issues
    else
      logger.debug "unprocessable entity(line 813): " + @role.errors.messages.inspect 
      return @role.errors.messages
    end
    ably_rest.channels.get('calendar').publish('json', @domchange)
    get_slot_stats(new_slot_id)
    if(old_slot_id && (new_slot_id != old_slot_id))
      get_slot_stats(old_slot_id)
    end
    # everything is completed successfully.
    #respond_to do |format|
    #  format.json { render json: @domchange, status: :ok }
    #end
    return ""
  end
  #---------------End of  Service Function = doSingleMoveCopy ----------------

  #******************************************************************
  #---------------- Service Function = doAllocation --------------------
  # This function will do the required moves when allocating students
  # from the stats page.
  #
  # Input: dom_id of the clicked on element - the one to be extended.
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
    extend_chain_blocks = lambda do |new_lesson_id|
      #this_error = get_role_chain_and_block(@role)
      #return this_error if this_error.length > 0
      this_error = ""
      @block_roles.push(@role)
      #----------------------- parent extension ----------------------------
      # Now need to find the parent chain
      # We find the existing parent for this role - and get the rest of the run.
      this_error = get_all_parent_lesson_chain_and_block(new_lesson_id)
      return this_error if this_error.length > 0
      # Now copy the roles hortzontally.
      # block_roles[0] is the existing entitiy
      # block_roles[1] is the first one to be created.
      # block_roles[block_roles.length - 1]  is the last one to be created &
      #                                      the last link in the chain.
      @allCopiedSlotsIds = Array.new    # track slots for updating stats
      thisroleid = @block_roles[0].id
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
          else
            @block_roles[i].status = i.odd? ? 'bye' : 'scheduled' 
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
    extend_chain_doms = lambda do
      # Build the @domchange(domchangerun for each element in the chain
      # Note: In this scenario, there is actually one element in this role chain
      #
      
      this_error = ""
      @domchangerun = Array.new
      @block_roles.each_with_index do |o, i|
        logger.debug "block_role (" + i.to_s + "): " + o.inspect
        @domchangerun[i] = Hash.new
        # @domchange['action'] for the element depends on if they are moved, added
        # or deleted.
        # move    is the normal mode for all preexisting elements.
        # remove  is for elements that have been deleted - handled in
        #         block_roles_remove processing 
        # copy    is for elements that have been added - detected by checking
        #         @blocksToAdd which is the number of added elements
        @domchangerun[i]['action']         = 'move'           # default.
        if @num_elements_added != nil && @num_elements_added > 0      # elements have been added         
          if @block_roles.count - @num_elements_added <= i     # detect added elements
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
        @domchangerun[i]['html_partial']    = 
          render_to_string("calendar/_schedule_student.html",
                          :formats => [:html], :layout => false,
                          :locals => {:student  => @role.student, 
                                      :thisrole => @domchangerun[i]['role'], 
                                      :slot     => @domchangerun[i]['new_slot_domid'],                     # new_slot_id, 
                                      :lesson   => o.id                               # new_lesson_id
                                     })
        @domchangerun[i]['object_id'] = @domchangerun[i]['to'] +
                                        's' + @role.student_id.to_s.rjust(@sf, "0")
      end
      # # sometimes, we need to rmove students on the display
      if @block_roles_remove != nil        # if deletions are required.
         @domchangeremove = Array.new      # build the version to manage display deletes
        (0..@block_roles_remove.length-1).each do |i|
          o = @block_roles_remove[i]                # shortend chain in db
          @domchangeremove[i] = Hash.new if @domchangeremove[i] == nil
          @domchangeremove[i]['action']    = 'remove'
          @domchangeremove[i]['object_id']  =        o.lesson.slot.location[0,3] +
                                                     o.lesson.slot.timeslot.strftime("%Y%m%d%H%M") +
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
      logger.debug "@domchange['object_id'] : " + @domchange['object_id'].inspect
      @domchange['object_id'] = @domchangerun[0]['object_id']
      #logger.debug "@domchange['object_id'] : " + @domchange['object_id'].inspect
      # Now remove keys not needed
      @domchangerun.delete('role')
      @domchangerun.delete('student')
      return this_error     # be empty if no errors
    end


    #---------- relink roles from old_lessons to new_lessons ----------------
    extend_chain_relinkrole = lambda do
      @block_roles.each_with_index do |o, i|
        @block_roles[i].lesson_id = @block_lessons[i].id
      end
      return ""
    end

    #------------------------- perform the db update ------------------------
    extend_chain_dbUpdates = lambda do
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
    
    
    extend_chain_screenUpdates = lambda do
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
      (0..@block_roles.length-1).each do |i|
        get_slot_stats(@domchangerun[i]['new_slot_domid'])
        if(@domchangerun[i]['new_slot_domid'] != @domchangerun[i]['old_slot_domid'])
          get_slot_stats(@domchangerun[i]['old_slot_domid'])
        end
      end
      # everything is completed successfully.
      return ""
    end
    #---------------------- end of lambda --------------------------------
    
    this_error = ""
    # Extract relevant details from source
    if(result = /^(([A-Z]+\d+l\d+)n(\d+))([st])(\d+)$/.match(object_domid))
      student_id = result[5].to_i
      old_lesson_id = result[3].to_i
      old_slot_id = result[2]
      @domchange['object_type'] = result[4] == 's' ? 'student':'tutor'
      @domchange['from'] = result[1]
    else
      return "passed clicked_domid parameter to moverun function is incorrect - #{clicked_domid.inspect}"
    end      
    # Extract relevant details from destination
    # Teh destination lesson (allocate) is determined and placed in @domchange['to']
    # before this function is called.
    if(result = /^(([A-Z]+\d+l\d+)n(\d+))/.match(@domchange['to']))  # destination
      new_lesson_id = result[3].to_i
      new_slot_id = result[2]
    else
      return "passed dest parameter to moverun function is incorrect - #{dest_domid.inspect}"
    end      
    #---- Do some initial checks on type of allocation ----
    # There are a number of restrictions: They can only come from
    # 1. global (first scheduling of a student)
    # 2. allocate (rescheduling already scheduled student) i.e. parent changed
    #             their minds.
    # There are a number of options based on kind of lesson/student
    # 1. catchup - only a single element is moved.
    # 2. other types - element is moved to chosen designation, then that element 
    #                  is extended into the rest of the term.
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
    # Keep a list of all the elements to be updated in the database
    @block_roles = Array.new
    @block_lessons = Array.new
    #  ** old_lesson_id  ** holds the old lesson_id => so can update @role.lesson_id
    # Get the element we want to move
    ### Role.where(first: @role.first).includes([:student, lesson: :slot])
    ### @role = Role.includes(:lesson).where(:student_id => student_id, :lesson_id => old_lesson_id).first
    @role = Role.includes([:student, lesson: :slot]).where(:student_id => student_id, :lesson_id => old_lesson_id).first
    @new_lesson = Lesson.includes(:slot).find(new_lesson_id)
    return "Allocation Error - Parent lesson is not a part of a chain" if @new_lesson.first == nil 
    if(@role.lesson.status == 'global')    # coming from global 
      logger.debug " in stats moving from global"
      if @role.first != nil                # error if not a single element (non a chain).
        return "Allocation Error - Global elements must not be chains!" 
      end                                  # Guaranteed single element at this point
      #@role.lesson_id = @new_lesson.id     # relink to new lesson
      if ['catchup'].include?(@role.kind)  # do the catchups first - remain single elements
        @block_roles.push(@role)           # and store for later update (as db transaction)
        @block_lessons.push(@new_lesson)   # the matching lesson
      else                                    # do the others, they become a chain after dropping into allocate
        @role.first = @role.id                # make into a chain
        @role.block = @role.id                # .next defaults to nil - terminates chain.
        this_error = extend_chain_blocks.call(@new_lesson.id) # Extend the chain to the end of term -> @block_roles 
        return this_error if this_error.length > 0
      end
      this_error = extend_chain_doms.call
      return this_error if this_error.length > 0
      @domchange['object_id_old'] = @domchangerun[0]['object_id_old']
      @domchange['object_id'] = @domchangerun[0]['object_id']
      @domchange['to'] = @domchangerun[0]['to']
      this_error = extend_chain_relinkrole.call
      return this_error if this_error.length > 0
      this_error = extend_chain_dbUpdates.call
      return this_error if this_error.length > 0
      this_error = extend_chain_screenUpdates.call
      return this_error if this_error.length > 0
    elsif(@role.lesson.status == 'allocate')
      logger.debug " in stats moving from allocate"
      if @role.first == nil                     # single element  
        logger.debug "dealing with a single element"
        @block_roles.push(@role)           # and store for later update (as db transaction)
        @block_lessons.push(@new_lesson)   # the matching lesson
        this_error = extend_chain_doms.call
        return this_error if this_error.length > 0
        @domchange['object_id_old'] = @domchangerun[0]['object_id_old']
        @domchange['object_id'] = @domchangerun[0]['object_id']
        @domchange['to'] = @domchangerun[0]['to']
        this_error = extend_chain_relinkrole.call
        return this_error if this_error.length > 0
        this_error = extend_chain_dbUpdates.call
        return this_error if this_error.length > 0
        this_error = extend_chain_screenUpdates.call
        return this_error if this_error.length > 0
      else                                  # Moving chain
        logger.debug "dealing with a chain"
        # This chain move is different as it can be moved into a different 
        # starting week of year
        # Step 1 - get the destination chain that matches the destination roles
        logger.debug "get_all_parent_lesson_chain_and_block"
        get_all_parent_lesson_chain_and_block(@new_lesson.id)
        #Step 2 - get the existing role chain requested to be moved.
        logger.debug "get_role_chain_and_block"
        get_role_chain_and_block(@role)
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
        logger.debug "extend_chain_doms"
        this_error = extend_chain_doms.call
        return this_error if this_error.length > 0
        @domchange['object_id_old'] = @domchangerun[0]['object_id_old']
        @domchange['object_id'] = @domchangerun[0]['object_id']
        @domchange['to'] = @domchangerun[0]['to']
        logger.debug "calling relinkrole"
        this_error = extend_chain_relinkrole.call
        return this_error if this_error.length > 0
        logger.debug "extend_chain_dbUpdates"
        this_error = extend_chain_dbUpdates.call
        return this_error if this_error.length > 0
        logger.debug "extend_chain_screenUpdates"
        this_error = extend_chain_screenUpdates.call
        return this_error if this_error.length > 0
      end
    end
    return ''
  end
    
  #------------------End of Service Function = doAllocation ---------------------

  #==================================================================
  # PATCH/PUT /studentmovecopylesson.json
  # this is the ** updated ** function to replace
  # studentmovelesson and studentcopylesson.
  def studentmovecopylesson
    @domchange = Hash.new
    params[:domchange].each do |k, v| 
      logger.debug "k: " + k.inspect + " => v: " + v.inspect 
      @domchange[k] = v
    end
    this_error = ""
    # from / source
    # need to check if is from index area or schedule area
    # identified by the id
    # id = t11111     ->  index
    # id = GUN2018... -> schedule
    if((result = /^(([A-Z]+\d+l\d+)n(\d+))s(\d+)$/.match(@domchange['object_id'])))
      student_id = result[4].to_i
      ###old_lesson_id = result[3].to_i
      ###old_slot_id = result[2]
      @domchange['object_type'] = 'student'
      @domchange['from'] = result[1]
    elsif((result = /^s(\d+)/.match(@domchange['object_id'])))  #index area
      student_id = result[1].to_i
      @domchange['object_type'] = 'student'
      @domchange['action'] = 'copy'    # ONLY a copy allowed from index area.
    else
      logger.debug "neither index or schedule found!!!"
      return
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
      # Nothing to do here - must ignore.
      #logger.debug "in extend run - no destination sought."
    elsif(@domchange.has_key?("to_slot"))
      #logger.debug "to_slot present in parameters"
      result = /^(([A-Z]+\d+l(\d+)))/.match(@domchange['to_slot'])
      if result 
        new_slot_dbId = result[3].to_i
        new_slot_id = result[2]
        # Need to find the 'allocate' lesson for this slot.
        @lesson_new = Lesson.where(:slot_id => new_slot_dbId, :status => "allocate" )
                            .first
        unless @lesson_new
          logger.debug "lesson not found"
          # need to create a new lesson with status 'allocatae'
          @lesson_new = Lesson.new(slot_id: new_slot_dbId, status: "allocate")
          @lesson_new.save
        end
        new_lesson_id = @lesson_new.id
        @domchange['to'] = new_slot_id + 'n' + @lesson_new.id.to_s
      end
      #new_parent_date = @domchange['to_slot'][3,11]
    else  # the normal to destination
      result = /^(([A-Z]+\d+l\d+)n(\d+))/.match(@domchange['to'])
      if result 
        new_lesson_id = result[3].to_i
        new_slot_id = result[2]
        @domchange['to'] = result[1]
      end
      #mm = /^[A-Za-z]+(\d\d\d\d)(\d\d)(\d\d)/.match(@domchange['to'])
      #new_parent_date = DateTime.new(mm[1].to_i, mm[2].to_i, mm[3].to_i);
    end
    #------------------------------------------------------------------------
    # Now handle the different types of moves or copies.
    #------------------------------------------------------------------------
    #---------------------------- start of extendrun ------------------------
    if( @domchange['action'] == 'extendrun')
      # offload extend run to it's own function
      # we must handle any errors here
      this_error = doExtendRun(@domchange['object_id'])
    #---------------------------- start of moverun --------------------------
    elsif( @domchange['action'] == 'moverun')
      this_error = doMoveRun(@domchange['object_id'], @domchange['to'])      # element dom_id to be moved, destination dom_id
    #------------------------ Stats Screen Allocation ----------------------
    elsif(@domchange.has_key?('allocation'))
      @domchange['object_id_old'] = @domchange['object_id']
      this_error = doAllocation(@domchange['object_id'], @domchange['to'])      # 
    #------------------------ Single Element operation ----------------------
    elsif(@domchange['action'] == 'move' ||
          @domchange['action'] == 'copy')
      this_error = doSingleMoveCopy(@domchange['action'],     # action - move or copy 
                                    @domchange['object_id'],  # source element
                                    @domchange['to'])         # destination element
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
    if @role.status_changed? && @role.status == 'away'
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
      get_slot_stats(slot_id)
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
    @copied_role.kind = 'catchup'
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