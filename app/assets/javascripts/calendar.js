/* Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
*/

/* global $ */

// Note: this is called with turbolinks at bottom of page.
// Written as a callable function to provide this flexibility.
// Found that we need to be careful this does not get called twice
// e.g. from from both tuboload and page load - causes double triggers.
var ready = function() {
  // some global variables for this page
  var sf = 5;     // significant figures for dom id components e.g.lesson ids, etc.
  var myhost = window.location.protocol + '//' + window.location.hostname;   // base url for ajax

  // These are used in the quick status setting.
  var validTutorStatuses = ["Away", "Absent", "Deal", "Scheduled", "Notified", "Confirmed", "Attended"];
  var validStudentStatuses = ["Away", "Absent", "Deal", "Attended", "Scheduled"];


  // want to set defaults on some checkboxes on page load
  if (document.getElementById("hidetutors") &&
      document.getElementById("hidestudents")){
    //document.getElementById("hidetutors").checked = true;
    //document.getElementById("hidestudents").checked = true;
    
    var showList = document.getElementsByClassName("selectsite");
    if(showList.length > 0){
      showList[0].checked = true;
    }
    
    selectshows();  // call the functions that invokes the checkbox values.
  }
  
  $("ui-draggable");
  
//------------------------ Context Menu -----------------------------
// This is the context menu for the lesson,
// tutor and student elements.
// It is the first context menu to be displayed when you right click on an
// element.
// When some context menu item are selected, a tertiary menu is opened
// enabling further options to be selected.


  // the order of this class list is important - searches are done from 
  // finest to broadest when looking for relevant elements(divs).
  var taskItemClassList = ['slot', 'lesson', 'tutor', 'student'];
  var taskItemInContext;  
  var contextMenuActive = "context-menu--active";
  var tertiaryMenuActive = "tertiary-menu--active";
  var contextMenuItemClassName = "context-menu__item";
  var tertiaryMenuItemClassName = "tertiary-menu__choice";
  var menu;
  var menuState = 0;
  var tmenu;            // tertiary menu with context menu parent
  var tmenuState = 0;
  var clickPosition;
  var eleClickedOn;
  var currentActivity = {};
  var stackActivity = [];

  // This opertions provide visual feedback when you are moving over
  // menu items.
  $('.context-menu__item').mouseenter(function(){
    $(this).css('background-color','lime');
  });
  $('.context-menu__item').mouseleave(function(){
    $(this).css('background-color', 'white');
  });

  $('.context-menu__choice').mouseenter(function(){
    $(this).css('background-color','lime');
  });
  $('.context-menu__choice').mouseleave(function(){
    $(this).css('background-color', 'white');
  });


  // Initialise our application's code.
  // Made modular so that you have more control over initialising them. 
  function init() {
    contextListener();
    clickListener();
    keyupListener();
    resizeListener();
  }
  
  if ($('#sticky-header').length) {
    var stickyHeaderTop = $('#sticky-header').offset().top;
    $(window).scroll(function (event) {
      var y = $(this).scrollTop();
      if (y >= stickyHeaderTop)
        $('#sticky-header').addClass('fixed');
      else
        $('#sticky-header').removeClass('fixed');
      $('#sticky-header').width($('#sticky-header').parent().width());
    });
    
    $('.sticky-header__title').click(function() {
      $('#sticky-header__collapsible').slideToggle();
    })
  }

  // Listens for contextmenu events.
  // Add the listeners for the main menu items.
  // contextmenu is an integrated javascript library function.
  // We detect the element right clicked on and position the context
  // menu adjacent to it.
  function contextListener() {
    document.addEventListener( "contextmenu", function(e) {
      //console.log("== contextmenu Listener ==");
      //console.log(e.currentTarget);
      menu = document.querySelector("#context-menu");
      tmenu = document.querySelector("#tertiary-menu");
      taskItemInContext = clickInsideElementClassList( e, taskItemClassList);
      if ( taskItemInContext ) {
        //console.log("-----taskItemInContext-----should be the element of interest");
        //console.log(taskItemInContext);
        //console.log("element id: " + taskItemInContext.id);
        e.preventDefault();
        enableMenuItems();
        toggleMenuOn();
        clickPosition = getPosition(e);  // global variable
        positionMenu(menu);
        positionMenu(tmenu);
        eleClickedOn = e;                 // global variable
        //console.log("----------event clicked on-----------");
        //console.log(eleClickedOn);
      } else {
        taskItemInContext = null;
        toggleMenuOff();
      }
    });
  }

  //Listens for click events on context menu items element.
  // On selection an item on the context menu, an appropriate action is triggered.
  // 
  function clickListener() {
    document.addEventListener( "click", function(e) {
      console.log("== clickListener ==");
      console.log(e.currentTarget);
      // determine if clicked inside main context menu or tertiary context menu.
      var clickEleIsAction = clickInsideElementClassList( e, [contextMenuItemClassName]);
      var clickEleIsChoice = clickInsideElementClassList( e, [tertiaryMenuItemClassName]);
      var clickEleIsTutor  = clickInsideElementClassList( e, ["tutor"]);
      var clickEleIsStudent  = clickInsideElementClassList( e, ["student"]);
  
      if ( clickEleIsAction ) {      // clicked in main context menu
        e.preventDefault();
        menuItemActioner( clickEleIsAction );   // call main menu item actioner.
      } else if (clickEleIsChoice) {     // clicked in tertiary menu or text edits
        if (clickEleIsChoice.id == 'edit-comment' ||   // clicked in an edit box
            clickEleIsChoice.id == 'edit-subject') {  
          //console.log("in one of the edit text boxes"); 
          // determine if clicked on edit-comment update button
          var thisTarget = e.target;
          if (thisTarget.id == 'edit-comment-button' ||
              thisTarget.id == 'edit-subject-button' ){  // do comment update
            //console.log("edit-comment-button or edit-subject-button is clicked");
            //call this function to update the text for comments or subjects.
            // This has quite a range.
            editCommentSubjectActioner(thisTarget.id);
            toggleTMenuOff();
          } //else just editing - do nothing special (default actions)
        } else {   // clicked in tertialy menu action values
          e.preventDefault();
          menuChoiceActioner( clickEleIsChoice );    // process tertiary menu actions.
        }
      } else if (clickEleIsTutor ||     // clicked on tutor
                 clickEleIsStudent){    // or a student
          //var validTutorStatuses = ["Deal", "Dealt", "Scheduled", "Notified", "Confirmed", "Attended"];
          //var validStudentStatuses = ["Deal", "Dealt", "Attended"];
          // clickEleIsTutor = tutor element to be manipulated.
          // clickEleIsStudent = student element to be manipulated.
          if (document.getElementById('enableQuickStatus').checked){
            var newStatus = document.getElementById('quickStatusValue').value;
            if (clickEleIsTutor){     // clicked on tutor
              if (validTutorStatuses.indexOf(newStatus) >= 0){
                console.log("set tutor status to: " + newStatus);
                currentActivity['action'] = "tutor-status-" + newStatus.toLowerCase(); 
                currentActivity['move_ele_id'] = clickEleIsTutor.id;
                personupdatestatuskindcomment( currentActivity );
              }
            } else {                // clicked on student
              if (validStudentStatuses.indexOf(newStatus) >= 0){
                console.log("set student status to: " + newStatus);
                currentActivity['action'] = "student-status-" + newStatus.toLowerCase(); 
                currentActivity['move_ele_id'] = clickEleIsStudent.id;
                personupdatestatuskindcomment( currentActivity );
              }
            }
          }
      } else {    // clicked anywhere else
        var button = e.which || e.button;
        if ( button === 1 ) {
          toggleMenuOff();
          toggleTMenuOff();
        }
      }
    });
  }

  // Listens for keyup events on escape key.
  // Simply removes the menus.
  function keyupListener() {
    window.onkeyup = function(e) {
      if ( e.keyCode === 27 ) {
        toggleMenuOff();
        toggleTMenuOff();
      }
    };
  }
  
  //function getRecordType(ele_id){
  //function getRecordId(ele_id){
  // this function extracts the record type (l, n, t, s) from the dom id
  // for slot, lesson, tutor and student entries
  function getRecordType(ele_id){
    return ele_id.substr(ele_id.length-sf-1, 1);
  }

  // this function extracts the record id from the dom id
  // for slot, lesson, tutor and student entries
  function getRecordId(ele_id){
    return ele_id.substr(ele_id.length-sf, sf);
  }

  // used to extract lesson id from a tutor or student element's id
  // the lesson id is embedded in the elementid to ensure uniqueness.
  function getLessonIdFromTutorStudent(ele_id){
    //return ele_id.substr(ele_id.length-sf-1, 1);
    return ele_id.substr(ele_id.length-sf-1-sf, sf);
  }

  // As these are context sensitive menus, we need to determine what actions
  // are displayed.
  // Basically, all items are in the browser page. They are simply shown or
  // hidden depending on what element is right clicked on.
  // Elements identified are tutor, students, lessons and slots.
  // Also, selecting tutors and students in the top of the page (index area) 
  // causes different actions to selecting them in the scheduling section (lesson).
  // Names are choosen to be self explanatory - hopefully.
  function enableMenuItems(){
    var thisEleId = taskItemInContext.id;    // element clicked on
    var thisEle = document.getElementById((thisEleId));
    var recordType = getRecordType(thisEleId);  //student, tutor, lesson
    var scmi_copy = false;  //scmi - set comtext menu items.
    var scmi_move = false;  // to show or not show in menu
    var scmi_paste = false;  // set the dom display value at end.
    var scmi_remove = false;
    var scmi_addLesson = false;
    var scmi_removeLesson = false;
    var scmi_setStatus = false;
    var scmi_setKind = false;
    var scmi_editComment = false;
    var scmi_editDetail = false;
    var scmi_history = false;
    var scmi_changes = false;
    var scmi_editSubject = false;
    var scmi_editEntry = false;

    //  var currentActivity = {};   declared globally within this module

    // You can only paste if a source for copy or move has been identified.
    if(currentActivity.action  == 'move' || // something has been copied,
       currentActivity.action  == 'copy'){  // ready to be pasted
      scmi_paste = true;
    }

    switch(recordType){     // student, tutor, lesson.
      case 's':   //student
      case 't':   //tutor
        if(clickInsideElementClassList2(thisEle, ['index'])){   // index area
          // this element in student and tutor list
          scmi_copy = true;
          scmi_paste = false;   //nothing can be pasted into the index space
          scmi_editComment = true;
          scmi_editSubject = true;
          scmi_editEntry   = true;
        }else{  // in the main schedule area (lesson)
          scmi_copy = scmi_move = scmi_remove = scmi_addLesson = true;
          scmi_setStatus = scmi_setKind = scmi_editComment = scmi_editDetail = true;
          scmi_history = true;
          scmi_changes = true;
        }
        break;
      case 'n':   //lesson which is always in the main scheduling area.
          scmi_move = scmi_addLesson = scmi_setStatus = true;
          // if there are no tutors or students in this lesson, can remove
          var mytutors = thisEle.getElementsByClassName('tutor'); 
          var mystudents = thisEle.getElementsByClassName('student');
          if( (mytutors && mytutors.length == 0 )  &&
              (mystudents && mystudents.length == 0 )  ){
            scmi_removeLesson = true;
          }
          scmi_editComment = true;
          break;
      case 'l':   //slot which is always in the main scheduling area.
          scmi_addLesson = true;
          break;
    }
    
    // Here we simply hide or show the menu items based on above settings.
    setscmi('context-move', scmi_move);
    setscmi('context-copy', scmi_copy);
    setscmi('context-paste', scmi_paste);
    setscmi('context-remove', scmi_remove);
    setscmi('context-addLesson', scmi_addLesson);
    setscmi('context-removeLesson', scmi_removeLesson);
    setscmi('context-setStatus', scmi_setStatus);
    setscmi('context-setKind', scmi_setKind);
    setscmi('context-editComment', scmi_editComment);
    setscmi('context-editDetail', scmi_editDetail);
    setscmi('context-editSubject', scmi_editSubject);
    setscmi('context-history', scmi_history);
    setscmi('context-changes', scmi_changes);
    setscmi('context-editEntry', scmi_editEntry);
  }
  
  function setscmi(elementId, scmi){
    if(document.getElementById(elementId)){
      if(scmi){
        document.getElementById(elementId).classList.remove('hideme');
      }else{
        document.getElementById(elementId).classList.add('hideme');
      }
    }
  }

//***********************************************************************
// Perform the actions invoked by the context menu items.                *
// Some actions will invoke a second level (tertialy) menu.              *
//***********************************************************************
  // action is the element clicked on in the menu.
  // The menu element clicked on has an attribute "data-action" that 
  // describes the required action.
  function menuItemActioner( action ) {
    //dom_change['action'] = "move";
    //dom_change['move_ele_id'] = ui.draggable.attr('id');
    //dom_change['ele_old_parent_id'] = document.getElementById(dom_change['move_ele_id']).parentElement.id;
    //dom_change['ele_new_parent_id'] = this.id;
    //dom_change['element_type'] = "lesson";
    toggleMenuOff();
    //console.log("-------------- menu item action passed object ---------------");
    //console.log(action);
    var thisAction =  action.getAttribute("data-action");
    // taskItemInContext is a global variable set when context menu first invoked.
    var thisEleId = taskItemInContext.id;    // element 'right clicked' on
    var thisEle = document.getElementById((thisEleId));
    //console.log("thisAction: " + thisAction);
    // 'thisAction' are basically the context menu selectable items.
    // However, not all of these cases were available in the menu for any given
    // element that was right clicked on.
    // Note that for cut, move and paste, compatability is kept between menu 
    // selection and drag and drop.
    
    // There are some operations that happen for ALMOST every action.
    // The exception is if there has already been a copy or paste - then 
    // info from that action is held over -> stored in currentActivity.
    // To complete this current activity, you need a paste.
    // Otherwise, a current activity is cleared when the action is completed.
    if((thisAction == "paste")) {   // been a cut or move initiated so can do a paste
      // do not set currentActivity 
      // That way, when we do checks in "paste" action, currentActivity will
      // be empty if a move or copy has not been selected.
    } else {
      // but for all other actions, we need to set action, element_id and 
      // the old (pre-manimpulation) parent of the element being manipulated.
      // i.e. tutor and student -> nearest session as old parent
      //      session           -> nearest slot as old parent
      currentActivity['action'] = thisAction;
      currentActivity['move_ele_id'] =  thisEleId;
      thisEle = document.getElementById(thisEleId);
      //currentActivity['ele_old_parent_id'] = document.getElementById(thisEleId).parentElement.id;
      switch ( getRecordType(thisEleId) ) {
        case 's':   //student
        case 't':   //tutor
          currentActivity['ele_old_parent_id'] = clickInsideElementClassList2(thisEle, ['lesson']).id;
          break;
        case 'n':   //lesson
          currentActivity['ele_old_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
          break;
      }
    }

    switch( thisAction ) {     
      case "copy":
      case "move":
        //console.log("copy or cut");
        //console.log("finished the move/copy case processing");
        //console.log(currentActivity);
        // Nothing else to do, need a paste before any action can be taken!!!
        break;
      case "paste":
        //console.log("paste");
        //Note, we need the action for the move/copy, not paste.
        // On dropping, need to move up parent tree of the destination element
        // till find the appropriate parent
        //console.log(currentActivity);
        if( currentActivity ) {   // been a cut or move initiated so can do a paste
          // based on the type of element we are moving
          // Note, currentActiviey['move_ele_id'] is the element right clicked on when
          // copy or move was selected - held over in this variable.
          switch ( getRecordType(currentActivity['move_ele_id']) ) {
            case 's':   //student
            case 't':   //tutor
              // find the 'lesson' element in the tree working upwards
              // as thisEle is the dom location we are moving this element to.
              currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['lesson']).id;
              //******************************************************
              // Need the database changes and manipulation called here
              //******************************************************
              personupdateslesson( currentActivity );
              //----- contained in currentActivity ------------(example)
              //  move_ele_id: "Wod201705301600s002",
              //  ele_old_parent_id: "Wod201705301600n001", 
              //  element_type: "student"
              //  ele_new_parent_id: "Wod201705291630n003"
              //----------required in ajax (domchange)---------------------------------
              break;
            case 'n':   //lesson
              // find the 'slot' element in the tree working upwards
              // as thisEle is the dom location we are moving this element to.
              currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
              lessonupdateslot( currentActivity );
              break;
          }
          currentActivity = {};     // clear when done - can't paste twice.
        }  // end of if currentActivity
        // Of course, if there is no currentActivity on a paste, then ignore.
        break;
      case "remove":
        // This removed the selected element
        // Actually deletes the mapping record for tutor and student
        deleteentry(currentActivity);
        break;
      case "addLesson":
        // This will add a new lesson within the slot holding the element clicked.
        // Will add a new lesson record with this slot value.
        currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
        addLesson(currentActivity);
        break;
      case "removeLesson":
        // This will remove a lesson clicked on.
        // Will delete the lesson record for a lesson only if empty 
        // i.e. not tutors or students.
        // This is needed as no matter what element was clicked on, we still need
        // to find the nearest slot - prevous setting could have been tutor 
        // finding lesson as parent.
        currentActivity['ele_old_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
        removeLesson(currentActivity);
        break;
      case "setStatus":
        // Set Status has been selected on an element.
        // It will open up another menu to select the status required.
        // This will set the status of this item (tutor, student, lesson).
        //currentActivity['ele_old_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
        enableTertiaryMenu(thisEle, thisAction, currentActivity);
        break;
      case "setKind":
        // Set Kind has been selected on an element.
        // It will open up another menu to select the status requried.
        // This will set the status of this item (tutor, student, lesson).
        //currentActivity['ele_old_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
        enableTertiaryMenu(thisEle, thisAction, currentActivity);
        break;
      case "editDetail":
        // this case edits the tutor or student comment when we have clicked 
        // on the student or tutro in the scheduler area.
        // This is actioned by making believe that we have clicked on this 
        // tutor or student in the index area, then let editComment take its
        // course. (Hence no break after this section!)
        //
        // currentActivity['move_ele_id'] =  thisEleId;
        // thisEle = document.getElementById(thisEleId);
        // function getRecordType(ele_id){
        // function getRecordId(ele_id){
        // generate the element id of this person in the index area
        // and override existing values.
        thisEleId = getRecordType(thisEleId) + getRecordId(thisEleId);
        thisEle = document.getElementById(thisEleId);
        currentActivity['move_ele_id'] = thisEleId;
        currentActivity['action'] = "editComment";
      case "editComment":
        // Edit Comment has been selected on an element.
        // It will open up a text field to key in your updates.
        // This will update the relevant comment.
        var personContext = '';
        if(clickInsideElementClassList2(thisEle, ['index'])){
          personContext = 'index';
        } else {
          personContext = 'lesson';
        }
        // ???? is the following line needed ???????????
        //currentActivity['ele_old_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
        
        var recordType = getRecordType(thisEleId);  //student, tutor, lesson
        var thisComment;
        // We need to get the comment text which is to be edited.
        // This has to be obtained from the appropriate location in the html doc.
        if(recordType == 't') {   // tutor
          if(personContext == 'index') {    // index
            thisComment = thisEle.getElementsByClassName('tutorcommentdetail')[0].innerHTML;
          } else {                          // lesson
            thisComment = thisEle.getElementsByClassName('tutrolecomment')[0].innerHTML;
          }
        } else if(recordType == 's') {   // student
          if(personContext == 'index'){     // index
            thisComment = thisEle.getElementsByClassName('studentcommentdetail')[0].innerHTML;
          } else {                          // lesson
            thisComment = thisEle.getElementsByClassName('rolecomment')[0].innerHTML;
          }
        } else if(recordType == 'n') {   // session
          thisComment = thisEle.getElementsByClassName('lessoncommenttext')[0].innerHTML;
        }
        // Now that we have the text, we need to place it into the text eniting 
        // field in the browser doc and then show it in the tertiary menu.
        document.getElementById('edit-comment-text').value = thisComment;
        document.getElementById('edit-comment-elementid').innerHTML = thisEleId;
        //enableTertiaryMenu(thisEle, thisAction, currentActivity);
        enableTertiaryMenu(thisEle, currentActivity['action'], currentActivity);
        break;
      case "editSubject":
        // Edit Subject has been selected on an element.
        // It will open up a text field to key in your updates.
        // This will update the relevant subject.
        // The editing dialogue is the same one as for editing
        // comments.
        //currentActivity['ele_old_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
        // We need to get the subject text which is to be edited.
        // This has to be obtained from the appropriate location in the html doc.
        // The subject text for student is combined with other stuff - so 
        // needs to be split out. Tutor is clean.
        recordType = getRecordType(thisEleId);  //student, tutor, lesson
        if(recordType == 't') {   // tutor
          var thisSubject = thisEle.getElementsByClassName('tutorsubjects')[0].innerHTML;
        } else if(recordType == 's') {   // student
          thisSubject = thisEle.getElementsByClassName('studentsubjects')[0].innerHTML;
          var res = thisSubject.split("|");
          thisSubject = res[1];
          thisSubject = thisSubject.slice( 1 ); // remove space inserted by display format
        } 
        // Now that we have the text, we need to place it into the text eniting 
        // field in the browser doc and then show it in the tertiary menu.
        document.getElementById('edit-subject-text').value = thisSubject;
        document.getElementById('edit-subject-elementid').innerHTML = thisEleId;
        enableTertiaryMenu(thisEle, thisAction, currentActivity);
        break;
      case "history":
        // Edit Comment has been selected on an element.
        // It will open up a text field to key in your updates.
        // This will update the relevant comment.
        getHistory(currentActivity);        
        break;
      case "changes":
        // Display changes has been selected on an element.
        // Want to open another tab to display the changes.
        // url is "https//:myhost/tutors or students/change/n"
        // currentActivity['action'] = thisAction;
        // currentActivity['move_ele_id'] =  thisEleId;
        //console.log ("in changes");
        //console.log(currentActivity);
        var personType = getRecordType(thisEleId);
        var personId = getRecordId(thisEleId);
        var myurl = '';
        if(personType == 't') {
          myurl = myhost + '/tutors/change/' + personId;
        } else if (personType == 's') {
          myurl = myhost + '/students/change/' + personId;
        }
        //console.log('myurl: ' + myurl);
        window.open(myurl, '_blank');
        //var win = window.open(myurl, '_blank');
        //win.focus();
        break;
      case "editEntry":
        // Edit tutor has been selected on an element.
        // Want to open the tutor edit screen.
        // url is "https//:myhost/tutors or students/n/edit"
        // currentActivity['action'] = thisAction;
        // currentActivity['move_ele_id'] =  thisEleId;
        //console.log ("in changes");
        //console.log(currentActivity);
        var personType = getRecordType(thisEleId);
        var personId = getRecordId(thisEleId);
        var myurl = '';
        if(personType == 't') {
          myurl = myhost + '/tutors/' + personId + '/edit';
        } else if (personType == 's') {
          myurl = myhost + '/students/' + personId + '/edit';
        }
        //console.log('myurl: ' + myurl);
        window.open(myurl, '_blank');
        //var win = window.open(myurl, '_blank');
        //win.focus();
        break;
      }
      //console.log("--- completed context menu actioner ---");
      //console.log("--- currentActivity ---");
      //console.log(currentActivity);
  }
  
  // This determines what is displayed in the tertiary menu.
  // It is context sensitive so depends on what element is
  // right clicked on.
  function enableTertiaryMenu(etmEle, etmAction, currentActivity){
    // etmEle = original element right clicked on.
    // etmAction = action selected within the primary context menu.
    // currentActivity['action'];
    // currentActivity['move_ele_id'];
    // currentActivity['ele_old_parent_id'];  ?? rarely required.
    console.log("--------------- enableTertiaryMenu ---------------");
    // Need to add another context menu with selection choices
    // based on action and move_ele_id
    // etmAction = action of the first context menu e.g set tutor status
    // etm = element tertiary menu
    var etmEleId = etmEle.id; // element clicked on e.g. tutor, student, lesson
    var recordType = getRecordType(etmEleId);  //student, tutor, lesson
    var stmi_tutor_status_scheduled   = false;   // stmi = set tertiary menu item
    var stmi_tutor_status_notified    = false;
    var stmi_tutor_status_confirmed   = false;
    var stmi_tutor_status_attended    = false;
    var stmi_tutor_status_deal        = false;   
    var stmi_tutor_status_absent      = false;
    var stmi_tutor_status_away        = false;
    
    var stmi_tutor_kind_oncall        = false;
    var stmi_tutor_kind_onsetup       = false;
    var stmi_tutor_kind_bfl           = false;
    var stmi_tutor_kind_training      = false;
    var stmi_tutor_kind_standard      = false;
    var stmi_tutor_kind_called        = false;
    var stmi_tutor_kind_relief        = false;

    var stmi_student_status_scheduled = false;
    var stmi_student_status_attended  = false;
    var stmi_student_status_deal      = false;
    var stmi_student_status_absent    = false;
    var stmi_student_status_away      = false;

    var stmi_student_kind_free        = false;
    var stmi_student_kind_first       = false;
    var stmi_student_kind_catchup     = false;
    var stmi_student_kind_fortnightly = false;
    var stmi_student_kind_onetoone    = false;
    var stmi_student_kind_standard    = false;

    var stmi_lesson_status_oncall     = false;
    var stmi_lesson_status_onsetup    = false;
    var stmi_lesson_status_onbfl      = false;
    var stmi_lesson_status_standard   = false;

    var stmi_edit_comment             = false;
    var stmi_edit_subject             = false;
    
    // First, identify type of element being actioned e.g. tutor, lesson, etc..
    switch(recordType){
      case 't':   // tutor
        console.debug("etm recordType is tutor");
        // Now show the tertiary choices for this element.
        switch(etmAction){
          case 'setStatus':   // tutor set Status options
            console.debug("etmAction is tutor");
            stmi_tutor_status_scheduled = true;   // stmi - set tertiary menu item
            stmi_tutor_status_notified  = true;
            stmi_tutor_status_confirmed = true;
            stmi_tutor_status_attended  = true;
            stmi_tutor_status_deal      = true;
            stmi_tutor_status_absent    = true;
            stmi_tutor_status_away      = true;
            break;
          case 'setKind':   // tutor set Kind options
            console.debug("etmAction is setKind");
            stmi_tutor_kind_bfl         = true;
            stmi_tutor_kind_oncall      = true;
            stmi_tutor_kind_onsetup     = true;
            stmi_tutor_kind_training    = true;
            stmi_tutor_kind_standard    = true;
            stmi_tutor_kind_called      = true;
            stmi_tutor_kind_relief      = true;
            break;
          case 'editComment':   // show the text edit box & populate
            console.debug("etmAction is editComment");
            stmi_edit_comment           = true;
            break;
          case 'editSubject':   // show the text edit box & populate
            console.debug("etmAction is editSubject");
            stmi_edit_subject           = true;
            break;
        }     // switch(etmAction)
        break;
      case 's':   // student
        console.debug("etm recordType is student");
        // Now show the tertiary choices for this element.
        switch(etmAction){
          case 'setStatus':   // student set Status options
            console.debug("etmAction is setStatus");
            stmi_student_status_scheduled = true
            stmi_student_status_attended  = true;
            stmi_student_status_deal      = true;
            stmi_student_status_absent    = true;
            stmi_student_status_away      = true;
            break;
          case 'setKind':   // student set Kind options
            console.debug("etmAction is setKind");
            stmi_student_kind_free        = true;            
            stmi_student_kind_first       = true;
            stmi_student_kind_catchup     = true;
            stmi_student_kind_fortnightly = true;
            stmi_student_kind_onetoone    = true;
            stmi_student_kind_standard    = true;
            break;
          case 'editComment':   // show the text edit box & populate
            console.debug("etmAction is editComment");
            stmi_edit_comment             = true;
            break;
          case 'editSubject':   // show the text edit box & populate
            console.debug("etmAction is editSubject");
            stmi_edit_subject             = true;
            break;
        }     // switch(etmAction)
        break;

      case 'n':   //lesson
        console.debug("etm recordType is lesson");
        // Now show the tertiary choices for this element.
        switch(etmAction){
          case 'setStatus':   // lesson set Status options
            stmi_lesson_status_oncall     = true;
            stmi_lesson_status_onsetup    = true;
            stmi_lesson_status_onbfl      = true;
            stmi_lesson_status_standard   = true;
            break;
          case 'editComment':   // show the text edit box & populate
            console.debug("etmAction is editComment");
            stmi_edit_comment             = true;
            break;
        }
        break;
    }     // switch(recordType
    
    setscmi('tutor-status-scheduled', stmi_tutor_status_scheduled);
    setscmi('tutor-status-notified', stmi_tutor_status_notified);
    setscmi('tutor-status-confirmed', stmi_tutor_status_confirmed);
    setscmi('tutor-status-attended', stmi_tutor_status_attended);
    setscmi('tutor-status-deal', stmi_tutor_status_deal);
    setscmi('tutor-status-absent', stmi_tutor_status_absent);
    setscmi('tutor-status-away', stmi_tutor_status_away);
    
    setscmi('tutor-kind-bfl', stmi_tutor_kind_bfl);
    setscmi('tutor-kind-oncall', stmi_tutor_kind_oncall);
    setscmi('tutor-kind-onsetup', stmi_tutor_kind_onsetup);
    setscmi('tutor-kind-training', stmi_tutor_kind_training);
    setscmi('tutor-kind-standard', stmi_tutor_kind_standard);
    setscmi('tutor-kind-called', stmi_tutor_kind_called);
    setscmi('tutor-kind-relief', stmi_tutor_kind_relief);

    setscmi('student-status-scheduled', stmi_student_status_scheduled);
    setscmi('student-status-attended', stmi_student_status_attended);
    setscmi('student-status-deal', stmi_student_status_deal);
    setscmi('student-status-absent', stmi_student_status_absent);
    setscmi('student-status-away', stmi_student_status_away);

    setscmi('student-kind-free', stmi_student_kind_free);            
    setscmi('student-kind-first', stmi_student_kind_first);
    setscmi('student-kind-catchup', stmi_student_kind_catchup);
    setscmi('student-kind-fortnightly', stmi_student_kind_fortnightly);
    setscmi('student-kind-onetoone', stmi_student_kind_onetoone);
    setscmi('student-kind-standard', stmi_student_kind_standard);

    setscmi('lesson-status-oncall', stmi_lesson_status_oncall);
    setscmi('lesson-status-onsetup', stmi_lesson_status_onsetup);
    setscmi('lesson-status-on_BFL', stmi_lesson_status_onbfl);
    setscmi('lesson-status-standard', stmi_lesson_status_standard);

    setscmi('edit-comment', stmi_edit_comment);
    setscmi('edit-subject', stmi_edit_subject);
    
    toggleMenuOff();
    toggleTMenuOn();

  }

  // This function actions the choices made in the tertiay menu.
  // Only limited items exist here, but they are sensitive to
  // what was selected in the primary context menu.
  // This gets used for 'Set Status', 'Set Kind' & 'Edit Comment'
  // For these elements, only need 
  // - element right clicked on
  // - action to be taken.
  // personupdatestatuskindcomment() does the smart stuff.
  function menuChoiceActioner( choice ){
    // choice = the tertiary menu item selected (dom element)
    //console.log("--------------- menuChoiceActioner ---------------------");
    toggleTMenuOff();
    //console.log(choice);
    var thisChoice =  choice.getAttribute("data-choice");
    var thisEleId = taskItemInContext.id;    // element 'right clicked' on
    //console.log("choice: " + thisChoice);
    //console.log("thisEleId: " + thisEleId);
    currentActivity['action'] = thisChoice;
    currentActivity['move_ele_id'] = thisEleId;
    personupdatestatuskindcomment( currentActivity );
  }
  
  // This actions the text editing results following the person editing
  // the text and pressing update.
  function editCommentSubjectActioner(editButton){
    console.log("--------------- editCommentSubjectActioner ---------------------");
    //toggleTMenuOff();
    // thisTarget.id is one of two options:
    // - 'edit-comment-button'
    // - 'edit-subject-button'
    
    // First step is to get required details from text edit box 
    // - updated commment + id of the comment field to be updated.
    if (editButton == 'edit-comment-button'){
      var thisComment = document.getElementById('edit-comment-text').value;
      var thisEleId = document.getElementById('edit-comment-elementid').innerHTML;
      currentActivity['action'] = '-comment-edit';
    } else {   // edit-subject-button
      thisComment = document.getElementById('edit-subject-text').value;
      document.getElementById('edit-subject-text').value = '';
      //document.getElementById('edit-subject-text').value = '';
      thisEleId = document.getElementById('edit-subject-elementid').innerHTML;
      currentActivity['action'] = '-subject-edit';
    }
    // Now set up ready for the db update and dom changes.
    currentActivity['move_ele_id'] = thisEleId;
    currentActivity['new_value'] = thisComment;
    //var thisEle = document.getElementById(thisEleId);
    var recordType = getRecordType(thisEleId);  //student, tutor, lesson
    if (recordType == 't'){
      currentActivity['action'] = 'tutor' + currentActivity['action'];
    }else if (recordType == 's'){
      currentActivity['action'] = 'student' + currentActivity['action'];
    }else if (recordType == 'n'){
      currentActivity['action'] = 'lesson-comment-edit';
    }
    // now update the database, then the dom.
    personupdatestatuskindcomment( currentActivity );
  }
  
//***********************************************************************
// End of performing the actions invoked by the context menu items.     *
//***********************************************************************
  
  function toggleMenuOn() {
    if ( menuState !== 1 ) {
      menuState = 1;
      menu.classList.add(contextMenuActive);
    }
  }

  function toggleMenuOff() {
    if ( menuState !== 0 ) {
      menuState = 0;
      menu.classList.remove(contextMenuActive);
    }
  }

  function toggleTMenuOn() {
    if ( tmenuState !== 1 ) {
      tmenuState = 1;
      tmenu.classList.add(tertiaryMenuActive);
    }
  }

  function toggleTMenuOff() {
    if ( tmenuState !== 0 ) {
      tmenuState = 0;
      tmenu.classList.remove(tertiaryMenuActive);
    }
  }
  
  
  //On windows screen resize, hides the menu - start selection again 
  function resizeListener() {
    window.onresize = function(e) {
      toggleMenuOff();
      toggleTMenuOff();

    };
  }

  init();

  // check if clicked element or element in the parent chain 
  // is of the class provided in the list.
  function clickInsideElementClassList( e, classNameList ) {
    var el = e.srcElement || e.target;
    return clickInsideElementClassList2( el, classNameList );
  }
  
  function clickInsideElementClassList2( el, classNameList ) {
    if(el.classList){
      for(var i = classNameList.length; i--; ) {
        if ( el.classList.contains(classNameList[i]) ) {
          return el;
        }
      }
    }
    while ( (el = el.parentNode) ) {
      if(el.classList){
        for(i = classNameList.length; i--; ) {
          if ( el.classList.contains(classNameList[i]) ) {
            return el;
          }
        }
      }
    }
    return false;
  }
  
  // get position on screen of where the event occurred - point of clicking
  function getPosition(e) {
    var posx = 0;
    var posy = 0;
  
    if (!e) e = window.event;
  
    // Notes:
    // pageY    vertical coordiante according to document
    // clientY  vertical coordiante according to client area = current window
    // screenY  vertical coordiante according to user's computer screen
    if (e.pageX || e.pageY) {
      console.log("*** detected page positions ***");
      posx = e.pageX;
      posy = e.pageY;
    } else if (e.clientX || e.clientY) {
      console.log("*** using client positions ***");
      posx = e.clientX + document.body.scrollLeft + 
                         document.documentElement.scrollLeft;
      posy = e.clientY + document.body.scrollTop + 
                         document.documentElement.scrollTop;
    }
    return { x: posx, y: posy };
  }

  // Put menu in correct position - where the click event was triggered.
  // can be called using menu, tmenu or historydisplay
  // clickPosition is a global variable.
  //function positionMenu(clickPosition, thismenu) {
  function positionMenu(thismenu) {
    var clickCoords = clickPosition;
    var clickCoordsX = clickCoords.x;
    var clickCoordsY = clickCoords.y;
    
    var menuWidth = thismenu.offsetWidth + 4;
    var menuHeight = thismenu.offsetHeight + 4;
    var windowWidth = window.innerWidth;
    // This relates to window height which fails when document is higher than window
    //var windowHeight = window.innerHeight;
    // Hopefully this will be better!!!!
    var windowHeight = document.documentElement.scrollHeight;
    thismenu.style.position="absolute";
    if ( (windowWidth - clickCoordsX) < menuWidth ) {
      thismenu.style.left = windowWidth - menuWidth + "px";
    } else {
      thismenu.style.left = clickCoordsX + "px";
    }
    
    if ( (windowHeight - clickCoordsY) < menuHeight ) {
      thismenu.style.top = windowHeight - menuHeight + "px";
    } else {
      thismenu.style.top = clickCoordsY + "px";
    }
    console.log(thismenu);
  }

//------------------------ End of Context Menu -----------------------------


//----------------- Get history of Tutor or Student ------------------------
  //This function is called to get a student or tutor history
  //Does ajax to get the student or tutor history
  function getHistory(domchange){
    console.log("getHistory called");
    console.log(domchange);
    // domchange['action']      = thisChoice;
    // domchange['move_ele_id'] = thisEleId;
    var recordtype = getRecordType(domchange['move_ele_id']);  // s or t
    var personid = getRecordId(domchange['move_ele_id']);      // record id
    var persontype, myurl;
    var mydata = {'domchange' : domchange};
    console.log("move_ele_id: " + domchange['move_ele_id']);
    console.log("personid: " + personid);

    if( 's' == recordtype ){    // student
      persontype = 'student';
      console.log("we have a student - " + personid);
      myurl = myhost + "/students/history/" + personid;   // skc = status, kind, comment
    } else if( 't' == recordtype ){   // tutor
      persontype = 'tutor';
      console.log("we have a tutor - " + personid);
      myurl = myhost + "/tutors/history/" + personid;   // skc = status, kind, comment
    } else {
      console.log("error - request is not a tutor or student");
      return;
    }
    console.log("now make the ajax call");
    console.log("url: " + myurl);
    $.ajax({
        type: "GET",
        url: myurl,
        data: mydata,
        dataType: "json",
        context: domchange,

        success: function(data, textStatus, xhr){
          console.log("ajax call successful");
          showhistory(data);
        },
        error: function(xhr){
            //$(this).addClass( "processingerror" );
            var errors = $.parseJSON(xhr.responseText);
            var error_message = "";
            for (var error in (errors['person_id'])){
              error_message += " : " + errors['person_id'][error];
            }
            alert('error fetching history for ' + 
                   persontype + ': ' + error_message);
        }
     });
  }


  function showhistory(historydata){
    var template_ele = document.getElementById("history-template");
    var this_ele = template_ele.cloneNode(true);
    this_ele.id = 'history-' + historydata['role'] + historydata['id'];
    this_ele.innerHTML = historyToHtml(historydata);
    template_ele.after(this_ele);
    var historyDisplay = this_ele;
    positionMenu(historyDisplay);
    $("#" + this_ele.id).resizable({handles: "e"});
    this_ele.classList.remove('hideme');
  }

  // As this history element is added after the page load,
  // the click event is not attached.
  // Event delegation addresses this issue. Disccussed in:
  // https://learn.jquery.com/events/event-delegation/
  $(".histories").on('click', '#closehistory' , function() {
    console.log("closing history clicked");
    $(this).parent("div").remove();
  });

  // convert historydata to a HTML segment
  function historyToHtml(hd){
    var role = hd['role'];
    var htmlsegment = "<h4>" + role + ': ' + hd['pname'] + "</h4>";
    htmlsegment += '<div id="closehistory"><svg height="300" width="300"><line x1="1" y1="1" x2="15" y2="15" style="stroke:#000; stroke-width:4" /><line x1="15" y1="1" x2="1" y2="15" style="stroke:#000; stroke-width:4" /></svg></div>';
    htmlsegment += "<table>";
    htmlsegment += "<tr><td>Kind</td><td>Status</td><td>Day Time</td><td>Site</td><td>With</td></tr>";
    hd['lessons'].forEach( function(lesson){
        htmlsegment += "<td>" + lesson['kind'] + "</td>";
        htmlsegment += "<td>" + lesson['status'] + "</td>";
        htmlsegment += "<td>" + lesson['daytime'] + "</td>";
        htmlsegment += "<td>" + lesson['site'] + "</td>";

        if(role == 'student'){
          htmlsegment += "<td>";
            lesson['tutors'].forEach( function(tutor){
              htmlsegment += tutor.tutor + "<br>";
            });
          htmlsegment += "</td>";
        }

        if(role == 'tutor'){
          htmlsegment += "<td>";
            lesson['students'].forEach( function(student){
              htmlsegment += student.student + "<br>";
            });
          htmlsegment += "</td>";
        }
        
      htmlsegment += "</tr>";
    });
    htmlsegment += "</table>";
    return htmlsegment;
  }


//----- Update Tutor, Student or Lesson -> Status, Kind or Comment ----------
  //This function is called to update a student or tutor record
  // with one of status, kind or comment. 
  // Called from the tertiary context menu.
  //Does ajax to update the student or tutor record
  function personupdatestatuskindcomment( domchange ){
    // domchange['action']      = thisChoice;
    // domchange['move_ele_id'] = thisEleId;
    console.log("personupdatestatuskindcomment called");
    console.log(domchange);
    var mydata = {'domchange' : domchange};
    var action = domchange['action'];   //update status or kind with value
    console.log("action: " + action);
    var recordtype = getRecordType(domchange['move_ele_id']);  // s or t
    var personid = getRecordId(domchange['move_ele_id']);      // record id
    // Need to determine the context - index or lession
    var thisEle = document.getElementById(domchange['move_ele_id']);
    var lessonid;
    var personContext = '';
    if(clickInsideElementClassList2(thisEle, ['index'])){
      personContext = 'index';
    } else {
      personContext = 'lesson';
      lessonid = getLessonIdFromTutorStudent(domchange['move_ele_id']);
      mydata['lesson_id'] = lessonid;
    }
    var persontype, myurl;
    var workaction, t, updatefield, updatevalue;
    console.log("move_ele_id: " + domchange['move_ele_id']);
    console.log("personid: " + personid);
    console.log("lessonid: " + lessonid);
    if( 's' == recordtype ){    // student
      persontype = 'student';
      console.log("we have a student - " + personid);
      // action = "student-status-deal"
      // var updatefield = 'status';
      // var updatevalue = 'deal';
      // Note - variable 'workaction' is detroyed in this process
      workaction = action;
      t = /^\w+-/.exec(workaction);
      workaction = workaction.replace(t[0], '');
      t = /^\w+-/.exec(workaction);
      updatefield = t[0]; 
      workaction = workaction.replace(updatefield, '');
      updatefield = updatefield.replace('-', '');
      updatevalue =  workaction;
      // comment field is slightly different.
      if (updatefield == 'comment' ||
          updatefield == 'subject'){    
        updatevalue = domchange['new_value'];
      }
      domchange["new_value"] = updatevalue;
      // translate from browser name to db name
      // subject -> study
      if (updatefield == 'subject') {
        updatefield = 'study';
      } 
      mydata[updatefield] = updatevalue;
      mydata['student_id'] = personid;
      if ( personContext == 'lesson') {
        myurl = myhost + "/studentupdateskc";   // skc = status, kind, comment
      } else {        // index
        myurl = myhost + "/studentdetailupdateskc";   // +subject
      }
    } else if( 't' == recordtype ){   // tutor
      persontype = 'tutor';
      console.log("we have a tutor - " + personid);
      // action = "tutor-status-deal"
      // var updatefield = 'status';
      // var updatevalue = 'deal';
      // Note - variable 'workaction' is detroyed in this process
      workaction = action;
      t = /^\w+-/.exec(workaction);
      workaction = workaction.replace(t[0], '');
      t = /^\w+-/.exec(workaction);
      updatefield = t[0]; 
      workaction = workaction.replace(updatefield, '');
      updatefield = updatefield.replace('-', '');
      updatevalue =  workaction;
      // comment field is slightly different.
      if (updatefield == 'comment' ||
          updatefield == 'subject'){    
        updatevalue = domchange['new_value'];
      }
      domchange["new_value"] = updatevalue;
      // translate from browser name to db name
      // subject -> subjects
      if (updatefield == 'subject') {
        updatefield = 'subjects';
      } 
      mydata[updatefield] = updatevalue;
      mydata['tutor_id'] = personid;
      if ( personContext == 'lesson') {
        myurl = myhost + "/tutorupdateskc";   // skc = status, kind, comment
      } else {        // index
        myurl = myhost + "/tutordetailupdateskc";   // + subject
      }
    } else if( 'n' == recordtype ){   // lesson
      persontype = 'lesson';
      console.log("we have a lesson - " + personid);
      // action = "lesson-status-oncall"
      // var updatefield = 'status';
      // var updatevalue = 'oncall';
      // Note - variable 'workaction' is detroyed in this process
      workaction = action;
      t = /^\w+-/.exec(workaction);
      workaction = workaction.replace(t[0], '');
      t = /^\w+-/.exec(workaction);
      updatefield = t[0]; 
      workaction = workaction.replace(updatefield, '');
      updatefield = updatefield.replace('-', '');
      updatevalue =  workaction;
      // comment field is slightly different.
      if (updatefield == 'comment'){    
        updatevalue = domchange['new_value'];
        mydata['comments'] = updatevalue;
      }else{
        mydata[updatefield] = updatevalue;
      }
      domchange["new_value"] = updatevalue;
      mydata['lesson_id'] = personid;
      myurl = myhost + "/lessonupdateskc";   // skc = status, kind, comment
    } else {
      console.log("error - the record being updated is not a tutor, student or lesson");
      return;
    }
    console.log("now make the ajax call");
    console.log("url: " + myurl);
    $.ajax({
        type: 'POST',
        url: myurl,
        data: mydata,
        dataType: "json",
        context: domchange,

        success: function(){
          console.log("ajax call successful");
            updatestatuskindelement(domchange);
        },
        error: function(xhr){
            //$(this).addClass( "processingerror" );
            var errors = $.parseJSON(xhr.responseText);
            var error_message = "";
            for (var error in (errors['person_id'])){
              error_message += " : " + errors['person_id'][error];
            }
            alert('error updating ' + persontype +
                  ' '  + updatefield + ': ' + error_message);
        }
     });
  }

  // This updates the dom model with the changes applied
  // to the database.
  function updatestatuskindelement(domchange){
    console.log("------------- updatestatuskindelement ------------------");
    console.log(domchange);
    // changing the location of storing colour classes
    // moving to tutor div from previous name and comment divs
    // for testing keep both options - switch between them
    //var testnewformat = true;  // true or false
    
    var updateaction = domchange['action'];
    var t = /^\w+-/.exec(updateaction);
    updateaction = updateaction.replace(t[0], '');
    t = /^\w+-/.exec(updateaction);
    var scmType = t[0]; 
    updateaction = updateaction.replace(scmType, '');
    scmType = scmType.replace('-', '');
    var scmValue =  updateaction;
    var recordtype = getRecordType(domchange["move_ele_id"]);  // s or t
    var this_ele = document.getElementById(domchange["move_ele_id"]);

    if(clickInsideElementClassList2(this_ele, ['index'])){ // index context
      var personContext = 'index';
      var personId = this_ele.id;
      if (scmType == 'comment') {
        if (recordtype == 't') {        // tutor
          var comment_ele = this_ele.getElementsByClassName("tutorcommentdetail")[0];
        }else if (recordtype == 's'){   // student
          comment_ele = this_ele.getElementsByClassName("studentcommentdetail")[0];
        }
        //var comment_text_new = domchange["new_value"];
      } else if (scmType == 'subject') {
        if (recordtype == 't') {        // tutor
          var subject_ele = this_ele.getElementsByClassName("tutorsubjects")[0];
          var subject_text_new = domchange["new_value"];
        }else if (recordtype == 's'){   // student
          // student subject consist of added sex (optional) + year 
          subject_ele = this_ele.getElementsByClassName("studentsubjects")[0];
          var subject_text_old = subject_ele.innerHTML;
          var res = subject_text_old.split("|");
          subject_text_new = res[0] + "| " + domchange["new_value"];
        }
      }
    } else {   // lesson (or schedule) context
      personContext = 'lesson';
      comment_ele = this_ele.getElementsByClassName("comment")[0];
      // some variables are only valid in this context
      var statusinfoele = this_ele.getElementsByClassName("statusinfo")[0];
    }

    var foundClass = false;    
    var searchForClass, these_classes, kindtext, statusinfo, statustext;
    var comment_text_eles;
    
    // Let's just do tutor
    if(recordtype == 't'){
      searchForClass = "t-" + scmType + "-";
      var tutorname_eles = this_ele.getElementsByClassName("tutorname");
      // First update the classes - this controls the status colour
      if (scmType == 'kind') {   // only impact the class in comments
        //if (testnewformat) {  // new style      
          // have to update the 'tutor' div with the 't-status-' class
          var changeclass_ele = this_ele;
          
        //}else{    // textnewformat = false (old style)  
          // have to update the 'tutorcomment' div with the 't-status-' class
          //changeclass_ele = comment_ele;
        //}
        these_classes = changeclass_ele.classList;
        // scan these classes for our class of interest
        these_classes.forEach(function(thisClass, index, array){
          if (thisClass.includes(searchForClass)) {     // t-kind-
            // as we are updating, remove this class and add the corrected class
            foundClass = true;
            changeclass_ele.classList.remove(thisClass);
            changeclass_ele.classList.add(searchForClass + scmValue);
          }
        });
        if(foundClass == false){    // if class was not found
          changeclass_ele.classList.add(searchForClass + scmValue); // add it
        }
/*
        these_classes = comment_ele.classList;
        // scan these classes for our class of interest
        these_classes.forEach(function(thisClass, index, array){
          if (thisClass.includes(searchForClass)) {     // t-kind-
            // as we are updating, remove this class and add the corrected class
            foundClass = true;
            comment_ele.classList.remove(thisClass);
            comment_ele.classList.add(searchForClass + scmValue);
          }
        });
        if(foundClass == false){    // if class was not found
          comment_ele.classList.add(searchForClass + scmValue); // add it
        }
*/
        statusinfo = statusinfoele.innerHTML;
        kindtext = /Kind: \w*/.exec(statusinfo);
        statusinfo = statusinfo.replace(kindtext, 'Kind: ' + scmValue + ' ');
        statusinfoele.innerHTML = statusinfo;
      } else if (scmType == 'status') {    // only impact the class in tutorname
        //if (testnewformat) {  // new style      
          // have to update the 'tutor' div with the 't-status-' class
          var changeclass_ele = this_ele;
          
        //}else{    // textnewformat = false (old style)  
          // have to update the 'tutorname' div with the 't-status-' class
          //changeclass_ele = tutorname_eles[0];
        //}
        these_classes = changeclass_ele.classList;
        // scan these classes for our class of interest
        these_classes.forEach(function(thisClass, index, array){
          if (thisClass.includes(searchForClass)) {     // t-status-
            // as we are updating, remove this class and add the corrected class
            foundClass = true;
            changeclass_ele.classList.remove(thisClass);
            changeclass_ele.classList.add(searchForClass + scmValue);
          }
        });
        if(foundClass == false){    // if class was not found
          changeclass_ele.classList.add(searchForClass + scmValue); // add it
        }
        statusinfo = statusinfoele.innerHTML;
        // we have an issue when status and kind are blank = 'Status: Kind: '
        // statustext = /Status: \w*/.exec(statusinfo);  // replace this to resolve
        kindtext = /Kind: \w*/.exec(statusinfo);
        var temptext = statusinfo.replace(kindtext, '');
        statustext = /Status: \w*/.exec(temptext);
        statusinfo = statusinfo.replace(statustext, 'Status: ' + scmValue + ' ');
        statusinfoele.innerHTML = statusinfo;
      } else if (scmType == 'comment') {  // update the comment
        if (personContext == 'index') {
          // Update the tutor detail comment, then update all the sheet with this commment 
          // update comment in the index area (top of page)
          //comment_text_eles = comment_ele.getElementsByClassName("tutorcommentdetail");
          comment_ele.innerHTML = domchange["new_value"];
          // now the rest of the sheet
          var tutor_lesson_eles = document.getElementsByClassName("f" + domchange["move_ele_id"]);
          //tutor_lesson_eles.forEach(function(lele) { // lesson element
          for (let i = 0; i < tutor_lesson_eles.length; i++) {
            console.log(tutor_lesson_eles[i]);
            comment_text_eles = tutor_lesson_eles[i].getElementsByClassName("tutorcommentdetail");
            comment_text_eles[0].innerHTML = domchange["new_value"];
          }
        } else {    // lesson
          // Now to update the comment with tutrole comment
          comment_text_eles = comment_ele.getElementsByClassName("tutrolecomment");
          comment_text_eles[0].innerHTML = domchange["new_value"];
        }
      } else if (scmType == 'subject') {  // update the tutor subject
        if (personContext == 'index') { 
          // Update the tutor subject, then update all the sheet with this commment 
          // update subject in the index area (top of page)
          //var subject_text_eles = subject_ele.getElementsByClassName("tutorsubjects");
          //subject_text_eles[0].innerHTML = subject_text_new;
          subject_ele.innerHTML = subject_text_new;
          // now the rest of the sheet
          tutor_lesson_eles = document.getElementsByClassName("f" + domchange["move_ele_id"]);
          for (let i = 0; i < tutor_lesson_eles.length; i++) {
            console.log(tutor_lesson_eles[i]);
            subject_text_eles = tutor_lesson_eles[i].getElementsByClassName("tutorsubjects");
            subject_text_eles[0].innerHTML = subject_text_new;
          }
        }
      }
    }

    // Now do the student
    if(recordtype == 's'){
      searchForClass = "s-" + scmType + "-";
      var studentname_eles = this_ele.getElementsByClassName("studentname");
      // First update the classes - this controls the status colour
      if (scmType == 'kind') {   // only impact the class in comments
      
        //if (testnewformat) {  // new style      
          // have to update the 'tutor' div with the 't-status-' class
          changeclass_ele = this_ele;
          
        //}else{    // textnewformat = false (old style)  
          // have to update the 'tutorcomment' div with the 't-status-' class
          //changeclass_ele = comment_ele;
        //}
        these_classes = changeclass_ele.classList;
        // scan these classes for our class of interest
        these_classes.forEach(function(thisClass, index, array){
          if (thisClass.includes(searchForClass)) {     // t-kind-
            // as we are updating, remove this class and add the corrected class
            foundClass = true;
            changeclass_ele.classList.remove(thisClass);
            changeclass_ele.classList.add(searchForClass + scmValue);
          }
        });
        if(foundClass == false){    // if class was not found
          changeclass_ele.classList.add(searchForClass + scmValue); // add it
        }

      
/*      
        these_classes = comment_ele.classList;
        // scan these classes for our class of interest
        these_classes.forEach(function(thisClass, index, array){
          if (thisClass.includes(searchForClass)) {     // t-kind-
            // as we are updating, remove this class and add the corrected class
            foundClass = true;
            comment_ele.classList.remove(thisClass);
            comment_ele.classList.add(searchForClass + scmValue);
          }
        });
        if(foundClass == false){    // if class was not found
          comment_ele.classList.add(searchForClass + scmValue); // add it
        }
*/
        statusinfo = statusinfoele.innerHTML;
        kindtext = /Kind: \w*/.exec(statusinfo);
        statusinfo = statusinfo.replace(kindtext, 'Kind: ' + scmValue + ' ');
        statusinfoele.innerHTML = statusinfo;
      } else if (scmType == 'status') {    // only impact the class in studentname
        //if (testnewformat) {  // new style      
          // have to update the 'tutor' div with the 't-status-' class
          changeclass_ele = this_ele;
          
        //}else{    // textnewformat = false (old style)  
          // have to update the 'tutorcomment' div with the 't-status-' class
          //changeclass_ele = studentname_eles[0];
        //}

        // have to update the 'studentname' div with the 't-status-' class
        var studentname_ele = studentname_eles[0];
        these_classes = changeclass_ele.classList;
        // scan these classes for our class of interest
        these_classes.forEach(function(thisClass, index, array){
          if (thisClass.includes(searchForClass)) {     // t-status-
            // as we are updating, remove this class and add the corrected class
            foundClass = true;
            changeclass_ele.classList.remove(thisClass);
            changeclass_ele.classList.add(searchForClass + scmValue);
          }
        });
        if(foundClass == false){    // if class was not found
          changeclass_ele.classList.add(searchForClass + scmValue); // add it
        }

/*
        var studentname_ele = studentname_eles[0];
        these_classes = studentname_ele.classList;
        // scan these classes for our class of interest
        these_classes.forEach(function(thisClass, index, array){
          if (thisClass.includes(searchForClass)) {     // t-status-
            // as we are updating, remove this class and add the corrected class
            foundClass = true;
            studentname_ele.classList.remove(thisClass);
            studentname_ele.classList.add(searchForClass + scmValue);
          }
        });
        if(foundClass == false){    // if class was not found
          studentname_ele.classList.add(searchForClass + scmValue); // add it
        }
*/
        statusinfo = statusinfoele.innerHTML;
        //statustext = /Status: \w*/.exec(statusinfo); // see student notes
        kindtext = /Kind: \w*/.exec(statusinfo);
        temptext = statusinfo.replace(kindtext, '');
        statustext = /Status: \w*/.exec(temptext);
        statusinfo = statusinfo.replace(statustext, 'Status: ' + scmValue + ' ');
        statusinfoele.innerHTML = statusinfo;
      } else if (scmType == 'comment') {  // update the role comment
        if (personContext == 'index') {
          // Update the student detail comment, then update all the sheet with this commment 
          // update comment in the index area (top of page)
          //comment_text_eles = comment_ele.getElementsByClassName("studentcommentdetail");
          comment_ele.innerHTML = domchange["new_value"];
          // now the rest of the sheet
          var student_lesson_eles = document.getElementsByClassName("f" + domchange["move_ele_id"]);
          for (let i = 0; i < student_lesson_eles.length; i++) {
            console.log(student_lesson_eles[i]);
            comment_text_eles = student_lesson_eles[i].getElementsByClassName("studentcommentdetail");
            comment_text_eles[0].innerHTML = domchange["new_value"];
          }
        } else {    // lesson
          // Now to update the comment with tutrole comment
          comment_text_eles = comment_ele.getElementsByClassName("rolecomment");
          comment_text_eles[0].innerHTML = domchange["new_value"];
        }
      } else if (scmType == 'subject') {  // update the tutor subject
        if (personContext == 'index') { 
          // Update the student subject, then update all the sheet with this commment 
          // update subject in the index area (top of page)
          //var subject_text_eles = subject_ele.getElementsByClassName("studentsubjects");
          //subject_text_eles[0].innerHTML = " " + subject_text_new;
          subject_ele.innerHTML = subject_text_new;
          // now the rest of the sheet
          student_lesson_eles = document.getElementsByClassName("f" + domchange["move_ele_id"]);
          for (let i = 0; i < student_lesson_eles.length; i++) {
            console.log(student_lesson_eles[i]);
            var subject_text_eles = student_lesson_eles[i].getElementsByClassName("studentsubjects");
            subject_text_eles[0].innerHTML = subject_text_new;
          }
        }
      }
    }    
    
    // Now do the lesson
    if(recordtype == 'n'){
      searchForClass = "n-" + scmType + "-";
      comment_ele = this_ele.getElementsByClassName("lessoncomment")[0];
      // First update the classes - this controls the status colour
      if (scmType == 'status') {    // only impact the class in lesson
        // have to update the 'lesson' div with the 't-status-' class
        these_classes = this_ele.classList;
        // scan these classes for our class of interest
        these_classes.forEach(function(thisClass, index, array){
          if (thisClass.includes(searchForClass)) {     // t-status-
            // as we are updating, remove this class and add the corrected class
            foundClass = true;
            this_ele.classList.remove(thisClass);
            this_ele.classList.add(searchForClass + scmValue);
          }
        });
        if(foundClass == false){    // if class was not found
          this_ele.classList.add(searchForClass + scmValue); // add it
        }
        statusinfoele = comment_ele.getElementsByClassName("lessonstatusinfo")[0];
        statusinfo = statusinfoele.innerHTML;
        statustext = /Status: \w*/.exec(statusinfo);
        statusinfo = statusinfo.replace(statustext, 'Status: ' + scmValue + ' ');
        statusinfoele.innerHTML = statusinfo;
      } else if (scmType == 'comment') {  // update the role comment
        // Now to update the comment with tutrole comment
        var comment_text_ele = comment_ele.getElementsByClassName("lessoncommenttext")[0];
        comment_text_ele.innerHTML = domchange["new_value"];
      }
    }    

  }
  // ------------------------- Draggable History -----------------------------   
  // Draggable history container
    $(".histories").on('mouseover', '.history', function(){
      $(this).draggable();
    });

//------------------------ Drag and Drop -----------------------------------
// This is the drag and drop code
// which uses ajax to update the database
// the drag reverts if database update fails.
// good intro document: 
// https://www.elated.com/articles/drag-and-drop-with-jquery-your-essential-guide/

  // for moving the lessons
  function elementdraggable(myelement){
    $(myelement).draggable({
      revert: true,
      zIndex: 100,
      //comments display on click, remove when begin the drag
      start: function(event, ui) {
        $('#comments').css('visibility', 'hidden');  
      }
    });
  }

  function slotdroppable(myelement){
    $(myelement).droppable({
      accept: ".lesson",
      drop: function( event, ui ) {
        var dom_change = {};
        dom_change['action'] = "move";
        dom_change['move_ele_id'] = ui.draggable.attr('id');
        dom_change['ele_old_parent_id'] = document.getElementById(dom_change['move_ele_id']).parentElement.id;
        dom_change['ele_new_parent_id'] = this.id;
        dom_change['element_type'] = "lesson";

        lessonupdateslot( dom_change );
        $( this )
          .removeClass( "my-over" );
      },
      over: function( event, ui ) {
        $( this )
          .addClass( "my-over" );
      },
      out: function( event, ui ) {
        $( this )
          .removeClass( "my-over" );
      }
    });
  }

  elementdraggable(".lesson");
  slotdroppable(".slot");

  // for moving tutors and students.
  function lessondroppable(myelement){
    $(myelement).droppable({
      accept: ".student, .tutor",
      drop: function( event, ui ) {
        var this_move_element = document.getElementById(ui.draggable.attr('id'));
        var dom_change = {};
        dom_change['action'] = "move";
        dom_change['move_ele_id'] = ui.draggable.attr('id');
        dom_change['ele_new_parent_id'] = this.id;
        //dom_change['ele_old_parent_id'] = clickInsideElementClassList2(document.getElementById(dom_change['move_ele_id']), ['lesson']).id;
        if(clickInsideElementClassList2(this_move_element, ['index'])){
          dom_change['action'] = "copy";
          //dom_change['ele_old_parent_id'] = this_move_element.parentElement.id; 
        } else {
          dom_change['ele_old_parent_id'] = 
          clickInsideElementClassList2(document.getElementById(dom_change['move_ele_id']),
                                       ['lesson']).id;
        }
        var type = getRecordType(dom_change['move_ele_id']);
        if(type == 's'){
          dom_change['element_type'] = "student";
        } else if(type == 't') {
          dom_change['element_type'] = "tutor";
        } else {
          dom_change['element_type'] = "";
        }

        personupdateslesson( dom_change );

        $( this )
          //.append(ui.draggable)
          .removeClass( "my-over" );
          //.addClass( "ui-state-highlight" );
      },
      over: function( event, ui ) {
        $( this )
          .addClass( "my-over" );
      },
      out: function( event, ui ) {
        $( this )
          .removeClass( "my-over" );
      }
    });
  }
  
  elementdraggable(".student, .tutor");
  lessondroppable(".lesson");
  
//------------------------ End of Drag and Drop ----------------------------

//----- Common Functions used by both Drag & Drop and Context Menu ---------

  // delete one of tutor, student or lesson. 
  function deleteentry( domchange ){
    console.log("deleteentry called");
    console.log(domchange);
    var itemid = getRecordId(domchange['move_ele_id']);
    var oldparentid = getRecordId(domchange['ele_old_parent_id']);
    console.log("eleid full: " + domchange['move_ele_id']);
    var itemtype = getRecordType(domchange['move_ele_id']);
    if( 'n' == itemtype ){ //lesson
      console.log("we have a lesson - " + itemid);
      var mytype = 'DELETE';
      //var myurl = "https://bit3-micmac.c9users.io/lessons/" + parseInt(itemid, 10);
      var myurl = myhost + "/lessons/" + parseInt(itemid, 10);
      var mydata =  { 'domchange'      : domchange };
    } else if( 't' == itemtype ){  // tutor
      console.log("we have a tutor - " + itemid);
      mytype = 'POST';
      //myurl = "https://bit3-micmac.c9users.io/removetutorfromlesson";
      myurl = myhost + "/removetutorfromlesson";
      mydata =  { 'tutor_id'     : itemid, 
                  'old_lesson_id' : oldparentid,
                  'domchange'      : domchange 
                };
    } else if( 's' == itemtype ){  // student
      console.log("we have a student- " + itemid);
      //myurl = "https://bit3-micmac.c9users.io/removestudentfromlesson";
      myurl = myhost + "/removestudentfromlesson";
      mytype = 'POST';
      mydata =  { 'student_id'     : itemid, 
                  'old_lesson_id' : oldparentid,
                  'domchange'      : domchange 
                };
    }
    console.log("myurl: " + myurl);
    $.ajax({
        type: mytype,
        url: myurl,
        data: mydata,
        dataType: "json",
        context: domchange,
        success: function(){
            console.log("done - deleted lesson " + itemid );
            deleteelement(domchange);
        },
        error: function(request, textStatus, errorThrown){
            //$(this).addClass( "processingerror" );
            console.log("ajax error occured: " + request.status.to_s + " - " + textStatus );
            alert("ajax error occured: " + request.status.to_s + " - " + textStatus );
        }
    });
    //data: {lesson : {'slot_id' : slotid }, 'domchange' : domchange },
  }

  function deleteelement( domchange ){
    //  action:             "move"
    //  ele_new_parent_id:  "Wod201705291630l002"  -- slot
    //  ele_old_parent_id:  "Wod201705291600l001"  -- slot
    //  move_ele_id:        "Wod201705291600n003"  -- lesson
    console.log("called deleteelement");
    console.dir(domchange);
    var eleid = domchange['move_ele_id'];
    console.log("deleteelement - id: " + eleid);
    var eledelete = document.getElementById(eleid);
    eledelete.remove();
  }

  //This function is called for either move or copy
  //Does ajax to move or copy a student or tutor to another lesson
  function personupdateslesson( domchange ){
    console.log("personupdatelesson called");
    console.log(domchange);
    var action = domchange['action'];   //move or copy
    var personid = getRecordId(domchange['move_ele_id']);
    var newlessonid = getRecordId(domchange['ele_new_parent_id']);
    if(oldlessonid == newlessonid){
      //alert("You dropped this item in the same location!!!");
      return;
    }
    console.log("personid: " + domchange['move_ele_id']);
    var myurl;
    var mydata;
    var recordtype = getRecordType(domchange['move_ele_id']);
    if( 's' == recordtype ){    //student
      console.log("we have a student - " + personid);
      console.log("action: " + action);
      mydata =  { 'student_id'     : personid, 
                  'new_lesson_id' : newlessonid,
                  'domchange'      : domchange 
                };
      if(action == "move") {   
        myurl = myhost + "/studentmovelesson/";
        var oldlessonid = getRecordId(domchange['ele_old_parent_id']);
        mydata['old_lesson_id'] =  oldlessonid;
      } else if(action == "copy"){ // copy
        myurl = myhost + "/studentcopylesson/";
      }
    } else if( 't' == recordtype ){   //tutor
      console.log("we have a tutor - " + personid);
      mydata =  { 'tutor_id'       : personid, 
                  'new_lesson_id' : newlessonid,
                  'domchange'      : domchange                  
                };
      if(action == "move") {
        var oldlessonid = getRecordId(domchange['ele_old_parent_id']);
        mydata['old_lesson_id'] =  oldlessonid;
        myurl = myhost + "/tutormovelesson/";
      } else { // copy
        myurl = myhost + "/tutorcopylesson/";
      }
      
    } else {
      console.log("error - the moving person is not a tutor or student");
      return;
    }
    console.log("now make the ajax call");
    console.log("url: " + myurl);
    $.ajax({
        type: "POST",
        url: myurl,
        data: mydata,
        dataType: "json",
        context: domchange,

        success: function(){
          console.log("ajax call successful");
            moveelement(domchange);
        },
        error: function(xhr){
            //$(this).addClass( "processingerror" );
            var errors = $.parseJSON(xhr.responseText);
            var error_message = "";
            for (var error in (errors['lesson_id'])){
              error_message += " : " + errors['lesson_id'][error];
            }
            alert("error moving student or tutor to another lesson: " + error_message);
        }
     });
  }

  function addLesson(domchange){
    console.log("calling addLesson");
    console.log(domchange);
    var newslotid = getRecordId(domchange['ele_new_parent_id']);
    domchange["status"] = "standard";
    //var myurl = "https://bit3-micmac.c9users.io/lessons/"
    var myurl = myhost + "/lessons/";
    console.log("about to call ajax for addLesson")
    $.ajax({
        type: "POST",
        url: myurl,
        data: {lesson : {'slot_id' : newslotid, 'status' : domchange["status"] },
                         'domchange' : domchange },
        dataType: "json",
        context: domchange,
        success: function(result){
            console.log("done - ajax added lesson to slot " + newslotid );
            console.log(result);
            console.log("extract the created lesson id: " + result.id );
            var lessonid = result.id;
            //ele_new_parent_id:"Wod201705291600l001"
            var slotid = domchange['ele_new_parent_id'];
            console.log("slotid: " + slotid + " lessonid: " + lessonid);
            var lessonid_base = slotid.substr(0, slotid.length-sf-1 );
            var paddedid = padleft(lessonid, sf);
            console.log("paddedid: " + paddedid);
            var newlessonid = lessonid_base + "n" + paddedid;
            console.log("newlessonid: " + newlessonid);
            domchange['move_ele_id'] = newlessonid;
            console.log(domchange);
            addelement(domchange);
        },
        error: function(request, textStatus, errorThrown){
            //$(this).addClass( "processingerror" );
            console.log("ajax error occured: " + request.status.to_s + " - " + textStatus );
            alert("ajax error occured: " + request.status.to_s + " - " + textStatus );
        }
    });
  }
  
  function removeLesson(domchange){
    console.log("calling removeLesson");
    console.log(domchange);
    var lessonid = getRecordId(domchange['move_ele_id']);
    //var myurl = "https://bit3-micmac.c9users.io/lessons/" + lessonid
    var myurl = myhost + "/lessons/" + lessonid;
    $.ajax({
        type: "DELETE",
        url: myurl,
        //url: "lessons/" + lessonid,
        data: {'domchange' : domchange },
        dataType: "json",
        context: domchange,
        success: function(result){
            console.log("done - ajax removed lesson" );
            //ele_new_parent_id:"Wod201705291600l001"
            deleteelement(domchange);
        },
        error: function(request, textStatus, errorThrown){
            console.log(request);
            var temp = request.responseJSON.base;
            var errorText = "";
            for(var i=0; i<temp.length; i++){
              errorText += temp[i] + "\n";
            }
            console.log("ajax error occured: " + request.status.to_s + " - " + textStatus  + "\n" + errorText);
            alert("ajax error occured\n" + request.status.to_s + " - " + textStatus + "\n" + errorText);
        }
    });
  }

  function padleft(num, sigfig){
    var numstr = num.toString();
    var temp = "";
    for(var i = sigfig - (numstr.length); i--;){
      temp = temp + "0";
    }
    return temp + numstr;
  }

  //lessonupdateslot( oldslot_id1, slot_id1, lesson_id1, this, ui, domchange );
  function lessonupdateslot( domchange ){
    console.log("calling lessonupdateslot");
    console.log(domchange);
    var lessonid = getRecordId(domchange['move_ele_id']);
    var oldslotid = getRecordId(domchange['ele_old_parent_id']);
    var newslotid = getRecordId(domchange['ele_new_parent_id']);
    if(oldslotid == newslotid){
      //alert("You dropped this item in the same location!!");
      return;
    }
    //var myurl = "https://bit3-micmac.c9users.io/lessons/" + lessonid
    var myurl = myhost + "/lessons/" + lessonid
    $.ajax({
        type: "POST",
        url: myurl,
        data: {lesson : {'slot_id' : newslotid }, 'domchange' : domchange },
        dataType: "json",
        context: domchange,
        success: function(){
            console.log("done - dragged lesson " + lessonid + " to slot " + newslotid + " from " + oldslotid );
            moveelement(domchange);
        },
        error: function(request, textStatus, errorThrown){
            //$(this).addClass( "processingerror" );
            console.log("ajax error occured: " + request.status.to_s + " - " + textStatus );
            alert("ajax error occured: " + request.status.to_s + " - " + textStatus );
        }
    });
  }
  
  // Add a new lesson element to the DOM
  function addelement(domchange){
    console.log("addelement called");
    console.log(domchange);
    //<div class=lesson id=<%= cells["id_dom"] + "n" + entry.id.to_s.rjust(@sf, "0") %> >
    var lessontemplate = document.getElementById("lessontemplate");
    console.log(lessontemplate);
    var newlessonele = lessontemplate.cloneNode(true, true);
    console.log(newlessonele);
    newlessonele.id = domchange['move_ele_id'];
    var parentele = document.getElementById(domchange['ele_new_parent_id']);
    parentele.appendChild(newlessonele);
    newlessonele.classList.remove("hideme");
    // set status
    var status = 'n-status-' + domchange['status'];
    newlessonele.classList.add(status);
    elementdraggable(newlessonele);
    lessondroppable(newlessonele);
    console.log(parentele);
  }

  function moveelement( domchange ){
    //  action:             "move"
    //  ele_new_parent_id:  "Wod201705291630l002"  -- slot
    //  ele_old_parent_id:  "Wod201705291600l001"  -- slot
    //  move_ele_id:        "Wod201705291600n003"  -- lesson
    //console.log("called moveelement");
    //console.dir(domchange);
    var newparentid = domchange['ele_new_parent_id'];
    var moveRecordType = getRecordType(domchange['move_ele_id']);
    var newid = moveRecordType + getRecordId(domchange['move_ele_id']);
    var oldid = domchange['move_ele_id'];
    //console.log("moveelement - oldid: " + oldid + " => newid: " + newid);
    var elemoving = document.getElementById(oldid);
    var directparentclassname = elemoving.parentElement.className;
    // check if being copied from tutor/student lists or within scheduling
    //console.log("***************t: " + moveRecordType);
    switch(moveRecordType) {
      case 't': //tutor
        if(clickInsideElementClassList2(elemoving, ['index'])){
          var sample_tutor = document.getElementsByClassName('schedule')[0].getElementsByClassName('tutor')[0];
          directparentclassname = sample_tutor.parentElement.className;
        }
        newid = newparentid + newid;
        break;
      case 's': //student
        if(clickInsideElementClassList2(elemoving, ['index'])){
          var sample_student = document.getElementsByClassName('schedule')[0].getElementsByClassName('student')[0];
          directparentclassname = sample_student.parentElement.className;
        }
        newid = newparentid + newid;
        break;
      case 'n': //lesson
        newid = newparentid.substr(0, newparentid.length-sf-1) + newid;
        break;
    }
    if ('copy' == domchange['action']){
      var eletoplace = elemoving.cloneNode(true, true);
      elementdraggable(eletoplace);
      if(clickInsideElementClassList2(elemoving, ['index'])){
        // Need to add some more content - status, kind, comments,etc.
        var new_ele1 = document.createElement('div');
        var new_ele2 = document.createElement('div');
        new_ele2.classList.add("statusinfo");
        new_ele2.textContent = "Status: Kind: ";
        var comment_ele = eletoplace.getElementsByClassName('comment')[0];
        var comment_ele_children = comment_ele.children;
        comment_ele.appendChild(new_ele2);
        if( moveRecordType == 't') {   // tutor
          new_ele1.classList.add("tutrolecomment");
        } else if (moveRecordType == 's') {   // student
          new_ele1.classList.add("rolecomment");
        }
        comment_ele.insertBefore(new_ele1, comment_ele_children[1]);
      }
    }else if('move' == domchange['action']){
      eletoplace = elemoving;
    }
    //console.log("----------eletoplace-------");
    //console.log(eletoplace);
    // note thjis parent_element is one of lesson or slot.
    // The actual parent to insert into may be a subset
    // e.e. tutor is actually attached to grouptutors!
    var parent_element = document.getElementById(domchange['ele_new_parent_id']);
    //console.log("------ parent_element ---------");
    //console.log(parent_element);
    switch(moveRecordType) {
      case 't': //tutor
        // get the parent where tutors reside for this lesson.
        //var tutorsparent = parent_element.getElementsByClassName('grouptutors')[0];
        // This caters for differenct class names used for css styling
        // could be grouptutors, grouptutors1 etc. but only one class name for this element.
        var tutorsparent = parent_element.getElementsByClassName(directparentclassname)[0];
        // we really should insert them in correct alphabetical order
        console.log("Show all the tutors for this target node");
        var movetutorname = eletoplace.getElementsByClassName('tutorname')[0].innerHTML;
        var mytutors = tutorsparent.getElementsByClassName('tutor');
        if (mytutors) {    // have tutors
          var flagInserted = false;
          var mytutor;
          console.log (" we have tutors");
          for (let i = 0; i < mytutors.length; i++){
            mytutor = mytutors[i];
            var mytutorname = mytutor.getElementsByClassName('tutorname')[0].innerHTML;
            console.log(mytutorname);
            if (mytutorname.toLowerCase() > movetutorname.toLowerCase()){
              tutorsparent.insertBefore(eletoplace, mytutor);
              flagInserted = true;
              break;
            }
          }
          if(flagInserted == false) {
            tutorsparent.append(eletoplace);
          }
        } else {  // no tutors, just add.
          console.log ("no tutors");
          tutorsparent.insertBefore(eletoplace, tutorsparent.firstChild);
        }
        break;
      case 's': //student
        // get the parent where students reside for this lesson.
        // insert them in correct alphabetical order
        //var studentsparent = parent_element.getElementsByClassName('groupstudents')[0];
        // This caters for differenct class names used for css styling
        // could be groupstudents, groupstudents1 etc. but only one class name for this element.
        var studentsparent = parent_element.getElementsByClassName(directparentclassname)[0];
        var movestudentname = eletoplace.getElementsByClassName('studentname')[0].innerHTML;
        var mystudents = studentsparent.getElementsByClassName('student');
        if (mystudents) {    // have students
          flagInserted = false;
          var mystudent;
          for (let i = 0; i < mystudents.length; i++){
            mystudent = mystudents[i];
            var mystudentname = mystudent.getElementsByClassName('studentname')[0].innerHTML;
            if (mystudentname.toLowerCase() > movestudentname.toLowerCase()){
              studentsparent.insertBefore(eletoplace, mystudent);
              flagInserted = true;
              break;
            }
          }
          if(flagInserted == false) {
            studentsparent.append(eletoplace);
          }
        } else {  // no students in this lesson, just add.
          tutorsparent.insertBefore(eletoplace, tutorsparent.firstChild);
        }
        break;
      case 'n': //lesson
        // lesson is a direct child of slot 
        // so parent_element is correct parent.
        // insert lesson in the correct order.
        // order by status, then by name of first tutor.
        // Tutors are already in alphabetical order.
        var lessonsparent = parent_element;
        var movelessonstatus = eletoplace.getElementsByClassName('lessonstatusinfo')[0].innerHTML.toLowerCase().trim();
        var movelessontutorname = eletoplace.getElementsByClassName('tutor')[0];
        if (movelessontutorname) {
          movelessontutorname = movelessontutorname.getElementsByClassName('tutorname')[0].innerHTML.toLowerCase().trim();
        } else {
          movelessontutorname = '';
        }
        var mylessons = lessonsparent.getElementsByClassName('lesson');
        if (mylessons) {    // have tutors
          flagInserted = false;
          var mylesson;
          for (let i = 0; i < mylessons.length; i++){
            mylesson = mylessons[i];
            var mylessonstatus = mylesson.getElementsByClassName('lessonstatusinfo')[0].innerHTML.toLowerCase().trim();
            var mylessontutorname = mylesson.getElementsByClassName('tutor')[0];
            if (mylessontutorname) {
              mylessontutorname = mylessontutorname.getElementsByClassName('tutorname')[0].innerHTML.toLowerCase().trim();
            } else {
              mylessontutorname = '';
            }

            //if (mylessonstatus > movelessonstatus){
            console.log (movelessonstatus + " " + movelessontutorname + " " + mylessonstatus + " " + mylessontutorname)
            var sortresult = lessonsortorder(movelessonstatus, movelessontutorname, mylessonstatus, mylessontutorname );
            console.log ("sortresult: " + sortresult);
            if (sortresult > -1){
              lessonsparent.insertBefore(eletoplace, mylesson);
              flagInserted = true;
              break;
            }
          }
          if(flagInserted == false) {
            lessonsparent.append(eletoplace);
          }
        } else {  // no lessons in this slot, just add.
          lessonsparent.append(eletoplace);
          //lessonsparent.insertBefore(eletoplace, tutorsparent.firstChild);
        }
        //parent_element.append(eletoplace);
        break;
    }
    // once successfully processed - update the id
    eletoplace.id = newid;

  }
  
  // provides the sort order for lessons within the slot
  // Becomes complicated as teh order is different with postgreql
  // and javascript with stringcomparisions.

  function lessonsortorder(a_status, a_name, b_status, b_name){
    // item1 = [lesson_status, tutor_name]
    // the following statuses must be first on the page
    var baseorder = ['status: oncall', 'status: onsetup', 'status: on_bfl'];
    // all following statuses are in alphabetical order
    // If the session status is the same, then that set
    // are order by alphabetical order of tutor namme of 
    // the first tutor in the session.
    // The tutors within a session are in alphabetical order
    // return -1, 0 or 1

    if(a_status == b_status) {
      // compare names only
      if (a_name == b_name) {
        return 0; 
      } else if (a_name > b_name) {
        return -1;
      } else {
        return 1;
      }
    }
    var aindex = baseorder.indexOf(a_status);
    var bindex = baseorder.indexOf(b_status);
    
    if ((aindex > -1) && (bindex > -1)) {
      console.log ("a_status: " + a_status + " aindex: " + aindex + "b_status: " + b_status + " bindex: " + bindex);
      return (aindex > bindex  ? -1 : 1 ); 
    } 
    if (aindex > -1) {
      console.log ("a_status: " + a_status + " aindex: " + aindex);
      return 1; 
    } 
    if (bindex > -1) {
      console.log ("b_status: " + b_status + " bindex: " + bindex);
      return -1; 
    }
    // if get to here, do normal alphabetical order check on status
    // remember we have already checked for equal status.
    console.log ("a_status: " + a_status + " b_status: " + b_status);
    return (a_status > b_status ? 1 : -1 );

  }

  
  
  

//--- End of Common Functions used by both Drag & Drop and Context Menu ----

//--------- Filter by name functions for the tutors and students -----------


  $("#personInput").keyup(function filterPeople() {
      console.log("filterPeople called");
      var filter, eleIndexTutors, eleTutorNames, eleIndexStudents, eleStudentNames, i, eleAncestor;
      filter = document.getElementById("personInput").value.toUpperCase();
      //console.log("filter: " + filter);
      eleIndexTutors = document.getElementById("index-tutors");
      //console.log(eleIndexTutors);
      if(! eleIndexTutors.classList.contains("hideme")){
        eleTutorNames = eleIndexTutors.getElementsByClassName("tutorname");
        //console.log(eleTutorNames);
        for (i = 0; i < eleTutorNames.length; i++) {
            var tutorNameText = eleTutorNames[i].innerHTML.substr(7).toUpperCase();
            //console.log("tutorNameText: " + tutorNameText);
            eleAncestor = findAncestor (eleTutorNames[i], "tutor");
            //console.log(eleAncestor);
            if (tutorNameText.indexOf(filter) > -1) {
                eleAncestor.style.display = "";
                //console.log("show");
            } else {
                eleAncestor.style.display = "none";
                //console.log("hide");
            }
        }
      }
      console.log("about to process students");
      eleIndexStudents = document.getElementById("index-students");
      //console.log(eleIndexStudents);
      if(! eleIndexStudents.classList.contains("hideme")){
        eleStudentNames = eleIndexStudents.getElementsByClassName("studentname");
        //console.log(eleStudentNames);
        for (i = 0; i < eleStudentNames.length; i++) {
            var studentNameText = eleStudentNames[i].innerHTML.substr(9).toUpperCase();
            //console.log("studentNameText: " + studentNameText);
            eleAncestor = findAncestor (eleStudentNames[i], "student");
            //console.log(eleAncestor);
            if (studentNameText.indexOf(filter) > -1) {
                eleAncestor.style.display = "";
                //console.log("show");
            } else {
                eleAncestor.style.display = "none";
                //console.log("hide");
            }
        }
      }
  });


  function findAncestor (el, cls) {
    while ((el = el.parentElement) && !el.classList.contains(cls));
    return el;
  }

/*
  $("#personInput").keyup(filterPeople());

  function filterPeople() {
      console.log("filterPeople called");
      var filter, eleIndexTutors, eleTutorNames, eleIndexStudents, eleStudentNames, i, eleAncestor;
      filter = document.getElementById("personInput").value.toUpperCase();
      //console.log("filter: " + filter);
      eleIndexTutors = document.getElementById("index-tutors");
      //console.log(eleIndexTutors);
      if(! eleIndexTutors.classList.contains("hideme")){
        eleTutorNames = eleIndexTutors.getElementsByClassName("tutorname");
        //console.log(eleTutorNames);
        for (i = 0; i < eleTutorNames.length; i++) {
            var tutorNameText = eleTutorNames[i].innerHTML.substr(7).toUpperCase();
            //console.log("tutorNameText: " + tutorNameText);
            eleAncestor = findAncestor (eleTutorNames[i], "tutor");
            //console.log(eleAncestor);
            if (tutorNameText.indexOf(filter) > -1) {
                eleAncestor.style.display = "";
                //console.log("show");
            } else {
                eleAncestor.style.display = "none";
                //console.log("hide");
            }
        }
      }
      console.log("about to process students");
      eleIndexStudents = document.getElementById("index-students");
      //console.log(eleIndexStudents);
      if(! eleIndexStudents.classList.contains("hideme")){
        eleStudentNames = eleIndexStudents.getElementsByClassName("studentname");
        //console.log(eleStudentNames);
        for (i = 0; i < eleStudentNames.length; i++) {
            var studentNameText = eleStudentNames[i].innerHTML.substr(9).toUpperCase();
            //console.log("studentNameText: " + studentNameText);
            eleAncestor = findAncestor (eleStudentNames[i], "student");
            //console.log(eleAncestor);
            if (studentNameText.indexOf(filter) > -1) {
                eleAncestor.style.display = "";
                //console.log("show");
            } else {
                eleAncestor.style.display = "none";
                //console.log("hide");
            }
        }
      }
  }

*/

//------ End of Filter by name functions for the tutors and students -------

};

function selectshows() {
  //console.log("processing selectShows");
  var showList = document.getElementById("selectshows").getElementsByTagName("input");
  //console.log(showList);
  //var flagcomments = false;
  // if I have hidden both tutors and students, then also hide "index"
  var flagshowtutorsorstudents = false;
  for(var i = 0; i < showList.length; i++){
    //console.log(showList[i].id);
    //console.log(showList[i].checked);
    switch(showList[i].id){
      case "hidetutors":
        //var eleThisParent = document.getElementById("index-tutors");
        if (showList[i].checked){
          document.getElementById("index-tutors").classList.remove("hideme");
          flagshowtutorsorstudents = true;
        }else{
          document.getElementById("index-tutors").classList.add("hideme");
        }
        break;
      case "hidestudents":
        //var eleThisParent = document.getElementById("index-students");
        if (showList[i].checked){
          document.getElementById("index-students").classList.remove("hideme");
          flagshowtutorsorstudents = true;
        }else{
          document.getElementById("index-students").classList.add("hideme");
        }
        break;
      case "hidecomments":    // will hide all comments
        //flagcomments = true;
        showhidecomments(document.getElementsByClassName("comment"),
        showList[i].checked);
        /*var eleComments = document.getElementsByClassName("comment");
        if (showList[i].checked){
          for (var j=eleComments.length; j-- ; ){
            eleComments[j].classList.add("hideme");
          }
        }else{
          for (var j=eleComments.length; j-- ; ){
            eleComments[j].classList.remove("hideme");
          }
        }*/
        break;
      case "hidetutorlessoncomments":
        //if  (!flagcomments) {   // if all comments selected, stop here
        showhidecomments(document.getElementsByClassName("tutrolecomment"),
        showList[i].checked);
        break;
      case "hidestudentlessoncomments":
        //if  (!flagcomments) {   // if all comments selected, stop here
        showhidecomments(document.getElementsByClassName("rolecomment"),
        showList[i].checked);
        break;
      case "hidetutorcomments":
        showhidecomments(document.getElementsByClassName("tutorcommentdetail"),
        showList[i].checked);
        break;
      case "hidestudentcomments":
        showhidecomments(document.getElementsByClassName("studentcommentdetail"),
        showList[i].checked);
        break;
      default:
        var thispattern = /hide(.*)/;
        console.log("showList[i].id: " + showList[i].id);
        var m = thispattern.exec(showList[i].id);
        if( m ){
          console.log("m: " + m[1]);
          var siteid = 'site-' + m[1];
          console.log("siteid: " + siteid);          
          if (showList[i].checked){
            document.getElementById(siteid).classList.remove("hideme");
          }else{
            document.getElementById(siteid).classList.add("hideme");
          }
        }
    }
    if(flagshowtutorsorstudents){
      document.getElementById('index-tutor-students').classList.remove("hideme");
    }else{
      document.getElementById('index-tutor-students').classList.add("hideme");
    }
  }
}

function showhidecomments(theseelements, tohide) {
  //eleComments = document.getElementsByClassName("studentcommentdetail");
  if (tohide){
    for (var j=theseelements.length; j-- ; ){
      theseelements[j].classList.add("hideme");
    }
  }else{
    for (var j=theseelements.length; j-- ; ){
      theseelements[j].classList.remove("hideme");
    }
  }
}

//$(document).ready(ready);
$(document).on('turbolinks:load', ready);

