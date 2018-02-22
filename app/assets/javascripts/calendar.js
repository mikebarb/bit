/* Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
*/

/* global $ */

$(document).ready(function() {
  //console.log("documentready");  
  
  
  // some global variables for this page
  var sf = 5;     // significant figures for dom id components e.g.lesson ids, etc.
  var myhost = window.location.protocol + '//' + window.location.hostname;   // base url for ajax
  console.log("baseurl: " + myhost);
  
  // this will put obvious border on mouse entering selectable items
  /*$('.lesson').mouseenter(function(){
     $(this).css('border','3px solid black');
  });
  $('.lesson').mouseleave(function(){
    $(this).css('border','0px solid black');
  });
  $('.student').mouseenter(function(){
     $(this).css('border','3px solid blue');
  });
  $('.student').mouseleave(function(){
    $(this).css('border','0px solid blue');
  });
  $('.tutor').hover(function(){
     $(this).css('border','3px solid green');
  });
  $('.tutor').mouseleave(function(){
    $(this).css('border','0px solid green');
  });*/
  
  $("ui-draggable");
  
  // single click will display the comment.
  $('.lesson').mousedown(function(){
    $('.positionable').html("lesson: " + this.id);
    //$(this).css('border','0px solid grey');
    $('.positionable').css('visibility', 'visible');
    $('.positionable').position({
      of: this,
      my: "left top",
      at: "right top",
      collision: "flip flip"
    });
  });
  // remove by clicking on the displayed comment
  $('.positionable').click(function(){
    $('.positionable').css('visibility', 'hidden');
  });
  // hide on load
  $('.positionable').css('visibility', 'hidden');

//------------------------ Context Menu -----------------------------
// This is the context menu for the lesson,
// tutor and student elements.

  var taskItemClassList = ['slot', 'lesson', 'tutor', 'student'];
  var taskItemInContext;  
  var contextMenuActive = "context-menu--active";
  var contextMenuItemClassName = "context-menu__item";
  var menu = document.querySelector("#context-menu");
  var menuState = 0;
  var eleClickedOn;
  var currentActivity = {};
  var stackActivity = [];

  $('.context-menu__item').mouseenter(function(){
    $(this).css('background-color','lime');
  });
  $('.context-menu__item').mouseleave(function(){
    $(this).css('background-color', 'white');
  });


  // Initialise our application's code.
  function init() {
    contextListener();
    clickListener();
    keyupListener();
    resizeListener();
  }

  // Listens for contextmenu events.
  function contextListener() {
    document.addEventListener( "contextmenu", function(e) {
      taskItemInContext = clickInsideElementClassList( e, taskItemClassList);
      if ( taskItemInContext ) {
        console.log("-----taskItemInContext-----should be the element of interest");
        console.log(taskItemInContext);
        console.log("element id: " + taskItemInContext.id);
        e.preventDefault();
        enableMenuItems();
        toggleMenuOn();
        positionMenu(e);
        eleClickedOn = e;
        console.log("----------event clicked on-----------");
        console.log(eleClickedOn);
      } else {
        taskItemInContext = null;
        toggleMenuOff();
      }
    });
  }

  //Listens for click events on context menu items element.
  function clickListener() {
    document.addEventListener( "click", function(e) {
      var clickEleIsAction = clickInsideElementClassList( e, [contextMenuItemClassName]);
  
      if ( clickEleIsAction ) {
        e.preventDefault();
        menuItemActioner( clickEleIsAction );
      } else {
        var button = e.which || e.button;
        if ( button === 1 ) {
          toggleMenuOff();
        }
      }
    });
  }

  // Listens for keyup events on escape key.
  function keyupListener() {
    window.onkeyup = function(e) {
      if ( e.keyCode === 27 ) {
        toggleMenuOff();
      }
    };
  }
  
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
    
    //  var currentActivity = {};   declared globally within this module

    if(currentActivity.action  == 'move' || 
       currentActivity.action  == 'copy'){  // something has been copied ready to be pasted
      scmi_paste = true;
    }

    switch(recordType){
      case 's':   //student
      case 't':   //tutor
        if(clickInsideElementClassList2(thisEle, ['index'])){
          // this element in student and tutor list
          scmi_copy = true;
          scmi_paste = false;   //nothing can be pasted into the index space
        }else{  // in the main schedule
          scmi_copy = scmi_move = scmi_remove = scmi_addLesson = true;
        }
        break;
      case 'n':   //lesson
          scmi_move = scmi_addLesson = true;
          // if there are no tutors or students in this lesson, can remove
          var mytutors = thisEle.getElementsByClassName('tutor'); 
          var mystudents = thisEle.getElementsByClassName('student');
          if(!(mytutors || mystudents)){
            scmi_removeLesson = true;
          }
          break;
    }
    setscmi('context-move', scmi_move);
    setscmi('context-copy', scmi_copy);
    setscmi('context-paste', scmi_paste);
    setscmi('context-remove', scmi_remove);
    setscmi('context-addLesson', scmi_addLesson);
    setscmi('context-removeLesson', scmi_removeLesson);
  } 
  
  function setscmi(elementId, scmi){
    if(scmi){
      document.getElementById(elementId).classList.remove('hideme'); 
    }else{
      document.getElementById(elementId).classList.add('hideme'); 
    }
  }

//***********************************************************************
// Perform the actions invoked by the context menu items.                *
//***********************************************************************
  function menuItemActioner( action ) {
    //dom_change['action'] = "move";
    //dom_change['move_ele_id'] = ui.draggable.attr('id');
    //dom_change['ele_old_parent_id'] = document.getElementById(dom_change['move_ele_id']).parentElement.id;
    //dom_change['ele_new_parent_id'] = this.id;
    //dom_change['element_type'] = "lesson";
    toggleMenuOff();
    console.log("-------------- menu item action passed object ---------------");
    console.log(action);
    var thisAction =  action.getAttribute("data-action");
    var thisEleId = taskItemInContext.id;    // element clicked on
    var thisEle = document.getElementById((thisEleId));
    console.log("thisAction: " + thisAction);
    switch( thisAction ) {
      case "copy":
      case "move":
        console.log("copy or cut");
        currentActivity['action'] = thisAction;
        currentActivity['move_ele_id'] =  thisEleId;
        currentActivity['ele_old_parent_id'] = document.getElementById(thisEleId).parentElement.id;
        console.log("finished the move/copy case processing");
        console.log(currentActivity);
        break;
      case "paste":
        console.log("paste");
        //Note, we need the action for the move/copy, not paste.
        // On dropping, need to move up parent tree till find the appropriate parent
        console.log(currentActivity);
        if( currentActivity ) {   // been a cut or move initiated
          switch ( getRecordType(currentActivity['move_ele_id']) ) {
            case 's':   //student
            case 't':   //tutor
              // find the 'lesson' element in the tree working upwards
              currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['lesson']).id;
              break;
            case 'n':   //lesson
              // find the 'slot' element in the tree working upwards
              currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
              break;
          }
          //******************************************************
          // Need the database changes and manipulation called here
          //******************************************************
          personupdateslesson( currentActivity );
          //----- contained in currentActivity
          //  move_ele_id: "Wod201705301600s002",
          //  ele_old_parent_id: "Wod201705301600n001", 
          //  element_type: "student"
          //  ele_new_parent_id: "Wod201705291630n003"
          //----------required in ajax (domchange)---------------------------------
          currentActivity = {};
        }
        break;
      case "remove":
        // This removed the selected element
        // Actually deletes the mapping record for tutor and student
        // Will delete the lesson record for a lesson if empty.
        currentActivity['action'] = thisAction;
        thisEleId = taskItemInContext.id;
        currentActivity['move_ele_id'] =  thisEleId;
        currentActivity['ele_old_parent_id'] = document.getElementById(thisEleId).parentElement.id;
        deleteentry(currentActivity);
        break;
      case "addLesson":
        // This will add a new lesson within the slot holding the element clicked.
        // Will add a new lesson record with this slot value.
        currentActivity['action'] = thisAction;
        console.log("case = addLesson");
        thisEleId = taskItemInContext.id;
        thisEle = document.getElementById(thisEleId);
        currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
        addLesson(currentActivity);
        break;
      case "removeLesson":
        // This will remove a lesson clicked on.
        currentActivity['action'] = thisAction;
        currentActivity['move_ele_id'] =  thisEleId;
        console.log("case = removeLesson");
        thisEleId = taskItemInContext.id;
        thisEle = document.getElementById(thisEleId);
        currentActivity['ele_old_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
        removeLesson(currentActivity);
        break;
      }
      console.log("--- completed context menu actioner ---");
      console.log("--- currentActivity ---");
      console.log(currentActivity);
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
  
  //On windows screen resize, hides the menu - start selection again 
  function resizeListener() {
    window.onresize = function(e) {
      toggleMenuOff();
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
  
    if (e.pageX || e.pageY) {
      posx = e.pageX;
      posy = e.pageY;
    } else if (e.clientX || e.clientY) {
      posx = e.clientX + document.body.scrollLeft + 
                         document.documentElement.scrollLeft;
      posy = e.clientY + document.body.scrollTop + 
                         document.documentElement.scrollTop;
    }
    return { x: posx, y: posy };
  }
  
  // Put menu in correct position - where the click event was triggered.
  function positionMenu(e) {
    var clickCoords = getPosition(e);
    var clickCoordsX = clickCoords.x;
    var clickCoordsY = clickCoords.y;
    
    var menuWidth = menu.offsetWidth + 4;
    var menuHeight = menu.offsetHeight + 4;
    var windowWidth = window.innerWidth;
    var windowHeight = window.innerHeight;
    
    if ( (windowWidth - clickCoordsX) < menuWidth ) {
      menu.style.left = windowWidth - menuWidth + "px";
    } else {
      menu.style.left = clickCoordsX + "px";
    }
    
    if ( (windowHeight - clickCoordsY) < menuHeight ) {
      menu.style.top = windowHeight - menuHeight + "px";
    } else {
      menu.style.top = clickCoordsY + "px";
    }
    
    console.log(menu);
  }

//------------------------ End of Context Menu -----------------------------

//------------------------ Drag and Drop -----------------------------------
// This is the drag and drop code
// which uses ajax to update the database
// the drag reverts if database update fails.

  // for moving the lessons
  $( function() {
    $( ".lesson" ).draggable({
      revert: true,
      zIndex: 100,
      //comments display on click, remove when begin the drag
      start: function(event, ui) {
        $('#comments').css('visibility', 'hidden');  
      }
    });

    $( ".slot" ).droppable({
      accept: ".lesson",
      drop: function( event, ui ) {
        var dom_change = {};
        dom_change['action'] = "move";
        dom_change['move_ele_id'] = ui.draggable.attr('id');
        dom_change['ele_old_parent_id'] = document.getElementById(dom_change['move_ele_id']).parentElement.id;
        dom_change['ele_new_parent_id'] = this.id;
        dom_change['element_type'] = "lesson";
        //console.log("---------------dom_change---------------");
        //console.dir(dom_change);
        //var lesson_id = getRecordId(ui.draggable.attr('id'));
        //console.log("lesson_id: " + lesson_id);
        //var slot_id = getRecordId(this.id);
        //console.log("slot_id: " + slot_id);
        //var oldslot_id = getRecordId(ui.draggable.context.parentElement.id);
        //console.log("oldslot_id: " + oldslot_id);
        //lessonupdateslot( oldslot_id, slot_id, lesson_id, this, ui, dom_change );
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
  });

  // for moving the students and tutors
  $( function() {
    $( ".student, .tutor" ).draggable({
      revert: true,
      zIndex: 100,
      //comments display on click, remove when begin the drag
      start: function(event, ui) {
        $('#comments').css('visibility', 'hidden');  
      }
    });

    $( ".lesson" ).droppable({
      accept: ".student, .tutor",
      drop: function( event, ui ) {
        var dom_change = {};
        dom_change['action'] = "move";
        var this_move_element = document.getElementById(ui.draggable.attr('id'));
        //        if(clickInsideElementClassList2(thisEle, ['index'])){
        if(clickInsideElementClassList2(this_move_element, ['index'])){
          dom_change['action'] = "copy";          
        }
        dom_change['move_ele_id'] = ui.draggable.attr('id');
        dom_change['ele_old_parent_id'] = document.getElementById(dom_change['move_ele_id']).parentElement.id;
        dom_change['ele_new_parent_id'] = this.id;
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
  });

//------------------------ End of Drag and Drop ----------------------------


//----- Common Functions used by both Drag & Drop and Context Menu ---------

  // delete one of tutor, student or lesson. 
  function deleteentry( domchange ){
    console.log("deleteentry called");
    console.log(domchange);
    //var action = domchange['action'];   //move or copy
    var itemid = getRecordId(domchange['move_ele_id']);
    var oldparentid = getRecordId(domchange['ele_old_parent_id']);
    //var newparentid = getRecordId(domchange['ele_new_parent_id']);
    console.log("eleid full: " + domchange['move_ele_id']);
    var itemtype = getRecordType(domchange['move_ele_id']);
    if( 'n' == itemtype ){ //lesson
      console.log("we have a lesson - " + itemid);
      var mytype = 'DELETE';
      //var myurl = "https://bit3-micmac.c9users.io/lessons/" + parseInt(itemid, 10);
      var myurl = myhost + "/lessons/" + parseInt(itemid, 10);
      var mydata =  { 'domchange'      : domchange };
    } else if( 't' == itemtype ){
      console.log("we have a tutor - " + itemid);
      mytype = 'POST';
      //myurl = "https://bit3-micmac.c9users.io/removetutorfromlesson";
      myurl = myhost + "/removetutorfromlesson";
      mydata =  { 'tutor_id'     : itemid, 
                  'old_lesson_id' : oldparentid,
                  'domchange'      : domchange 
                };
    } else if( 's' == itemtype ){
      console.log("we have a student- " + itemid);
      //myurl = "https://bit3-micmac.c9users.io/removestudentfromlesson";
      myurl = myhost + "/removestudentfromlesson";
      mytype = 'POST';
      mydata =  { 'student_id'     : itemid, 
                  'old_lesson_id' : oldparentid,
                  'domchange'      : domchange 
                };
    }
    console.log("myurl: " + myurl)
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
    var oldlessonid = getRecordId(domchange['ele_old_parent_id']);
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
      if(action == "move") {   
        //myurl = "https://bit3-micmac.c9users.io/studentmovelesson/";
        myurl = myhost + "/studentmovelesson/";
      } else if(action == "copy"){ // copy
        //myurl = "https://bit3-micmac.c9users.io/studentcopylesson/";
        myurl = myhost + "/studentcopylesson/";
      }
      mydata =  { 'student_id'     : personid, 
                  'old_lesson_id' : oldlessonid,
                  'new_lesson_id' : newlessonid,
                  'domchange'      : domchange 
                };
    } else if( 't' == recordtype ){   //tutor
      console.log("we have a tutor - " + personid);
      if(action == "move") {
        //myurl = "https://bit3-micmac.c9users.io/tutormovelesson/";
        myurl = myhost + "/tutormovelesson/";
      } else { // copy
        //myurl = "https://bit3-micmac.c9users.io/tutorcopylesson/";
        myurl = myhost + "/tutorcopylesson/";
      }
      mydata =  { 'tutor_id'       : personid, 
                  'old_lesson_id' : oldlessonid,
                  'new_lesson_id' : newlessonid,
                  'domchange'      : domchange                  
                };
      
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
    //var myurl = "https://bit3-micmac.c9users.io/lessons/"
    var myurl = myhost + "/lessons/"
    $.ajax({
        type: "POST",
        url: myurl,
        data: {lesson : {'slot_id' : newslotid }, 'domchange' : domchange },
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
    var newlessonele = lessontemplate.cloneNode(true);
    console.log(newlessonele);
    newlessonele.id = domchange['move_ele_id'];
    var parentele = document.getElementById(domchange['ele_new_parent_id']);
    parentele.appendChild(newlessonele);
    newlessonele.classList.remove("hideme");
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
    //console.log("***************t: " + moveRecordType);
    switch(moveRecordType) {
      case 't': //tutor
      case 's': //student
        newid = newparentid + newid;
        break;
      case 'n': //lesson
        newid = newparentid.substr(0, newparentid.length-sf-1) + newid;
        break;
    }
    var oldid = domchange['move_ele_id'];
    //console.log("moveelement - oldid: " + oldid + " => newid: " + newid);
    var elemoving = document.getElementById(oldid);
    if ('copy' == domchange['action']){
      var eletoplace = elemoving.cloneNode(true);
    }else if('move' == domchange['action']){
      eletoplace = elemoving;
    }
    //console.log("----------eletoplace-------");
    //console.log(eletoplace);
    var parent_element = document.getElementById(domchange['ele_new_parent_id']);
    //console.log("------ parent_element ---------");
    //console.log(parent_element);
    if ('t' == moveRecordType) {  // for tutors, prepend
      parent_element.insertBefore(eletoplace, parent_element.firstChild);
    }else{  //otherwise, append.
      parent_element.append(eletoplace);
    }
    eletoplace.id = newid;
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



//------ End of Filter by name functions for the tutors and students -------

});

function selectshows() {
  //console.log("processing selectShows");
  var showList =  document.getElementById("selectshows").getElementsByTagName("input");
  //console.log(showList);
  for(var i = 0; i < showList.length; i++){
    //console.log(showList[i].id);
    //console.log(showList[i].checked);
    switch(showList[i].id){
      case "hidetutors":
        //var eleThisParent = document.getElementById("index-tutors");
        if (showList[i].checked){
          document.getElementById("index-tutors").classList.add("hideme");
        }else{
          document.getElementById("index-tutors").classList.remove("hideme");
        }
        break;
      case "hidestudents":
        //var eleThisParent = document.getElementById("index-students");
        if (showList[i].checked){
          document.getElementById("index-students").classList.add("hideme");
        }else{
          document.getElementById("index-students").classList.remove("hideme");
        }
        break;
      case "hidecomments":
        var eleComments = document.getElementsByClassName("comment");
        if (showList[i].checked){
          for (var j=eleComments.length; j-- ; ){
            eleComments[j].classList.add("hideme");
          }
        }else{
          for (var j=eleComments.length; j-- ; ){
            eleComments[j].classList.remove("hideme");
          }
        }
        break;
    }
  }
}
