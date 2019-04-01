#app/controllers/concerns/ChainUtilities.rb
module ChainUtilities
  #---------------------- Support Function for doMoveRun ---------------------
  #--------------------------- doMoveBlock() ---------------------------------
  # input: makes use of object variables
  # @role
  # output: writes out object variables
  # return: if error -text string containing error descrition
  #         else - empty string.
  #
  def doMoveBlock(role, new_lesson_id, options)
    # build the chain for roles - contains all elements of the original chain - even when fragmented.
    # and the block chain that we propagate as the updated elements (roles)
    this_error = ""
    this_error = get_role_chain_and_block(role, options)
    return this_error if this_error.length > 0
    # In order to minimise db queries.
    # Reload @role so get the full connections to lessons, slots and students/tutors
    # This makes the first lookup for @role more succint.
    role = @role_chain_index_id[role.id]
    #--------------------------- new parent ---------------------------------
    # Now need to find the parent chain
    # Note that calling ...matching_parent... does additional checks that
    # bloc_role and block_lesson chains are in week by week step and same length.
    this_error = get_matching_parent_lesson_chain_and_block(role, new_lesson_id)
    return this_error if this_error.length > 0
    #------------------------ build the dom updates  (pre-update parts)-------------------------
    # Build the @domchange(domchangerun for each element in the block)
    @domchangerun = Array.new
    @block_roles.each_with_index do |o, i|
      #logger.debug "block_role (" + i.to_s + "): " + o.inspect
      @domchangerun[i] = Hash.new
      @domchangerun[i]['action']         = 'move'                 # moverun of individual elements. 
      @domchangerun[i]['object_type']    = @domchange['object_type']
      @domchangerun[i]['old_slot_domid'] = o.lesson.slot.location[0,3] +
                                           o.lesson.slot.timeslot.strftime("%Y%m%d%H%M") +
                                    'l' +  o.lesson.slot_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['from']           = @domchangerun[i]['old_slot_domid'] +
                                    'n' +  o.lesson_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['old_slot_id']   = o.lesson.slot_id
      @domchangerun[i]['role']          = o
      if o.is_a?(Role)
        @domchangerun[i]['student']       = o.student
        @domchangerun[i]['name']          = o.student.pname  # for sorting in the DOM display
        @domchangerun[i]['object_id_old'] = @domchangerun[i]['from'] +
                                    's' + o.student.id.to_s.rjust(@sf, "0")
      else
        @domchangerun[i]['tutor']       = o.tutor
        @domchangerun[i]['name']          = o.tutor.pname  # for sorting in the DOM display
        @domchangerun[i]['object_id_old'] = @domchangerun[i]['from'] +
                                    't' + o.tutor.id.to_s.rjust(@sf, "0")
      end
    end
    #-----------determine if chain is breaking or reconnecting ---------------
    # Additional chain links of interest
    # pre_block_role  is the link before the start of the block.
    #                 Of interest if the chaining to the front of the block
    #                    is being broken (this_role.first !=- self.id)
    #                 OR the front of the chain is being relinked (new parents
    #                   in the same chain).
    # post_block_role is the first link after the block.
    #                 Of interest if relinking to next fragment (new parents
    #                   in the same chain)
    #                 OR (special case when a sinle intermediate chain element
    #                    being moved) the chaining to the following fragment
    #                    is being broken.
    #@role_chain_index       = Hash.new        # indexes in chain
    #@role_chain_index_id    = Hash.new        # index by id provides the object
    #@role_chain_index_date  = Hash.new        # index by woy provides object
    #@role_breakchainlast    = nil             # provides object in chain prevous to the block
    #@block_roles            = Array.new       # provides chain segment (called block) of interest
    @pre_block_role = nil
    @post_block_role = nil
    @flag_pre_block_role_unlink = false
    @flag_pre_block_role_relink = false
    @flag_post_block_role_unlink = false
    @flag_post_block_role_relink = false
    # check if chain needs to be broken at start of block
    if @role_prevtoblock  # there is actually some preblock elements
      if @block_roles[0].id != @block_roles[0].first  # chain needs to be broken 
        @pre_block_role = @role_breakchainlast
        @flag_pre_block_role_unlink = true
      end
      # check if chain needs to be relinked at start of block
      if @block_roles[0].id == @block_roles[0].first  # is the first link in the block fragment
        # if destination parent lesson is in the same chain as the pre_block_role_lesson,
        # then a reconnection of the chain is required.
        if @role_prevtoblock.lesson.first == @block_lessons[0].first  # relinking required
          # chain will need to be relinked (lesson parent chain will be continuous)
          @pre_block_role = @role_prevtoblock
          @flag_pre_block_role_relink = true
        end
      end
    end
    # check if chain needs to be relinked at end of block
    if @role_postblock  # there is actually some postblock elements
      # Need to keep the post_block_role "first" value because
      # a bulk field update is done on the following segment which does
      # not update the model values. (need it to identify the fragment!)
      post_block_role_first_old_value = @role_postblock.first
      if @block_roles[@block_roles.length - 1].next == nil  # checking the last link in the block fragment
        # if destination parent lesson is in the same chain as the post_block_role_lesson,
        # then a reconnection of the chain is required.
        if @role_postblock.lesson.first == @block_lessons[@block_roles.length - 1].first  # relinking required
          # chain will need to be relinked (lesson parent chain will be continuous)
          @post_block_role = @role_postblock
          @flag_post_block_role_relink = true
        end
      end
    end
    # check if chain needs to be broken at end of block
    if @role_postblock  # there is actually some postblock elements
      if @role_postblock.id != @role_postblock.first  # chain needs to be broken 
        @post_block_role = @role_postblock
        @flag_post_block_role_unlink = true
      end
    end
    #--------------- update first & next ids  ---------------------------------
    # this needs to be done before the html partial is generated.
    # In terms of sequence:
    # 1. preblock must be done before the block as info (first) from this element is
    #    propagated through the block when relinking.
    # 2. postblock must be done after the block as info (first) from the first
    #    element in the block is used to populate each element in the 
    #    following (post) fragment.
    # Preblock processing
    if @flag_pre_block_role_unlink
      @pre_block_role.next = nil
    elsif @flag_pre_block_role_relink
      @pre_block_role.next = @block_roles[0].id
      @block_roles[0].first = @pre_block_role.first
    end
    # Block processing
    (0..@block_roles.length-1).each do |i|
      @block_roles[i].lesson_id = @block_lessons[i].id   # change to the database
      if @flag_pre_block_role_unlink  # new chain segment.
        @block_roles[i].first = role.id 
      elsif @flag_pre_block_role_relink  # rejoining role chain segment at start.
        @block_roles[i].first = @pre_block_role.first 
      end
      if @flag_post_block_role_relink # rejoining role chain segment at end.
        if i == @block_roles.length - 1    # last link in block
          @block_roles[i].next = @post_block_role.id  # make block extend into next segment
        end
      end
    end
    # Postblock processing
    if @post_block_role != nil   # chain linkage need adjusting so need to update db and screens to match
      if @flag_post_block_role_unlink || @flag_post_block_role_relink
        # get the list of ids of the post block chain fragment
        postfragmentids = Array.new
        chainindexstartpostfragment = @role_chain_index[@post_block_role.id]
        (chainindexstartpostfragment .. @role_chain.length - 1).each do |i|
          if @role_chain[i].first ==  post_block_role_first_old_value
            postfragmentids.push(@role_chain[i].id)
          else
            break    # only first continuous fragment.
          end
        end
      end
      if @flag_post_block_role_unlink
        @block_roles[@block_roles.length - 1].next = nil
        @post_block_role.first = @post_block_role.id  # required for dom updates
      elsif @flag_post_block_role_relink
        @block_roles[@block_roles.length - 1].next = @post_block_role.id
        @post_block_role.first = @block_roles[0].first    # required for dom undates
      end
    end
    #------------------------- perform the db update ------------------------
    # block_role now contains all the (block of) elements we need to move
    # Need to step through this chain.
    # Let role be the controlling chain - lesson being the secondary chain
    # transactional code.
    #return "Truncated operation due to testing!!!"
    begin
      Role.transaction do
        (0..@block_roles.length-1).each do |i|
          #@block_roles[i].update!(lesson_id: @block_lessons[i].id)   # change to the database
          @block_roles[i].save!                                      # change to the database
            # all saved safely, now need to update the browser display (using calendar messages)
            # the object_id will now change (for both move and copy as the inbuild
            # lesson number will change.
        end
        #if @role_breakchainlast # break the chain.
        #  @role_breakchainlast.update!(next: nil)
        #end
        @pre_block_role.save! if @pre_block_role != nil   # break link at end of last segment
        if @flag_post_block_role_relink
          if @block_roles[0].is_a?(Role)
            Role.where(id: postfragmentids).update_all(first: @block_roles[0].first)
          elsif @block_roles[0].is_a?(Tutrole)
            Tutrole.where(id: postfragmentids).update_all(first: @block_roles[0].first)
          end
        end
        if @flag_post_block_role_unlink
          #mybulkupdateroles = Role.where(id: myrolepostfragmentids)
          if @block_roles[0].is_a?(Role)
            Role.where(id: postfragmentids).update_all(first: @post_block_role.id)
          elsif @block_roles[0].is_a?(Tutrole)
            Tutrole.where(id: postfragmentids).update_all(first: @post_block_role.id)
          end
        end
      end
      rescue ActiveRecord::RecordInvalid => exception
        logger.debug "Transaction failed!!! - rollback exception: " + exception.inspect
        this_error = "Transaction failed!!! " + exception.inspect 
    end
    return this_error if this_error.length > 0
    #------------------------ build the dom updates  (post-update parts)-------------------------
    @block_lessons.each_with_index do |o, i|
      @domchangerun[i]['new_slot_domid']  = o.slot.location[0,3] +
                                            o.slot.timeslot.strftime("%Y%m%d%H%M") +
                                     'l' +  o.slot_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['to']              = @domchangerun[i]['new_slot_domid'] +
                                     'n' +  o.id.to_s.rjust(@sf, "0")
      @domchangerun[i]['new_slot_id']     = o.slot_id
      #@domchangerun[i]['lesson_id']      = o.lesson_id
      if @block_roles[0].is_a?(Role)
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
      else
        @domchangerun[i]['html_partial']    = 
            render_to_string("calendar/_schedule_tutor.html",
                            :formats => [:html], :layout => false,
                            :locals => {:tutor  => @domchangerun[i]['tutor'], 
                                        :thistutrole => @domchangerun[i]['role'], 
                                        :slot     => @domchangerun[i]['new_slot_domid'],                     # new_slot_id, 
                                        :lesson   => o.id                         # new_lesson_id
                                       })
          @domchangerun[i]['object_id'] = @domchangerun[i]['to'] +
                                              's' + @domchangerun[i]['tutor'].id.to_s.rjust(@sf, "0")
      end
      #logger.debug "domchangerun (" + i.to_s + "): " + @domchangerun[i].inspect
    end
    pre_post_dom_processing = lambda do |o|
      logger.debug "processing dom for pre \ post role:" + o.inspect
      domchangeprepostblock = Hash.new
      domchangeprepostblock['action']         = 'replace'                 # moverun of individual elements. 
      domchangeprepostblock['object_type']    = @domchange['object_type']
      object_type                          = domchangeprepostblock['object_type']
      slot_dom_id                          = o.lesson.slot.location[0,3] +
                                             o.lesson.slot.timeslot.strftime("%Y%m%d%H%M") +
                                      'l' +  o.lesson.slot_id.to_s.rjust(@sf, "0")
      lesson_dom_id                        = slot_dom_id +
                                      'n' +  o.lesson_id.to_s.rjust(@sf, "0")
      domchangeprepostblock['object_id']      = lesson_dom_id +
      (object_type=='student'?('s'+o.student_id.to_s.rjust(@sf,"0")):('t'+o.tutor_id.to_s.rjust(@sf,"0")))
      render_locals = {:slot     => slot_dom_id,
                       :lesson   => o.lesson_id }
      if object_type == 'student'
        render_locals[:student]     = o.student 
        render_locals[:thisrole]    = o
      else
        render_locals[:tutor]       = o.tutor
        render_locals[:thistutrole] = o
      end
      domchangeprepostblock['html_partial']   = 
        render_to_string("calendar/_schedule_" + object_type + ".html",
                        :formats => [:html], :layout => false,
                        :locals => render_locals)
      return domchangeprepostblock
    end
    # Manage the pre-block role
    #if @pre_block_role
    if @flag_pre_block_role_unlink  || @flag_pre_block_role_relink
      @domchangepreblock = pre_post_dom_processing.call(@pre_block_role)
    end
    # Manage the post-block role
    #if @post_block_role
    if @flag_post_block_role_unlink  || @flag_post_block_role_relink
      @domchangepostblock = pre_post_dom_processing.call(@post_block_role)
    end
    #----------------------- update screens  ---------------------------------
    # saved safely, now need to update the browser display (using calendar messages)
    # collect the set of screen updates and send through Ably as single message
    domchanges = Array.new
    (0..@block_roles.length-1).each do |i|
      domchanges.push(@domchangerun[i])
    end
    if @flag_pre_block_role_unlink  || @flag_pre_block_role_relink
      domchanges.push(@domchangepreblock)
    end
    if @flag_post_block_role_unlink  || @flag_post_block_role_relink
      domchanges.push(@domchangepostblock)
    end
    ably_rest.channels.get('calendar').publish('json', domchanges)
    # Now send out the updates to the stats screen
    # no change in stats for preblock
    # collect the set of stat updates and send through Ably as single message
    if @block_roles[0].is_a?(Role)
      statschanges = Array.new
      (0..@block_roles.length-1).each do |i|
        statschanges.push(get_slot_stats(@domchangerun[i]['new_slot_domid']))
        if(@domchangerun[i]['new_slot_domid'] != @domchangerun[i]['old_slot_domid'])
          statschanges.push(get_slot_stats(@domchangerun[i]['old_slot_domid']))
        end
      end
      #ActionCable.server.broadcast "stats_channel", { json: @statschange }
      ably_rest.channels.get('stats').publish('json', statschanges)
    end
    # everything is completed successfully - just need to let the caller know.
    return ""
  end    
  #-----------------End of Support Function for doMoveBlock -------------------

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
  def doMoveRun(object_domid, dest_domid, options)
    flagMoveRunSingle = false
    if options.has_key?('single') &&
      options['single']  == true
      flagMoveRunSingle = true
    end
    this_error = ""
    if(result = /^(([A-Z]+\d+l\d+)n(\d+))([st])(\d+)$/.match(object_domid))
      person_id = result[5].to_i
      #student_id = result[5].to_i
      old_lesson_id = result[3].to_i
      #old_slot_id = result[2]
      @domchange['object_type'] = result[4] == 's' ? 'student':'tutor'
      @domchange['from'] = result[1]
    else
      return "passed clicked_domid parameter to moverun function is incorrect - #{clicked_domid.inspect}"
    end      
    if(result = /^(([A-Z]+\d+l\d+)n(\d+))/.match(dest_domid))
      new_lesson_id = result[3].to_i
      #new_slot_id = result[2]
      @domchange['from'] = result[1]
    else
      return "passed destination parameter to moverun function is incorrect (not a lesson in the schedule area) - #{dest_domid.inspect}"
    end
    # need to produce the matching block chain for the roles
    # get the chain of existing roles - so that we can change the link to the parent
    # in each of these. Only the role records are updated.
    #--------------------------- role ---------------------------------
    #@role = Role.where(:student_id => student_id, :lesson_id => old_lesson_id).first
    if @domchange['object_type'] == 'student'
      @role = Role.includes(:lesson).where(:student_id => person_id, :lesson_id => old_lesson_id).first
    else    # tutor
      @role = Tutrole.includes(:lesson).where(:tutor_id => person_id, :lesson_id => old_lesson_id).first
    end
    this_error += doMoveBlock(@role, new_lesson_id, options)
    return this_error if this_error.length > 0
    return ""
  end
  #------------------End of Service Function = doMoveRun ---------------------


  #******************************************************************
  #--------------------- Service Function = doSingleMoveCopy -----------------
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
  def doSingleMoveCopy(action, object_domid, dest_domid, options)
    #parse source for details
    if((result = /^(([A-Z]+\d+l\d+)n(\d+))([st])(\d+)$/.match(object_domid)))
      #student_id = result[5].to_i
      person_id = result[5].to_i
      old_lesson_id = result[3].to_i
      old_slot_id = result[2]
      @domchange['object_type'] = result[4] == 's' ? 'student' : 'tutor'
      @domchange['from'] = result[1]
    elsif((result = /^([st])(\d+)/.match(object_domid)))  #index area
      #student_id = result[2].to_i
      person_id = result[2].to_i
      @domchange['object_type'] = result[1] == 's' ? 'student' : 'tutor'
      @domchange['action'] = 'copy'    # ONLY a copy allowed from index area.
    else
      logger.debug "neither index or schedule found!!! #{object_domid}"
      return "doSingleMoveCopy -- neither index or schedule found!!! #{object_domid}"
    end
    object_type = @domchange['object_type']
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
      if @domchange['object_type'] == 'student'
        @role = Role
                    .includes(:student)
                    .where(:student_id => person_id, :lesson_id => old_lesson_id)
                    .first
      else      # tutor
        @role = Tutrole
                    .includes(:tutor)
                    .where(:tutor_id => person_id, :lesson_id => old_lesson_id)
                    .first
      end
      # Can only do a single move if not a chain element
      if @role.first != nil
        return "Cannot perform a single move on a chain element"
      end
      @role.lesson_id = new_lesson_id
    elsif( @domchange['action'] == 'copy')    # copy
      if @domchange['object_type'] == 'student'
        @role = Role.new(:student_id => person_id, :lesson_id => new_lesson_id)
        # Can only do a single copy if not a chain element
        if @role.first != nil
          return "Cannot perform a single copy on a chain element"
        end
        # copy relevant info from old role (status & kind)
        if old_lesson_id
          @role_from = Role.where(:student_id  => person_id,
                                  :lesson_id => old_lesson_id).first
          @role.status = @role_from.status
          @role.kind   = @role_from.kind
        end
        # handle the move student to global
        if options.has_key? 'to_global'
          @role.kind = options['to_global']
          ###@role.status = 'scheduled'
          @role.status = 'queued'
        end
      else      # tutor
        @role = Tutrole.new(:tutor_id => person_id, :lesson_id => new_lesson_id)
        # Can only do a single copy if not a chain element
        if @role.first != nil
          return "Cannot perform a single copy on a chain element"
        end
        # copy relevant info from old role (status & kind)
        if old_lesson_id
          @role_from = Tutrole.where(:tutor_id  => person_id,
                                  :lesson_id => old_lesson_id).first
          @role.status = @role_from.status
          @role.kind   = @role_from.kind
        end
      end
    end
    render_locals = {:slot => new_slot_id, 
                     :lesson => new_lesson_id }
    if object_type == 'student'
      render_locals[:student] = @role.student 
      render_locals[:thisrole] = @role
    else
      render_locals[:tutor] = @role.tutor 
      render_locals[:thistutrole] = @role
    end
    @domchange['html_partial'] = render_to_string("calendar/_schedule_" + object_type + ".html",
                                   :formats => [:html], :layout => false,
                                   :locals => render_locals)
    # the object_id will now change (for both move and copy as the inbuild
    # lesson number will change.
    @domchange['object_id_old'] = @domchange['object_id']
    @domchange['object_id'] = new_slot_id + "n" + new_lesson_id.to_s.rjust(@sf, "0") +
                              (@domchange['object_type'] == 'student' ? "s" : "t") +
                              person_id.to_s.rjust(@sf, "0")
    # want to hold the name for sorting purposes in the DOM display
    @domchange['name'] = @domchange['object_type'] == 'student' ? @role.student.pname : @role.tutor.pname
    if @role.save
      # no issues
    else
      logger.debug "unprocessable entity(line 813): " + @role.errors.messages.inspect 
      return @role.errors.messages
    end
    ably_rest.channels.get('calendar').publish('json', @domchange)

    # collect the set of stat updates and send through Ably as single message
    if @role.is_a?(Role)
      statschanges = Array.new
      #get_slot_stats(new_slot_id)
      statschanges.push(get_slot_stats(new_slot_id))
      if(old_slot_id && (new_slot_id != old_slot_id))
        #get_slot_stats(old_slot_id)
        statschanges.push(get_slot_stats(old_slot_id))
      end
      ably_rest.channels.get('stats').publish('json', statschanges)
    end
    
    # everything is completed successfully.
    #respond_to do |format|
    #  format.json { render json: @domchange, status: :ok }
    #end
    return ""
  end
  #---------------End of  Service Function = doSingleMoveCopy ----------------





  #******************************************************************
  #---------------- Service Function = doLessonUpdateStatusRun --------------------
  # This function will update the status in a lesson chain from the clicked on 
  # element through to the rest of the term and into the week + 1.
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
  def doLessonUpdateStatusRun(object_domid)
    this_error = ""
    if(result = /^(([A-Z]+\d+l\d+)n(\d+))/.match(object_domid))
      lesson_id = result[3].to_i
      #@domchange['object_type'] = 'lesson'
    else
      return "passed clicked_domid parameter to doLessonUpdateStatusRun function is incorrect - #{clicked_domid.inspect}"
    end      
    # need to produce the matching block chain for the roles
    # get the chain of existing lessons (called 'roles' here)
    # in each of these. Only the role records are updated.
    #--------------------------- role ---------------------------------
    #@role = Role.where(:student_id => student_id, :lesson_id => old_lesson_id).first
    if @domchange['object_type'] == 'lesson'
      @lesson = Lesson.find(lesson_id)
    else    # tutor
      return "doLessonUpdateStatusRun can only process lessons!!!"
    end
    this_error += doUpdateStatusBlock(@lesson)
    return this_error if this_error.length > 0
    return ""
  end
  #------------------End of Service Function = doLessonUpdateStatusRun ---------------------

  #--------------------------- doUpdateStatusBlock() ---------------------------------
  # input: makes use of object variables
  # @role
  # output: writes out object variables
  # return: if error -text string containing error descrition
  #         else - empty string.
  #
  def doUpdateStatusBlock(role)
    # build the chain for roles - contains all elements of the original chain - even when fragmented.
    # and the block chain that we propagate as the updated elements (roles)
    this_error = ""
    this_error = get_role_chain_and_block(role, {})
    return this_error if this_error.length > 0
    # In order to minimise db queries.
    # Reload @role so get the full connections to lessons, slots and students/tutors
    # This makes the first lookup for @role more succint.
    role = @role_chain_index_id[role.id]
    #------------------------ build the dom updates  (pre-update parts)-------------------------
    # Build the @domchange(domchangerun for each element in the block)
    @domchangerun = Array.new
    @block_roles.each_with_index do |o, i|
      #logger.debug "block_role (" + i.to_s + "): " + o.inspect
      @domchangerun[i] = Hash.new
      @domchangerun[i]['action']         = 'set'                 # set status of individual elements. 
      @domchangerun[i]['updatefield']    = @domchange['updatefield']
      @domchangerun[i]['updatevalue']    = @domchange['updatevalue']
      
      @domchangerun[i]['object_type']    = @domchange['object_type']
      @domchangerun[i]['object_id']       = o.slot.location[0,3] +
                                           o.slot.timeslot.strftime("%Y%m%d%H%M") +
                                    'l' +  o.slot_id.to_s.rjust(@sf, "0") +
                                    'n' +  o.id.to_s.rjust(@sf, "0")
    end
    #--------------- update the lesson status  ---------------------------------
    # Block processing
    (0..@block_roles.length-1).each do |i|
      @block_roles[i].status = @domchange['updatevalue']   # change to the database
    end
    #------------------------- perform the db update ------------------------
    # block_role now contains all the (block of) elements we need to move
    # Need to step through this chain.
    # Let role be the controlling chain - lesson being the secondary chain
    # transactional code.
    #return "Truncated operation due to testing!!!"
    begin
      Role.transaction do
        (0..@block_roles.length-1).each do |i|
          @block_roles[i].save!                                      # change to the database
            # all saved safely, now need to update the browser display (using calendar messages)
        end
      end
      rescue ActiveRecord::RecordInvalid => exception
        logger.debug "Transaction failed!!! - rollback exception: " + exception.inspect
        this_error = "Transaction failed!!! " + exception.inspect 
    end
    return this_error if this_error.length > 0
    #----------------------- update screens  ---------------------------------
    # saved safely, now need to update the browser display (using calendar messages)
    # collect the set of screen updates and send through Ably as single message
    domchanges = Array.new
    (0..@block_roles.length-1).each do |i|
      domchanges.push(@domchangerun[i])
    end
    ably_rest.channels.get('calendar').publish('json', domchanges)
    # Now send out the updates to the stats screen
    # no change in stats for preblock
    # collect the set of stat updates and send through Ably as single message
    if @block_roles[0].is_a?(Role)
      statschanges = Array.new
      (0..@block_roles.length-1).each do |i|
        statschanges.push(get_slot_stats(@domchangerun[i]['new_slot_domid']))
        if(@domchangerun[i]['new_slot_domid'] != @domchangerun[i]['old_slot_domid'])
          statschanges.push(get_slot_stats(@domchangerun[i]['old_slot_domid']))
        end
      end
      #ActionCable.server.broadcast "stats_channel", { json: @statschange }
      ably_rest.channels.get('stats').publish('json', statschanges)
    end
    # everything is completed successfully - just need to let the caller know.
    return ""
  end    
  #-----------------End of  doUpdateStatusBlock() -----------------------------


  #******************************************************************
  #----------------- Helper Function = get_role_and_block_chain ---------------
  # @role_chain  contains all the elemets for this chain - even if they have
  #              been broken into fragments
  # @block_chain contains all the elements in this fragment of the chain - if
  #              no fragmented, then contains th whole chain.
  def get_role_chain_and_block(role, options)
    # detect if requested a 'run move single element'
    flagSingle = false
    if options.has_key?('single') && options['single'] == true
      flagSingle = true
    end
    flagAll = false
    if options.has_key?('all') && options['all'] == true
      flagAll = true
    end
    # build the chain for roles.
    if role.first == nil     # not a chain
      return "attemping a chain operatioin on an element that is not a chain"
    end
    this_error = ""
    if role.is_a?(Tutrole)
      @role_chain = Tutrole.includes(:tutor, lesson: :slot)
                        .where(block: role.block).where.not(first: nil)
                        .order("slots.timeslot")
    elsif role.is_a?(Role)
      #@role_chain = Role.where(first: role.first).includes([:student, lesson: :slot])
      @role_chain = Role.includes(:student, lesson: :slot)
                        .where(block: role.block).where.not(first: nil)
                        .order("slots.timeslot")
    elsif role.is_a?(Lesson)
      @role_chain = Lesson.includes(:slot, roles: :student, tutroles: :tutor)
                        .where(first: role.first)
                        .order("slots.timeslot")
    end
    # At this point, the chain contains all possible chain segments and each
    # entery in the chain is order by the slot timeslot - correct sequence order
    # for any processing.
    # For lessons, this will be a single chain with no fragments.
    #
    # Do a check on chain integity and buld an index
    # integity check - each element should point to the next one
    #                  unless it is a segment terminted by next = nil
    flagChainIssue          = false
    flagCollectBlock        = false
    @role_chain_index       = Hash.new        # indexes in chain
    @role_chain_index_id    = Hash.new        # index by id provides the object
    @role_chain_index_date  = Hash.new        # index by woy provides object
    @role_breakchainlast    = nil             # provides object in chain prevous to the block
    @role_prevtoblock       = nil             # ditto
    @role_postblock         = nil             # provides first role following block
    @block_roles            = Array.new       # provides chain segment (called block) of interest
    @role_chain.each_with_index do |o, i|
      @role_chain_index[o.id] = i
      @role_chain_index_id[o.id] = o
      if o.is_a?(Lesson)
        @role_chain_index_date[o.slot.timeslot.to_datetime.cweek] = o
      else
        @role_chain_index_date[o.lesson.slot.timeslot.to_datetime.cweek] = o
      end
      if i == @role_chain.length - 1   # last link in chain
        if o.next != nil    # corrrupted - should be terminated with next = nil
            flagChainIssue = true
            this_error += role.is_a?(Tutrole) ? 'Tutrole' : 'Role' + 
                          " chain issue id: #{o.id} with last linkage. "
        end
      elsif i < @role_chain.length - 1 # normal chain links (should have next set or nil)
        if flagAll    # need to collect rest of chain (e.g. run delete)
          # OK - once started collecting, just keep collecting
        elsif o.next == nil      # ending a chain segment
          if @role_chain[i+1].first == o.first  # broken linkage - should continue segment
            flagChainIssue = true
            this_error += role.is_a?(Tutrole) ? 'Tutrole' : 'Role' + 
                          " chain issue id: #{o.id} with linkage broken within fragment. "
          else
            # all OK
          end
        else   # continueing a chain fragment
          if o.next == @role_chain[i+1].id     # linkage is good
            # OK
          else    # linkage incorrect
              flagChainIssue = true
              this_error += role.is_a?(Tutrole) ? 'Tutrole' : 'Role' + 
                            " chain issue id: #{o.id} with linkages. "
          end
        end
      end
      unless flagChainIssue
        @role_breakchainlast = o if o.next == role.id
        # Need something better to get prevous link to the block
        if i < @role_chain.length - 1   # not last link in chain
          if @role_chain[i+1].id == role.id  # next link starts the block
            @role_prevtoblock = o
          end
          # as the fragment is set when making the call, then the .next == nil
          # is valid for finding the end of the current block.
          # After manipulation this may change as we may relink.
          if @role_chain[i].next == nil  &&  # last link in the chain fragment
             o.first == role.first          # in the block segment
            @role_postblock = @role_chain[i+1]
          end
        end
        flagCollectBlock = true if o.id == role.id
        if i < @role_chain.length - 1 && # something post block to break from
           flagCollectBlock &&           # collecting
           flagSingle                    # and only collecting one element
          @role_postblock = @role_chain[i+1]
        end
        if flagAll      # need to collect rest of chain (e.g. run delete)
          # OK - just keep collecting - don't let it stop collecting
        elsif flagCollectBlock == true &&      # have been collecting the block
           o.first != role.first           # but now just past the block
          flagCollectBlock = false          # stop collecting the block          
        end
        if flagCollectBlock == true         # have been collecting the block
          @block_roles.push(o)
          if flagSingle                     # When 'run move single element' requested
            flagCollectBlock = false                            # limit to one element in block_roles
          end
        end
      end
    end
    if this_error.length > 0
      return this_error 
    end
    # chain (all segments) is in good shape
    return ""
  end
  #------------ End of Helper Function = get_role_and_block_chain -------------

  #******************************************************************
  #---------- Helper Function = get_all_parent_lesson_chain_and_block ----------
  # Beginning at the passed lesson, gets all remaining links in chain.
  #
  # modified version of get_matching_parent_lesson_chain_and_block
  # only difference is that ALL the parent block chain from the matching
  # starting role is returned AS OPPOSED to just the matching portion.
  # return: nothing is returned if all successful
  #         error message returned if issue.
  def get_all_parent_lesson_chain_and_block(role, new_lesson_id)
    # role is used to determine the type of parent & that is all
    # new_lesson_id is the id of the clicked on parent element.
    this_error = ""
    if role.is_a?(Lesson) 
      new_lesson = Slot.find(new_lesson_id)   # actually a slot
      @new_lesson_chain = Slot
                          .where(first: new_lesson.first)
                          .order("timeslot")
    else
      new_lesson = Lesson.includes(:slot).find(new_lesson_id)
      @new_lesson_chain = Lesson.includes(:slot)
                          .where(first: new_lesson.first)
                          .order("slots.timeslot")
    end
    if new_lesson.first == nil
      return "attempting chain operation with a parent that is not a chain."
    end
    # Do a check on chain integity and buld an index
    # integity check - each element should point to the next one
    #                  unless it is a segment terminted by next = nil
    flagChainIssue          = false
    flagCollectBlock        = false
    @new_lesson_chain_index       = Hash.new  # indexes in chain
    @new_lesson_chain_index_id    = Hash.new  # index by id provides the object
    @new_lesson_chain_index_date  = Hash.new  # index by woy provides object
    @new_lesson_breakchainlast    = nil       # provides object in chain prevous to the block
    @block_lessons            = Array.new     # provides chain segment (called block) of interest
    @new_lesson_chain.each_with_index do |o, i|
      @new_lesson_chain_index[o.id] = i
      @new_lesson_chain_index_id[o.id] = o
      if role.is_a?(Lesson)
        @new_lesson_chain_index_date[o.timeslot.to_datetime.cweek] = o
      else
        @new_lesson_chain_index_date[o.slot.timeslot.to_datetime.cweek] = o
      end
      if i == @new_lesson_chain.length - 1   # last link in chain
        if o.next != nil    # corrrupted - should be terminated with next = nil
            flagChainIssue = true
            this_error += " Lesson chain issue id: #{o.id} with last linkage. "
        end
      elsif i < @new_lesson_chain.length - 1 # normal chain links (should have next set or nil)
        if o.next == nil      # ending a chain segment
          if @new_lesson_chain[i+1].first = o.first  # broken linkage - should continue segment
            flagChainIssue = true
            this_error += "Lesson chain issue id: #{o.id} with linkage broken within fragment. "
          else
            # all OK
          end
        else   # continueing a chain fragment
          if o.next == @new_lesson_chain[i+1].id     # linkage is good
            # OK
          else    # linkage incorrect
              flagChainIssue = true
              this_error += " Lesson chain issue id: #{o.id} with linkages. "
          end
        end
      end
      unless flagChainIssue
        @new_lesson_breakchainlast = o if o.next == new_lesson.id
        # manipulated chain portion is from click on element to the end of chain segment.
        flagCollectBlock = true if o.id == new_lesson.id
        @block_lessons.push(o) if flagCollectBlock == true &&
                                o.first == new_lesson.first
      end
    end
    return this_error if this_error.length > 0 
    # chain (all segments) is in good shape
    return ""
  end
  #------- End of Helper Function = get_parent_lesson_chain_and_block ---------


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
  def get_matching_parent_lesson_chain_and_block(role, new_lesson_id)
    get_all_parent_lesson_chain_and_block(role, new_lesson_id)
    # For ...matching_parent.... we need the blocks to have equal length
    # The ...all_parent... version brings back all the lessons beginning at 
    # the provided lesson.
    # For matching, we need to truncate this so the chains are the same length.
    # Then the checks ensure the chains are in step.
    if @block_lessons.length >  @block_roles.length     # must be same length
      @block_lessons.pop(@block_lessons.length - @block_roles.length)
    end
    # Now to check if role and lesson block chains match.
    # these checks are the difference between the 
    # all_parent... and matching_parent... calls.
    if @block_lessons.length !=  @block_roles.length     # must be same length
      if @block_lessons.length < @block_roles.length
        return "moverun error: role chain is longer than the (parent) lesson chain"
      else
        return "moverun error: role chain is shorter than the (parent) lesson chain"
      end
      return " get_all_parent_lesson_chain_and_block error: role and lessons" +
             " lengths not matchin."
    end
    #check that roles and lessons are in step - check week of year (woy) for each.
    (0..@block_lessons.length-1).each do |i|
      woy_role   = @block_roles[i].lesson.slot.timeslot.to_datetime.cweek
      woy_lesson =      @block_lessons[i].slot.timeslot.to_datetime.cweek
      if woy_role != woy_lesson   # out of step
        return " get_all_parent_lesson_chain_and_block error: role and" + 
               " lessons week of year not matching - each link not in the same week."
      end
      if i < @block_lessons.length-1   # not in last link of block
        if @block_lessons[i].next == nil
          return " get_all_parent_lesson_chain_and_block error: lesson block" +
                 " has premature termination of chain segment."
        end
        if @block_roles[i].next == nil
          return " get_all_parent_lesson_chain_and_block error: role block" +
                 " has premature termination of chain segment."
        end
      end
    end
    # now get the maatching lesson_breakchainlast to match the role
    #@role_breakchainlast_lesson = @new_lesson_chain_index_id[@role_breakchainlast.lesson_id]
    return ""     # no errors
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
    if(result = /^(([A-Z]+\d+l\d+)n(\d+))([st])(\d+)$/.match(clicked_domid))
      person_id = result[5].to_i
      person_type = result[4] == 's' ? 'student' : 'tutor'
      old_lesson_id = result[3].to_i
      #old_slot_id = result[2]
      @domchange['object_type'] = result[4] == 's' ? 'student' : 'tutor'
      @domchange['from'] = result[1]
    else
      return "passed parameter to extend run function is incorrect (student or tutor in the calendar area) - #{clicked_domid.inspect}"
    end      
    #--------------------------- role ---------------------------------
    # This could be a student or tutor being processed.
    # Thus db query could be on tutrole or role table.
    # .includes([:student , lesson: :slot])
    if person_type == 'student'
      @role = Role.includes(:lesson).where(:student_id => person_id, :lesson_id => old_lesson_id).first
    else              # tutor
      @role = Tutrole.includes(:lesson).where(:tutor_id => person_id, :lesson_id => old_lesson_id).first
    end
    #@role = @role = Role.where(:student_id => student_id, :lesson_id => old_lesson_id).first
    # build the chain for roles - contains all elements of the original chain - even when fragmented.
    # and the block chain that we propagate as the updated elements (roles)
    #
    # First check if the parent lesson is a chain - any chain must have a parent chain.
    if @role.lesson.first == nil   # parent lesson not a chain
      this_error = "Cannot exten the chain as the parent is not a chain"
      return this_error
    end
    # First check if this role is part of a chain. Make a chain if not.
    if @role.block == nil
      @role.block = @role.id
      @role.first = @role.id
      @role.next = nil
      @role.save         # write to database.
    end
    this_error = get_role_chain_and_block(@role, {})
    return this_error if this_error.length > 0
    if @block_roles.length > 1
      this_error += " Can only extend from last link in chain (not midway)"
      return this_error
    end
    #------------------------- parent extension -------------------------------
    # Now need to find the parent chain
    # We find the existing parent for this role - and get the rest of the run.
    this_error = get_all_parent_lesson_chain_and_block(@role, @role.lesson_id)
    return this_error if this_error.length > 0
    if @block_lessons.length == 1
      this_error += " Already at end of parent chain - nothing to extend"
      return this_error
    end
    #------------------ copy roles hortzontially -----------------------------
    # Now copy the roles hortzontally.
    # block_roles[0] is the existing entitiy
    # block_roles[1] is the first one to be created.
    # block_roles[block_lessons.length - 1]  is the last one to be created &
    #                                      the last link in the chain.
    @allCopiedSlotsIds = Array.new    # track slots for updating stats
    # Now need to copy this to the following mycopynumweeks weeks.
    # we are forming a chain with first = first id in chain &
    # next = the following id in the chain.
    (1..@block_lessons.length - 1).each do |i|
      parentLessonId = @block_lessons[i].id
      # Need to check if there is already a role with the same week of year
      # as this parent lesson.
      woy_lesson = @block_lessons[i].slot.timeslot.to_datetime.cweek
      if @role_chain_index_date.has_key?(woy_lesson)
        # we already have a role in this week - not valid.
        #byebug
        this_error = "error extendrun -  already an entry for this role in " +
                     "this week (week #{woy_lesson} in parent lesson ) " +
                     @block_lessons[i].slot.timeslot.to_datetime.to_s + " " +
                     @block_lessons[i].slot.location
        break
      end
      # build the new entries
      if @role.is_a?(Role)
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
      elsif @role.is_a?(Tutrole)
        @block_roles[i] = Tutrole.new(lesson_id: parentLessonId,
                                        tutor_id: @role.tutor.id, 
                                        status: 'scheduled',
                                        kind: @role.kind,
                                        first: @role.first,
                                        block: @role.block)
      end
      @allCopiedSlotsIds.push @block_lessons[i].slot.id    # track all copied slots
      logger.debug "@block_roles ( " + i.to_s + "): " + @block_roles[i].inspect
    end
    # Deal with errors found & terminate
    return this_error if this_error.length > 0
    #------------------------- perform the db update ------------------------
    # block_role now contains all the (block of) elements we need to move
    # Need to step through this chain.
    # Let role be the controlling chain - lesson being the secondary chain
    # transactional code.
    begin
      Role.transaction do
        (0..@block_roles.length-1).reverse_each do |i|
          # linkage update
          # end of chain link defaults to next = nil
          @block_roles[i].next = @block_roles[i+1].id unless i == @block_roles.length-1
          @block_roles[i].save!                 # change to the database
        end
      end
      rescue ActiveRecord::RecordInvalid => exception
        logger.debug "rollback exception: " + exception.inspect
        this_error = "Transaction failed!!!"+ exception.inspect
    end
    return this_error if this_error.length > 0
    #--------------------------- build the DOMs ----------------------------
    # Build the @domchange(domchangerun for each element in the chain
    @domchangerun = Array.new
    @block_roles.each_with_index do |o, i|
      logger.debug "block_role (" + i.to_s + "): " + o.inspect
      @domchangerun[i] = Hash.new
      @domchangerun[i]['action']         = 'copy'                 # extendrun of individual elements. 
      @domchangerun[i]['action']         = 'replace' if i == 0    # update first / existing element. 
      @domchangerun[i]['object_type']    = @domchange['object_type']
      @domchangerun[i]['old_slot_domid'] = o.lesson.slot.location[0,3] +
                                           o.lesson.slot.timeslot.strftime("%Y%m%d%H%M") +
                                    'l' +  o.lesson.slot_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['from']           = @domchangerun[i]['old_slot_domid'] +
                                    'n' +  o.lesson_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['old_slot_id']   = o.lesson.slot_id
      @domchangerun[i]['role']          = o
      @domchangerun[i]['student']       = o.student     if person_type == 'student'
      @domchangerun[i]['tutor']         = o.tutor       if person_type == 'tutor'
      @domchangerun[i]['name']          = person_type == 'student' ? o.student.pname  : o.tutor.pname # for sorting in the DOM display
      @domchangerun[i]['object_id_old'] = @domchangerun[i]['from'] +
                                    's' + o.student.id.to_s.rjust(@sf, "0") if person_type == 'student'
      @domchangerun[i]['object_id_old'] = @domchangerun[i]['from'] +
                                    't' + o.tutor.id.to_s.rjust(@sf, "0")   if person_type == 'tutor'
    end
    # do the dom updates including rendering
    # do this after the db updates so all info is correct for rendering
    @block_lessons.each_with_index do |o, i|
      @domchangerun[i]['new_slot_domid']  = o.slot.location[0,3] +
                                            o.slot.timeslot.strftime("%Y%m%d%H%M") +
                                     'l' +  o.slot_id.to_s.rjust(@sf, "0")
      @domchangerun[i]['to']              = @domchangerun[i]['new_slot_domid'] +
                                     'n' +  o.id.to_s.rjust(@sf, "0")
      if @role.is_a?(Role)
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
      elsif @role.is_a?(Tutrole)
        @domchangerun[i]['html_partial']    = 
          render_to_string("calendar/_schedule_tutor.html",
                          :formats => [:html], :layout => false,
                          :locals => {:tutor  => @role.tutor, 
                                      :thistutrole => @domchangerun[i]['role'], 
                                      :slot     => @domchangerun[i]['new_slot_domid'],                     # new_slot_id, 
                                      :lesson   => o.id                               # new_lesson_id
                                     })
        @domchangerun[i]['object_id'] = @domchangerun[i]['to'] +
                                        't' + @role.tutor_id.to_s.rjust(@sf, "0")
      end
    end
    # saved safely, now need to update the browser display (using calendar messages)
    # collect the set of screen updates and send through Ably as single message
    domchanges = Array.new
    (0..@block_roles.length-1).each do |i|
      domchanges.push(@domchangerun[i])
    end
    ably_rest.channels.get('calendar').publish('json', domchanges)
    ### ably_rest.channels.get('calendar').publish('json', @domchangepreblock) if @pre_block_role != nil
    # Now send out the updates to the stats screen
    # no change in stats for preblock
    # collect the set of stat updates and send through Ably as single message
    if @role.is_a?(Role)   # No stats update for tutors
      statschanges = Array.new
      (1..@block_roles.length-1).each do |i|
        statschanges.push(get_slot_stats(@domchangerun[i]['new_slot_domid']))
        #get_slot_stats(@domchangerun[i]['new_slot_domid'])
      end
      ably_rest.channels.get('stats').publish('json', statschanges)
    end
    # everything is completed successfully.
    return ""
  end
  #-----------------End of Service Function = doExtendRun ---------------------


  #***************************************************************************
  #------------------ Service Function = toSingleChainLesson -----------------
  # This function will convert a lesson to a single element chain
  # This became necessary as some work practices required a chained student to 
  # be moved into a chained lesson that is flexible - these are often not chained.
  #
  # Input: dom_id of the clicked on element - the one to be extended.
  # Output: "" if all OK
  #         error message if not OK. Calling code to handle the error.
  #---------------------------------------------------------------------------
  def toSingleChainLesson      # element to be extended
    clicked_domid = @domchange['object_id']
    this_error = ""
    if(result = /^(([A-Z]+\d+l\d+)n(\d+))$/.match(clicked_domid))
      old_lesson_id = result[3].to_i
      slot_id_basepart = result[2]
      @domchange['object_type'] = 'lesson'
      @domchange['from'] = result[1]
    else
      this_error = "passed parameter to extend run function isincorrect - #{clicked_domid.inspect}"
      respond_to do |format|
        format.json { render json: this_error, status: :unprocessable_entity }
      end
    end
    #--------------------------- role ---------------------------------
    # This is converting a lesson to a chain.
    #@lesson = Lesson.includes(:slot).where(id: old_lesson_id).first
    @lesson = Lesson.includes(:slot, roles: :student, tutroles: :tutor)
                    .where(id: old_lesson_id).first
    # build the chain for lessons.
    # and the block chain that we propagate as the updated elements (roles)
    #
    # First check if the parent is a chain element
    if @lesson.slot.first == nil
      return "Cannot turn lesson into chain when parent slot is not a chain."
    end
    # First check if this role is part of a chain. Make a chain if not.
    if @lesson.first == nil
      @lesson.first = @lesson.id
      @lesson.next = nil
      respond_to do |format|
        if @lesson.save         # write to database.
          #@domchange['object_id'] = slot_id_basepart + 'n' + @lesson.id.to_s.rjust(@sf, "0")
          
          @domchange['html_partial'] = render_to_string("calendar/_schedule_lesson_ajax.html", 
                                      :formats => [:html], :layout => false,
                                      :locals => {:slot => slot_id_basepart,
                                                  :lesson => @lesson,
                                                  :thistutroles => @lesson.tutroles,
                                                  :thisroles => @lesson.roles
                                                 })
          @domchange['action'] = 'replace'    # in dom, this is replacing an existing element.
          format.json { render json: @domchange, status: :ok }
          #ActionCable.server.broadcast "calendar_channel", { json: @domchange }
          ably_rest.channels.get('calendar').publish('json', @domchange)
        else
          format.json { render json: @lesson.errors, status: :unprocessable_entity }
        end
      end
    end
  end

  #******************************************************************
  #--------------------- Service Function = doExtendLessonRun -----------------------
  # This function will extend a lesson chain from the clicked on element through
  # to the rest of the term and into the week + 1.
  # The chain goes all the way through to week + 1 inclusive
  # Week +1 is identified by a field (wpo = week plus one) in the slot.
  #
  # Input: dom_id of the clicked on element - the one to be extended.
  # Output: "" if all OK
  #         error message if not OK. Calling code to handle the error.
  #---------------------------------------------------------------------------
  def doExtendLessonRun(clicked_domid)      # element to be extended
    if(result = /^(([A-Z]+\d+l\d+)n(\d+))$/.match(clicked_domid))
      old_lesson_id = result[3].to_i
      @domchange['object_type'] = 'lesson'
      @domchange['from'] = result[1]
    else
      return "passed parameter to extend run function isincorrect - #{clicked_domid.inspect}"
    end
    #--------------------------- role ---------------------------------
    # This is extending a lesson.
    # @lesson = Lesson.includes(:slot).where(id: old_lesson_id).first
    @lesson = Lesson.includes(:slot, roles: :student, tutroles: :tutor)
                    .where(id: old_lesson_id).first
    # build the chain for lessons.
    # and the block chain that we propagate as the updated elements (roles)
    #
    # First check to see if the parent is a chain element
    # Note that slots should always be chains!!
    if @lesson.slot.first == nil
      return "Cannot perform chain operation on element whose parent slot is not a chain"
    end
    # First check if this role is part of a chain. Make a chain if not.
    if @lesson.first == nil
      @lesson.first = @lesson.id
      @lesson.next = nil
      @lesson.save         # write to database.
    end
    # Note: TRANSPOSITION OF NAMES.
    # Using libraries common to the tutors and students chaining
    # As such, naming is confusing - so 
    # @block_roles   are lessons
    # @block_lessons are slots
    # and associated matching global variables.
    this_error = get_role_chain_and_block(@lesson, {})
    return this_error if this_error.length > 0
    if @block_roles.length > 1
      this_error += " Can only extend from last link in chain (not midway)"
      return this_error
    end
    #--------------------------- parent extension ---------------------------------
    # Now need to find the parent chain
    # We find the existing parent for this role - and get the rest of the run.
    this_error = get_all_parent_lesson_chain_and_block(@lesson, @lesson.slot_id)
    return this_error if this_error.length > 0
    if @block_lessons.length == 1
      this_error += " Already at end of parent chain - nothing to extend"
      return this_error
    end
    # Now copy the roles hortzontally.
    # block_roles[0] is the existing entitiy
    # block_roles[1] is the first one to be created.
    # block_roles[block_lessons.length - 1]  is the last one to be created &
    #                                      the last link in the chain.
    @allCopiedSlotsIds = Array.new    # track slots for updating stats
    # Now need to copy this to the following mycopynumweeks weeks.
    # we are forming a chain with first = first id in chain &
    # next = the following id in the chain.
    (1..@block_lessons.length - 1).each do |i|
      parentLessonId = @block_lessons[i].id  # actually slots
      # Need to check if there is already a slot with the same week of year
      # as this parent lesson.
      woy_lesson = @block_lessons[i].timeslot.to_datetime.cweek
      if @role_chain_index_date.has_key?(woy_lesson)
        # we already have a lesson in this week - not valid.
        this_error = "error extendLessonrun -  for this chain, we already an entry for this lesson in this week (week #{woy_lesson})"
        break
      end
      # build the new lesson entries
      @block_roles[i] = Lesson.new( slot_id: @block_lessons[i].id, 
                                    status: @block_roles[0].status,
                                    first: @block_roles[0].first)
      @allCopiedSlotsIds.push @block_lessons[i].id    # track all copied slots
      logger.debug "@block_roles ( " + i.to_s + "): " + @block_roles[i].inspect
    end
    # Deal with errors found & terminate
    return this_error if this_error.length > 0
    #------------------------- perform the db update ------------------------
    # block_role now contains all the (block of) elements we need to move
    # Need to step through this chain.
    # Let role be the controlling chain - lesson being the secondary chain
    # transactional code.
    begin
      Role.transaction do
        (0..@block_roles.length-1).reverse_each do |i|
          # linkage update
          # end of chain link defaults to next = nil
          @block_roles[i].next = @block_roles[i+1].id unless i == @block_roles.length-1
          @block_roles[i].save!                 # change to the database
        end
      end
      rescue ActiveRecord::RecordInvalid => exception
        logger.debug "rollback exception: " + exception.inspect
        this_error = "Transaction failed!!!"+ exception.inspect
    end
    return this_error if this_error.length > 0
    #--------------------------- build the DOMs ----------------------------
    # Build the @domchange(domchangerun for each element in the chain
    # All need to be done as chaining indicators need to be updated 
    @domchangerun = Array.new
    #@block_roles.each_with_index do |o, i|
    (0..@block_roles.length-1).each do |i|
      o = @block_roles[i]
      logger.debug "block_role (" + i.to_s + "): " + o.inspect
      @domchangerun[i] = Hash.new
      @domchangerun[i]['action'] = 'addLesson'           # extendrun of individual elements except 
      @domchangerun[i]['action'] = 'replace' if i == 0   # for first element, replace existing dom lesson 
      @domchangerun[i]['object_type'] = 'lesson'
      @domchangerun[i]['to'] = o.slot.location[0,3] +
                                           o.slot.timeslot.strftime("%Y%m%d%H%M") +
                                    'l' +  o.slot_id.to_s.rjust(@sf, "0")
      #@domchangerun[i]['old_slot_id']   = o.slot_id
      @domchangerun[i]['object_id'] = @domchangerun[i]['to'] +
                                'n' + o.id.to_s.rjust(@sf, "0")
      thistutroles = i == 0 ? o.tutroles : []
      thisroles    = i == 0 ? o.roles    : []
      @domchangerun[i]['html_partial'] = render_to_string("calendar/_schedule_lesson_ajax.html", 
                                  :formats => [:html], :layout => false,
                                  :locals => {:slot => @domchangerun[i]['to'],
                                              :lesson => @block_roles[i],
                                              :thistutroles => thistutroles,
                                              :thisroles => thisroles
                                             })
    end
    # saved safely, now need to update the browser display (using calendar messages)
    # collect the set of screen updates and send through Ably as single message
    domchanges = Array.new
    (0..@block_roles.length-1).each do |i|
      domchanges.push(@domchangerun[i])
    end
    ably_rest.channels.get('calendar').publish('json', domchanges)
    #(0..@block_roles.length-1).each do |i|
    #  ably_rest.channels.get('calendar').publish('json', @domchangerun[i])
    #end
    ### ably_rest.channels.get('calendar').publish('json', @domchangepreblock) if @pre_block_role != nil
    # Now send out the updates to the stats screen
    # no change in stats for first item in block.
    # collect the set of stat updates and send through Ably as single message
    statschanges = Array.new
    (1..@block_roles.length-1).each do |i|
      statschanges.push(get_slot_stats(@domchangerun[i]['to']))
    end
    ably_rest.channels.get('stats').publish('json', statschanges)
    #(1..@block_roles.length-1).each do |i|
    #  get_slot_stats(@domchangerun[i]['to'])
    #end
    # everything is completed successfully.
    return ""
  end
  #------------End of Service Function = doExtendLessonRun -------------------


  #******************************************************************
  #--------------- Service Function = runremovepersonfromlesson --------------
  def runremovelessonfromslot(lesson)
    this_error = ""
    # Processing the chain.
    #--------------------- role (actually lesson)-----------------------------
    this_error = get_role_chain_and_block(lesson, {'all' => true})
    return this_error if this_error.length > 0
    #person_type = role.is_a?(Role) ? 'student' : 'tutor'
    #---------------------  check all lessons are empty ----------------------
    (0..@block_roles.length-1).each do |i|
      if @block_roles[i].tutroles.count > 0
        this_error += " Tutors in this lesson"
      end
      if @block_roles[i].roles.count > 0
        this_error += " Students in this lesson"
      end
      if this_error.length > 0
        return "You cannot remove lessons as " + this_error
      end
    end
    #---------------------------  update db ------------------------------
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
        #this_exception = exception
        logger.debug "Transaction failed!!!"
        this_error = "Transaction failed!!! " + exception.inspect
    end
    if this_error.length > 0
      logger.debug "unprocessable entity(line 117): " + this_error 
      return this_error
    end
    #---------------------------  update dom ------------------------------
    @domchangerun = Array.new
    @block_roles.each_with_index do |o, i|
      logger.debug "block_role (" + i.to_s + "): " + o.inspect
      @domchangerun[i] = Hash.new
      @domchangerun[i]['action']         = 'removeLesson'
      @domchangerun[i]['object_type']    = 'lesson'
      @domchangerun[i]['new_slot_domid'] = o.slot.location[0,3] +
                                           o.slot.timeslot.strftime("%Y%m%d%H%M") +
                                    'l' +  o.slot.id.to_s.rjust(@sf, "0")
      @domchangerun[i]['object_id']      = @domchangerun[i]['new_slot_domid'] +      
                                    'n' +  o.id.to_s.rjust(@sf, "0")
    end
    # No breakchainlast updates necessary for display. 
    ############ now need to add processing for screen update #################
    # Now do the breakchainlast
    if @role_breakchainlast # break the chain.
      # Need to display the linkage change on the display
      # @role_breakchainlast is the role
      # display is an update (not a removal) so must rerender
      # build using the role
      o = @role_breakchainlast    # lesson object
      @domchangebreakchainlast = Hash.new
      @domchangebreakchainlast['action']      = 'replace' 
      @domchangebreakchainlast['object_type'] = 'lesson'
      @domchangebreakchainlast['new_slot_id'] = o.slot.location[0,3] +
                                                o.slot.timeslot.strftime("%Y%m%d%H%M") +
                                                'l' + o.slot_id.to_s.rjust(@sf, "0")
      @domchangebreakchainlast['object_id']   = @domchangebreakchainlast['new_slot_id'] +
                                                'n' + o.id.to_s.rjust(@sf, "0")
      # This is rendering a lesson
      @domchangebreakchainlast['html_partial']  = 
        render_to_string("calendar/_schedule_lesson_ajax.html",
                        :formats => [:html], :layout => false,
                                  :locals => {:slot => @domchangebreakchainlast['new_slot_id'],
                                              :lesson => o,
                                              :thistutroles => o.tutroles,
                                              :thisroles => o.roles
                                   })
    end
    #---------------------------  update screens ------------------------------
    # saved safely, now need to update the browser display (using calendar messages)
    # collect the set of screen updates and send through Ably as single message
    domchanges = Array.new
    (0..@block_roles.length-1).each do |i|
      domchanges.push(@domchangerun[i])
    end
    domchanges.push(@domchangebreakchainlast)
    ably_rest.channels.get('calendar').publish('json', domchanges)
    #(0..@block_roles.length-1).each do |i|
    #  ably_rest.channels.get('calendar').publish('json', @domchangerun[i])
    #end
    # Now send out the updates to the stats screen
    # collect the set of stat updates and send through Ably as single message
    statschanges = Array.new
    (0..@block_roles.length-1).each do |i|
      statschanges.push(get_slot_stats(@domchangerun[i]['new_slot_domid']))
    end
    ably_rest.channels.get('stats').publish('json', statschanges)
    #(0..@block_roles.length-1).each do |i|
    #  get_slot_stats(@domchangerun[i]['new_slot_domid'])
    #end
    # everything is completed successfully.
    respond_to do |format|
      format.json { render json: @domchange, status: :ok }
    end
    return ""
  end
  #----------- End of Service Function = runremovelessonfromslot ------------



  #******************************************************************
  #--------------- Service Function = runremovepersonfromlesson --------------
  def runremovepersonfromlesson(role)
    # Processing the chain.
    #--------------------------- role ---------------------------------
    this_error = get_role_chain_and_block(role, {'all' => true})
    return this_error if this_error.length > 0
    person_type = role.is_a?(Role) ? 'student' : 'tutor'
    #---------------------------  update db ------------------------------
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
        #this_exception = exception
        logger.debug "Transaction failed!!!"
        this_error = "Transaction failed!!! " + exception.inspect
    end
    if this_error.length > 0
      #respond_to do |format|
      #  format.json { render json: this_exception, status: :unprocessable_entity }
      #end
      logger.debug "unprocessable entity(line 117): " + this_error 
      return this_error
    end
    #---------------------------  update dom ------------------------------
    # now delete these elements as a single transaction
    # and update the (new) last link in the chain.
    @domchangerun = Array.new
    @block_roles.each_with_index do |o, i|
      logger.debug "block_role (" + i.to_s + "): " + o.inspect
      @domchangerun[i] = Hash.new
      @domchangerun[i]['action']         = 'remove'
      @domchangerun[i]['object_type']    = @domchange['object_type']
      @domchangerun[i]['new_slot_domid'] = o.lesson.slot.location[0,3] +
                                           o.lesson.slot.timeslot.strftime("%Y%m%d%H%M") +
                                    'l' +  o.lesson.slot.id.to_s.rjust(@sf, "0")
      @domchangerun[i]['object_id']      = @domchangerun[i]['new_slot_domid'] +      
                                    'n' +  o.lesson_id.to_s.rjust(@sf, "0")
      if role.is_a?(Role)  # student
        @domchangerun[i]['object_id']      += 's' +  o.student_id.to_s.rjust(@sf, "0")
      else                  # tutor
        @domchangerun[i]['object_id']      += 't' +  o.tutor_id.to_s.rjust(@sf, "0")
      end        
    end
    # Now do the breakchainlast
    if @role_breakchainlast # break the chain.
      # Need to display the linkage change on the display
      # @role_breakchainlast is the role
      # display is an update (not a removal) so must rerender
      # build using the role
      o = @role_breakchainlast
      @domchangebreakchainlast = Hash.new
      @domchangebreakchainlast['action']         = 'replace' 
      @domchangebreakchainlast['object_type']    = @domchange['object_type']
      @domchangebreakchainlast['old_slot_domid'] = o.lesson.slot.location[0,3] +
                                           o.lesson.slot.timeslot.strftime("%Y%m%d%H%M") +
                                    'l' +  o.lesson.slot_id.to_s.rjust(@sf, "0")
      @domchangebreakchainlast['from']           = @domchangebreakchainlast['old_slot_domid'] +
                                    'n' +  o.lesson_id.to_s.rjust(@sf, "0")
      @domchangebreakchainlast['old_slot_id']   = o.lesson.slot_id
      @domchangebreakchainlast['role']          = o
      @domchangebreakchainlast['student']       = o.student     if person_type == 'student'
      @domchangebreakchainlast['tutor']         = o.tutor       if person_type == 'tutor'
      @domchangebreakchainlast['name']          = person_type == 'student' ? o.student.pname  : o.tutor.pname # for sorting in the DOM display
      @domchangebreakchainlast['object_id_old'] = @domchangebreakchainlast['from'] +
                                    's' + o.student.id.to_s.rjust(@sf, "0") if person_type == 'student'
      @domchangebreakchainlast['object_id_old'] = @domchangebreakchainlast['from'] +
                                    't' + o.tutor.id.to_s.rjust(@sf, "0")   if person_type == 'tutor'

      # built using the parent lesson
      # Need the parent
      @lesson_breakchainlast = Lesson.includes(:slot).find(@role_breakchainlast.lesson_id)
      o = @lesson_breakchainlast
      @domchangebreakchainlast['new_slot_domid']  = o.slot.location[0,3] +
                                                    o.slot.timeslot.strftime("%Y%m%d%H%M") +
                                             'l' +  o.slot_id.to_s.rjust(@sf, "0")
      @domchangebreakchainlast['to']              = @domchangebreakchainlast['new_slot_domid'] +
                                             'n' +  o.id.to_s.rjust(@sf, "0")
      if role.is_a?(Role)
        @domchangebreakchainlast['html_partial']  = 
          render_to_string("calendar/_schedule_student.html",
                          :formats => [:html], :layout => false,
                          :locals => {:student  => role.student,
                                      :thisrole => @domchangebreakchainlast['role'], 
                                      :slot     => @domchangebreakchainlast['new_slot_domid'],                     # new_slot_id, 
                                      :lesson   => o.id                               # new_lesson_id
                                     })
        @domchangebreakchainlast['object_id'] = @domchangebreakchainlast['to'] +
                                          's' + role.student_id.to_s.rjust(@sf, "0")
      elsif role.is_a?(Tutrole)
        @domchangebreakchainlast['html_partial']    = 
          render_to_string("calendar/_schedule_tutor.html",
                          :formats => [:html], :layout => false,
                          :locals => {:tutor    => role.tutor, 
                                      :thistutrole => @domchangebreakchainlast['role'], 
                                      :slot     => @domchangebreakchainlast['new_slot_domid'],                     # new_slot_id, 
                                      :lesson   => o.id                               # new_lesson_id
                                     })
        @domchangebreakchainlast['object_id'] = @domchangebreakchainlast['to'] +
                                          't' + role.tutor_id.to_s.rjust(@sf, "0")
      end
    end
    #---------------------------  update screens ------------------------------
    # saved safely, now need to update the browser display (using calendar messages)
    # collect the set of screen updates and send through Ably as single message
    domchanges = Array.new
    (0..@block_roles.length-1).each do |i|
      domchanges.push(@domchangerun[i])
      #ably_rest.channels.get('calendar').publish('json', @domchangerun[i])
    end
    if @role_breakchainlast # break the chain.
      domchanges.push(@domchangebreakchainlast)
      #ably_rest.channels.get('calendar').publish('json', @domchangebreakchainlast)
    end
    ably_rest.channels.get('calendar').publish('json', domchanges)
    # Now send out the updates to the stats screen
    # collect the set of stat updates and send through Ably as single message
    if role.is_a?(Role)    # status only require updating if students change
      statschanges = Array.new
      (0..@block_roles.length-1).each do |i|
        statschanges.push(get_slot_stats(@domchangerun[i]['new_slot_domid']))
        #get_slot_stats(@domchangerun[i]['new_slot_domid'])
      end
      ably_rest.channels.get('stats').publish('json', statschanges)
    end
    # everything is completed successfully.
    respond_to do |format|
      format.json { render json: @domchange, status: :ok }
    end
    return ""
  end
  #----------- End of Service Function = runremovepersonfromlesson ------------


  #******************************************************************
  #----------------- Helper Function = fix_looping_chain -----------------------
  # Fixes looping chains for tutors and students - not lessons and slots
