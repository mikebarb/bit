/* Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
*/

/* global $ */

$(document).ready(function() {
  //console.log("documentready");  
  
  
  // some global variables for this page
  var sf = 3;     // significant figures for dom id components e.g.session ids, etc.

  // this will put obvious border on mouse entering selectable items
  /*$('.session').mouseenter(function(){
     $(this).css('border','3px solid black');
  });
  $('.session').mouseleave(function(){
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
  $('.session').mousedown(function(){
    $('.positionable').html("session: " + this.id);
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
// This is the context menu for the session,
// tutor and student elements.

  var taskItemClassList = ['slot', 'session', 'tutor', 'student'];
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
  // for slot, session, tutor and student entries
  function getRecordType(ele_id){
    return ele_id.substr(ele_id.length-sf-1, 1);
  }

  // this function extracts the record id from the dom id
  // for slot, session, tutor and student entries
  function getRecordId(ele_id){
    return ele_id.substr(ele_id.length-sf, sf);
  }

//***********************************************************************
// Perform the actions invoked by the context menu items.                *
//***********************************************************************
  function menuItemActioner( action ) {
    //dom_change['action'] = "move";
    //dom_change['move_ele_id'] = ui.draggable.attr('id');
    //dom_change['ele_old_parent_id'] = document.getElementById(dom_change['move_ele_id']).parentElement.id;
    //dom_change['ele_new_parent_id'] = this.id;
    //dom_change['element_type'] = "session";
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
              // find the 'session' element in the tree working upwards
              currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['session']).id;
              break;
            case 'n':   //session
              // find the 'slot' element in the tree working upwards
              currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
              break;
          }
          //******************************************************
          // Need the database changes and manipulation called here
          //******************************************************
          personupdatessession( currentActivity );
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
        // Will delete the session record for a session if empty.
        currentActivity['action'] = thisAction;
        thisEleId = taskItemInContext.id;
        currentActivity['move_ele_id'] =  thisEleId;
        currentActivity['ele_old_parent_id'] = document.getElementById(thisEleId).parentElement.id;
        deleteentry(currentActivity);
        break;
      case "addSession":
        // This will add a new session within the slot holding the element clicked.
        // Will add a new session record with this slot value.
        currentActivity['action'] = thisAction;
        console.log("case = addSession");
        thisEleId = taskItemInContext.id;
        thisEle = document.getElementById(thisEleId);
        currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
        addSession(currentActivity);
        break;
      case "removeSession":
        // This will remove a session clicked on.
        currentActivity['action'] = thisAction;
        currentActivity['move_ele_id'] =  thisEleId;
        console.log("case = removeSession");
        thisEleId = taskItemInContext.id;
        thisEle = document.getElementById(thisEleId);
        currentActivity['ele_old_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
        removeSession(currentActivity);
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
    for(var i = classNameList.length; i--; ) {
      if ( el.classList.contains(classNameList[i]) ) {
        return el;
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

  // for moving the sessions
  $( function() {
    $( ".session" ).draggable({
      revert: true,
      zIndex: 100,
      //comments display on click, remove when begin the drag
      start: function(event, ui) {
        $('#comments').css('visibility', 'hidden');  
      }
    });

    $( ".slot" ).droppable({
      accept: ".session",
      drop: function( event, ui ) {
        var dom_change = {};
        dom_change['action'] = "move";
        dom_change['move_ele_id'] = ui.draggable.attr('id');
        dom_change['ele_old_parent_id'] = document.getElementById(dom_change['move_ele_id']).parentElement.id;
        dom_change['ele_new_parent_id'] = this.id;
        dom_change['element_type'] = "session";
        //console.log("---------------dom_change---------------");
        //console.dir(dom_change);
        //var session_id = getRecordId(ui.draggable.attr('id'));
        //console.log("session_id: " + session_id);
        //var slot_id = getRecordId(this.id);
        //console.log("slot_id: " + slot_id);
        //var oldslot_id = getRecordId(ui.draggable.context.parentElement.id);
        //console.log("oldslot_id: " + oldslot_id);
        //sessionupdateslot( oldslot_id, slot_id, session_id, this, ui, dom_change );
        sessionupdateslot( dom_change );
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

    $( ".session" ).droppable({
      accept: ".student, .tutor",
      drop: function( event, ui ) {
        var dom_change = {};
        dom_change['action'] = "move";
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

        personupdatessession( dom_change );

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

  // delete one of tutor, student or session. 
  function deleteentry( domchange ){
    console.log("deleteentry called");
    console.log(domchange);
    //var action = domchange['action'];   //move or copy
    var itemid = getRecordId(domchange['move_ele_id']);
    var oldparentid = getRecordId(domchange['ele_old_parent_id']);
    //var newparentid = getRecordId(domchange['ele_new_parent_id']);
    console.log("eleid full: " + domchange['move_ele_id']);
    var itemtype = getRecordType(domchange['move_ele_id']);
    if( 'n' == itemtype ){ //session
      console.log("we have a session - " + itemid);
      var mytype = 'DELETE';
      var myurl = "https://bit2-micmac.c9users.io/sessions/" + parseInt(itemid, 10);
      var mydata =  { 'domchange'      : domchange };
      
    } else if( 't' == itemtype ){
      console.log("we have a tutor - " + itemid);
      mytype = 'POST';
      myurl = "https://bit2-micmac.c9users.io/removetutorfromsession";
      mydata =  { 'tutor_id'     : itemid, 
                  'old_session_id' : oldparentid,
                  'domchange'      : domchange 
                };
    } else if( 's' == itemtype ){
      console.log("we have a student- " + itemid);
      myurl = "https://bit2-micmac.c9users.io/removestudentfromsession";
      console.log("myurl: " + myurl)
      mytype = 'POST';
      mydata =  { 'student_id'     : itemid, 
                  'old_session_id' : oldparentid,
                  'domchange'      : domchange 
                };
    }
    $.ajax({
        type: mytype,
        url: myurl,
        data: mydata,
        dataType: "json",
        context: domchange,
        success: function(){
            console.log("done - deleted session " + itemid );
            deleteelement(domchange);
        },
        error: function(request, textStatus, errorThrown){
            //$(this).addClass( "processingerror" );
            console.log("ajax error occured: " + request.status.to_s + " - " + textStatus );
            alert("ajax error occured: " + request.status.to_s + " - " + textStatus );
        }
    });
    //data: {session : {'slot_id' : slotid }, 'domchange' : domchange },
  }

  function deleteelement( domchange ){
    //  action:             "move"
    //  ele_new_parent_id:  "Wod201705291630l002"  -- slot
    //  ele_old_parent_id:  "Wod201705291600l001"  -- slot
    //  move_ele_id:        "Wod201705291600n003"  -- session
    console.log("called deleteelement");
    console.dir(domchange);
    var eleid = domchange['move_ele_id'];
    console.log("deleteelement - id: " + eleid);
    var eledelete = document.getElementById(eleid);
    eledelete.remove();
  }

  //This function is called for either move or copy
  //Does ajax to move or copy a student or tutor to another session
  function personupdatessession( domchange ){
    console.log("personupdatesession called");
    console.log(domchange);
    var action = domchange['action'];   //move or copy
    var personid = getRecordId(domchange['move_ele_id']);
    var oldsessionid = getRecordId(domchange['ele_old_parent_id']);
    var newsessionid = getRecordId(domchange['ele_new_parent_id']);
    console.log("personid: " + domchange['move_ele_id']);
    var myurl;
    var mydata;
    var recordtype = getRecordType(domchange['move_ele_id']);
    if( 's' == recordtype ){    //student
      console.log("we have a student - " + personid);
      console.log("action: " + action);
      if(action == "move") {   
        myurl = "https://bit2-micmac.c9users.io/studentmovesession/";
      } else if(action == "copy"){ // copy
        myurl = "https://bit2-micmac.c9users.io/studentcopysession/";
      }
      mydata =  { 'student_id'     : personid, 
                  'old_session_id' : oldsessionid,
                  'new_session_id' : newsessionid,
                  'domchange'      : domchange 
                };
    } else if( 't' == recordtype ){   //tutor
      console.log("we have a tutor - " + personid);
      if(action == "move") {
        myurl = "https://bit2-micmac.c9users.io/tutormovesession/";
      } else { // copy
        myurl = "https://bit2-micmac.c9users.io/tutorcopysession/";
      }
      mydata =  { 'tutor_id'       : personid, 
                  'old_session_id' : oldsessionid,
                  'new_session_id' : newsessionid,
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
            for (var error in (errors['session_id'])){
              error_message += " : " + errors['session_id'][error];
            }
            alert("error moving student or tutor to another session: " + error_message);
        }
     });
  }

  function addSession(domchange){
    console.log("calling addSession");
    console.log(domchange);
    var newslotid = getRecordId(domchange['ele_new_parent_id']);
    $.ajax({
        type: "POST",
        url: "https://bit2-micmac.c9users.io/sessions/",
        data: {session : {'slot_id' : newslotid }, 'domchange' : domchange },
        dataType: "json",
        context: domchange,
        success: function(result){
            console.log("done - ajax added session to slot " + newslotid );
            console.log(result);
            console.log("extract the created session id: " + result.id );
            var sessionid = result.id;
            //ele_new_parent_id:"Wod201705291600l001"
            var slotid = domchange['ele_new_parent_id'];
            console.log("slotid: " + slotid + " sessionid: " + sessionid);
            var sessionid_base = slotid.substr(0, slotid.length-sf-1 );
            var paddedid = padleft(sessionid, sf);
            console.log("paddedid: " + paddedid);
            var newsessionid = sessionid_base + "n" + paddedid;
            console.log("newsessionid: " + newsessionid);
            domchange['move_ele_id'] = newsessionid;
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
  
  function removeSession(domchange){
    console.log("calling removeSession");
    console.log(domchange);
    var sessionid = getRecordId(domchange['move_ele_id']);
    $.ajax({
        type: "DELETE",
        url: "https://bit2-micmac.c9users.io/sessions/" + sessionid,
        data: {'domchange' : domchange },
        dataType: "json",
        context: domchange,
        success: function(result){
            console.log("done - ajax removed session" );
            //ele_new_parent_id:"Wod201705291600l001"
            deleteelement(domchange);
        },
        error: function(request, textStatus, errorThrown){
            //$(this).addClass( "processingerror" );
            console.log("ajax error occured: " + request.status.to_s + " - " + textStatus );
            alert("ajax error occured: " + request.status.to_s + " - " + textStatus );
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

  //sessionupdateslot( oldslot_id1, slot_id1, session_id1, this, ui, domchange );
  function sessionupdateslot( domchange ){
    console.log("calling sessionupdateslot");
    console.log(domchange);
    var sessionid = getRecordId(domchange['move_ele_id']);
    var oldslotid = getRecordId(domchange['ele_old_parent_id']);
    var slotid = getRecordId(domchange['ele_new_parent_id']);
    $.ajax({
        type: "POST",
        url: "https://bit2-micmac.c9users.io/sessions/" + sessionid,
        data: {session : {'slot_id' : slotid }, 'domchange' : domchange },
        dataType: "json",
        context: domchange,
        success: function(){
            console.log("done - dragged session " + sessionid + " to slot " + slotid + " from " + oldslotid );
            moveelement(domchange);
        },
        error: function(request, textStatus, errorThrown){
            //$(this).addClass( "processingerror" );
            console.log("ajax error occured: " + request.status.to_s + " - " + textStatus );
            alert("ajax error occured: " + request.status.to_s + " - " + textStatus );
        }
    });
  }
  
  // Add a new session element to the DOM
  function addelement(domchange){
    console.log("addelement called");
    console.log(domchange);
    //<div class=session id=<%= cells["id_dom"] + "n" + entry.id.to_s.rjust(@sf, "0") %> >
    var sessiontemplate = document.getElementById("sessiontemplate");
    console.log(sessiontemplate);
    var newsessionele = sessiontemplate.cloneNode(true);
    console.log(newsessionele);
    newsessionele.id = domchange['move_ele_id'];
    var parentele = document.getElementById(domchange['ele_new_parent_id']);
    parentele.appendChild(newsessionele);
    newsessionele.classList.remove("hideme");
    console.log(parentele);
  }

  function moveelement( domchange ){
    //  action:             "move"
    //  ele_new_parent_id:  "Wod201705291630l002"  -- slot
    //  ele_old_parent_id:  "Wod201705291600l001"  -- slot
    //  move_ele_id:        "Wod201705291600n003"  -- session
    console.log("called moveelement");
    console.dir(domchange);
    var newparentid = domchange['ele_new_parent_id'];
    var moveRecordType = getRecordType(domchange['move_ele_id']);
    var newid = moveRecordType + getRecordId(domchange['move_ele_id']);
    console.log("***************t: " + moveRecordType);
    switch(moveRecordType) {
      case 't': //tutor
      case 's': //student
        newid = newparentid + newid;
        break;
      case 'n': //session
        newid = newparentid.substr(0, newparentid.length-sf-1) + newid;
        break;
    }
    var oldid = domchange['move_ele_id'];
    console.log("moveelement - oldid: " + oldid + " => newid: " + newid);
    var elemoving = document.getElementById(oldid);
    if ('copy' == domchange['action']){
      var eletoplace = elemoving.cloneNode(true);
    }else if('move' == domchange['action']){
      eletoplace = elemoving;
    }
    console.log("----------eletoplace-------");
    console.log(eletoplace);
    var parent_element = document.getElementById(domchange['ele_new_parent_id']);
    console.log("------ parent_element ---------");
    console.log(parent_element);
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
      var filter, eleIndexTutors, eleTutorNames, eleIndexStudents, eleStudentNames, i, eleAncestor;
      filter = document.getElementById("personInput").value.toUpperCase();
      console.log("filter: " + filter);
      eleIndexTutors = document.getElementById("index-tutors");
      console.log(eleIndexTutors);
      if(! eleIndexTutors.classList.contains("hideme")){
        eleTutorNames = eleIndexTutors.getElementsByClassName("tutorname");
        console.log(eleTutorNames);
        for (i = 0; i < eleTutorNames.length; i++) {
            var tutorNameText = eleTutorNames[i].innerHTML.substr(7).toUpperCase();
            console.log("tutorNameText: " + tutorNameText);
            eleAncestor = findAncestor (eleTutorNames[i], "tutor");
            console.log(eleAncestor);
            if (tutorNameText.indexOf(filter) > -1) {
                eleAncestor.style.display = "";
                console.log("show");
            } else {
                eleAncestor.style.display = "none";
                console.log("hide");
            }
        }
      }
      console.log("about to process students");
      eleIndexStudents = document.getElementById("index-students");
      console.log(eleIndexStudents);
      if(! eleIndexStudents.classList.contains("hideme")){
        eleStudentNames = eleIndexStudents.getElementsByClassName("studentname");
        console.log(eleStudentNames);
        for (i = 0; i < eleStudentNames.length; i++) {
            var studentNameText = eleStudentNames[i].innerHTML.substr(9).toUpperCase();
            console.log("studentNameText: " + studentNameText);
            eleAncestor = findAncestor (eleStudentNames[i], "student");
            console.log(eleAncestor);
            if (studentNameText.indexOf(filter) > -1) {
                eleAncestor.style.display = "";
                console.log("show");
            } else {
                eleAncestor.style.display = "none";
                console.log("hide");
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
  console.log("processing selectShows");
  var showList =  document.getElementById("selectshows").getElementsByTagName("input");
  console.log(showList);
  for(var i = 0; i < showList.length; i++){
    console.log(showList[i].id);
    console.log(showList[i].checked);
    switch(showList[i].id){
      case "hidetutors":
        console.log("processing hide tutors");
        var eleThisParent = document.getElementById("index-tutors");
        console.log(eleThisParent);
        if (showList[i].checked){
          document.getElementById("index-tutors").classList.add("hideme");
        }else{
          document.getElementById("index-tutors").classList.remove("hideme");
        }
        break;
      case "hidestudents":
        console.log("processing hidestudents");
        eleThisParent = document.getElementById("index-students");
        console.log(eleThisParent);
        if (showList[i].checked){
          document.getElementById("index-students").classList.add("hideme");
        }else{
          document.getElementById("index-students").classList.remove("hideme");
        }
        break;
      case "hidecomments":
        console.log("processing hidecomments");
        var eleComments = document.getElementsByClassName("comment");
        console.log(eleComments);
        if (showList[i].checked){
          for (var j=eleComments.length; j-- ; ){
            console.log("j: " + j);
            console.log(eleComments[j].id);
            console.log(eleComments[j]);
            eleComments[j].classList.add("hideme");
          }
        }else{
          for (var j=eleComments.length; j-- ; ){
            console.log("j: " + j);
            console.log(eleComments[j].id);
            console.log(eleComments[j]);
            eleComments[j].classList.remove("hideme");
          }
        }
        break;
    }
  }
}