=begin
  def fix_looping_chain(chain)
    # this chain is broken - must find the break and fix
    unless (chain[0].is_a?(Role) || chain[0].is_a?(Tutrole))
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
    if this_error.length > 0
      return this_error
    end
    return "--- WARNING --- \n looping chain has been fixed.\n"
  end
=end
  #---------------- End of Helper Function = fix_looping_chain -----------------


  #******************************************************************
  #----------------- Helper Function = fix_broken_chain -----------------------
=begin
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
        if thislink != nil &&
           chain_reverse_index.has_key?(thislink.id) # there is a previous link
          previouslink = chain[chain_index[chain_reverse_index[thislink.id]]]
          thislink = previouslink     # loop again steping  back through chain
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
=end
  #---------------- End of Helper Function = fix_broken_chain -----------------


  #******************************************************************
  #------------------- Helper Function = fix_lessonMissingSlot ----------------
=begin
  def fix_lessonMissingSlot(mylesson)
    myerror = "--- WARNING ---\n"
    myerror += "Lesson #{mylesson.id.to_s} has no slot - created #{mylesson.created_at.to_s}\n"
    this_lesson = Lesson.includes([:tutroles, :roles]).find(mylesson.id) 
    # need to find the matching slot chain for this lesson
    # first get the lesson chain that this lesson belongs to
    this_lessons_index_id = Hash.new
    this_lessons = Lesson.includes(:slot).where(first: thislesson.first)
    reference_lesson = nil
    this_lessons.each do |o|
      reference_lesson = o if o.slot_id != 0      # has a parent slot identified
      this_lessons_index_id[o.id] = o 
    end
    # build an ordered chain - first to last
    # assume chain is not broken but simply missing slot_id
    lesson_chain_ordered = Array.new
    loop_lesson = this_lessons_index_id[this_lesson.first]  # first lesson in chain
    loop do
      lesson_chain_ordered.push(loop_lesson)
      if loop_lesson.next != nil
        loop_lesson = this_lessons_index_id[loop_lesson.next]
      else 
        break
      end
    end
    if reference_lesson == nil
      myerror += "No parent slot allowing fixing of parent lesson chain."
      return myerror 
    end
    # Get the slot chain
    this_slot = Slot.find(reference_lesson.slot_id)
    this_slots = Slot.where(first: this_slot.first)
    this_slots_index_id = Hash.new
    this_slots.each do |o|
      this_slots_index_id[o.id] = o
    end
    # normally the number of lessons and number of slots should match
    # and should be in step
    # However, lessons can be created or stopped during the term.
    # see if we can step through the chains and check that they match
    # Start at beginning of lesson chain.
    flagInvalidLessonFound = false
    firstSyncLesson = nil
    firstSyncSlot = nil
    lesson_chain_ordered.each_with_index do |o, i|
      if o.slot_id != nil   # lesson has a slot (not faulty)
        if this_slots_index_id.has_key?(o.slot_id) # there is a matching slot
          # Have a synchronisation point.
          firstSyncLesson = o
          firstSyncSlot = o.slot_id
          break
        end
      else
        flagInvalidLessonFound = true
      end
    end
    # have a sync point, now step through chains
    if flagInvalidLessonFound   # invalid lesson before sync pont
      # have to step backwards to fix      
    else   # fix by stepping forward
      loop_lesson = this_lessons_index_id[firstSyncLesson.next]
      loop_slot   = this_slots_index_id[firstSyncSlot.next]
      loop
        if loop_lesson.slot_id != 0    # is valid
          if loop_slot.id = loop_lesson.slot_id  # still instep
            if loop_lesson.next != nil &&
               loop_slot.next != nil
              loop_lesson = this_lessons_index_id[loop_lesson.next]
              loop_slot   = this_slots_index_id[loop_slot.next]
            else
              myerror += "Cannot fix missing slot for lesson as not enough valid chain for repairs."
              return myerror
            end
          else
            myerror += "cannot fix lesson missing slot - slots and lessons out of step."
            return myerror 
          end
        else   # the faulty lesson
          # fix by using teh matching slot id from the slot chain
          loop_lesson.slot_id = loop_slot.id
          loop_lesson.save
          myerror += "lesson (#{loop_lesson.id} with missing slot (#{loop_slot.id}) has been repaired."
          return myerror 
        end
    end
    return myerror
  end
=end
  #------------- End of Helper Function = fix_lessonMissingSlot ---------------

end