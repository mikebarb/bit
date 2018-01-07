/* Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
*/

/* global $ */

$(document).ready(function() {
  //console.log("documentready");  

  // this will put obvious border on mouse entering selectable items
  $('.session').mouseenter(function(){
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
  $('.tutor').mouseenter(function(){
     $(this).css('border','3px solid green');
  });
  $('.tutor').mouseleave(function(){
    $(this).css('border','0px solid green');
  });
  
  // single click will display the comment.
  $('.session').mousedown(function(){
    $('.positionable').html("session: " + this.id);
    $(this).css('border','0px solid grey');
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
  
  function getSessionType(ele_id){
    return ele_id.substr(3+12, 1);
  }

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
    switch( thisAction ) {
      case "copy":
      case "cut":
        console.log("cut or paste");
        currentActivity['action'] = thisAction;
        var thisEleId = taskItemInContext.id;
        currentActivity['move_ele_id'] =  thisEleId;
        currentActivity['ele_old_parent_id'] = document.getElementById(thisEleId).parentElement.id;
        //var t = getSessionType(thisEleId);
        var t = thisEleId.substr(3+12, 1);
        console.log("id: " + thisEleId + " t: " + t);
        switch(t) {
          case 's':
            console.log("student");
            currentActivity['element_type'] = 'student';
            break;
          case 't':
            console.log("tutor");
            currentActivity['element_type'] = 'tutor';
            break;
          case 'n':
            console.log("session");
            currentActivity['element_type'] = 'session';
            break;
          // ignore slot here as it is never moved - only gets dropped into.
        }
        break;
      case "paste":
        console.log("paste");
        //currentActivity['action'] = thisAction;
        thisEleId = taskItemInContext.id;
        var thisEle = document.getElementById(thisEleId);
        t = thisEleId.substr(3+12, 1);
        // action nor relevant for a paste, set in the move / copy action.
        // On dropping, need to move up parent tree till find the appropriate parent
        console.log(currentActivity);
        if( currentActivity ) {   // been a cut or move
          switch ( currentActivity.element_type) {
            case 'student':
            case 'tutor':
              console.log("processing paste for a student or tutor");
              // find the seesion element in the tree working upwards
              //var newParent = clickInsideElementClassList2(thisEle, ['session']);
              currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['session']).id;
              break;
            case 'session':
              console.log("processing paste for a student or tutor");
              //newParent = clickInsideElementClassList2(thisEle, ['slot']);
              currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
              break;
          }
          console.log("--- current activity on paste before deleting---");
          console.log(currentActivity);
          //******************************************************
          // Need the database changes and manipulation called here
          //******************************************************
          currentActivity = {};
        }
      }
      console.log("--- current activity ---");
      console.log(currentActivity);
  }
  
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

// This is the drag and drop code
// which uses ajax to update the database
// the drag reverts if database update fails.

  // for moving the sessions
  $( function() {
    $( ".session" ).draggable({
      revert: true,
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
        console.log("---------------dom_change---------------");
        console.dir(dom_change);
        var session_id = ui.draggable.attr('id').substr(3+12+1, 3);
        console.log("session_id: " + session_id);
        var slot_id = this.id.substr(3+12+1, 3);
        console.log("slot_id: " + slot_id);
        var oldslot_id = ui.draggable.context.parentElement.id.substr(3+12+1, 3);
        console.log("oldslot_id: " + oldslot_id);
        sessionupdateslot( oldslot_id, slot_id, session_id, this, ui, dom_change );
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

  // for moving the students
  $( function() {
    $( ".student, .tutor" ).draggable({
      revert: true,
      //comments display on click, remove when begin the drag
      start: function(event, ui) {
        $('#comments').css('visibility', 'hidden');  
      }
    });

    $( ".session" ).droppable({
      accept: ".student, .tutor",
      drop: function( event, ui ) {
        console.log("----------------passed parameters------------------------");
        console.log ("--this--");
        console.dir (this);
        console.log ("--ui.draggable--");
        console.dir (ui.draggable);
        console.log ("--ui.draggable.attr('id')--");
        console.dir (ui.draggable.attr('id'));
        console.log ("--ui--");
        console.dir (ui);
        console.log ("================");
        
        var dom_change = {};
        dom_change['action'] = "move";
        dom_change['move_ele_id'] = ui.draggable.attr('id');
        dom_change['ele_old_parent_id'] = document.getElementById(dom_change['move_ele_id']).parentElement.id;
        dom_change['ele_new_parent_id'] = this.id;
        var type = dom_change['move_ele_id'].substr(3+12, 1);
        dom_change['element_type'] = "tutor";
        if(type == 's'){
          dom_change['element_type'] = "student" ;
        } else {
          dom_change['element_type'] = "tutor" ;
        }
        console.log("---------------dom_change---------------");
        console.dir(dom_change);
        
        var move_ele_id = ui.draggable.attr('id');
        console.log("move_ele_id: " + move_ele_id);
        var ele_old_parent_id = document.getElementById(move_ele_id).parentElement.id;
        console.log("ele_old_parent_id: " + ele_old_parent_id);
        var ele_new_parent_id = this.id;
        console.log("ele_new_parent_id: " + ele_new_parent_id);
        var person_id = ui.draggable.attr('id').substr(3+12+1, 3);
        console.log("person_id: " + person_id);
        var session_id = this.id.substr(3+12+1, 3);
        console.log("session_id: " + session_id);
        var oldsession_id = ui.draggable.context.parentElement.id.substr(3+12+1, 3);
        console.log("oldsession_id: " + oldsession_id);
        personupdatessession( oldsession_id, session_id, person_id, this, ui, dom_change );        
        console.log ("dropping student or tutor");
        $( this )
          //.append(ui.draggable)
          .removeClass( "my-over" )
          .addClass( "ui-state-highlight" );
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

  function personupdatessession( oldsessionid, sessionid, personid, mythis, ui, domchange ){
    //console.log("calling studentupdatesession");
    //var mydata = "{sessionid:" + sessionid + "}";
    //alert("called studentupdatesession: studentid- " + studentid + " sessionid- to " + sessionid + " from " + ui.draggable.context.parentElement.id );
    //console.log("---------------------this-------------------");
    //console.dir(this);
    //console.log("---------------------mythis.dragged-------------------");
    mythis.dragged = ui.draggable;
    //console.dir(mythis.dragged);
    //var myajaxdata = {'student_id' : studentid, 'old_session_id' : oldsessionid, 'new_session_id' : sessionid };
    //console.log("--------------------myajaxdata-------------------");
    //console.log(myajaxdata);
    //console.log("=============================================");
    console.log("personid: " + domchange['move_ele_id']);
    var myurl;
    var mydata;
    if( 's' == domchange['move_ele_id'].substr(3+12, 1) ){
      console.log("we have a student - " + personid);
      myurl = "https://bit2-micmac.c9users.io/studentchangesession/";
      mydata =  { 'student_id'     : personid, 
                  'old_session_id' : oldsessionid,
                  'new_session_id' : sessionid,
                  'domchange'      : domchange 
                };
      //data: {session : {'slot_id' : slotid }, 'domchange' : domchange },
      
    } else if( 't' == domchange['move_ele_id'].substr(3+12, 1) ){
      console.log("we have a tutor - " + personid);
      myurl = "https://bit2-micmac.c9users.io/tutorchangesession/";
      mydata =  { 'tutor_id'       : personid, 
                  'old_session_id' : oldsessionid,
                  'new_session_id' : sessionid,
                  'domchange'      : domchange                  
                };
      
    } else {
      console.log("error - the moving person is not a tutor or student");
      return;
    }
    //return;
    $.ajax({
        type: "POST",
        url: myurl,
        data: mydata,
        dataType: "json",
        context: mythis,

        success: function(){
            //console.log("done personupdatesession: personid- " + personid + " sessionid- to " + sessionid + " from " + oldsessionid );
            //console.dir(mythis);
            moveelement(domchange);

            //var newid = mythis.id.substr(0, 3+12+1) + personid;
            //console.log("newid: " + newid);
            //var oldid = mythis.dragged.attr('id');
            //console.log("oldid: " + oldid);
            //$(this).append(mythis.dragged);
            //var elemoved = document.getElementById(oldid);
            //elemoved.id = newid;
            //$(this).addClass( "processingsuccess" );
        },
        error: function(xhr){
            //$(this).addClass( "processingerror" );
            var errors = $.parseJSON(xhr.responseText);
            var error_message = "";
            for (var error in (errors['session_id'])){
              error_message += " : " + errors['session_id'][error];
            }
            alert("error moving student to another session: " + error_message);
        }
     });
  }

  //sessionupdateslot( oldslot_id, slot_id, session_id, this, ui );
  function sessionupdateslot( oldslotid, slotid, sessionid, mythis, ui, domchange ){
     console.log("calling sessionupdateslot");
     alert("called sessionupdateslot: sessionid- " + sessionid + " slotid- to " + slotid + " from " + oldslotid );
     mythis.dragged = ui.draggable;  
     $.ajax({
        type: "POST",
        url: "https://bit2-micmac.c9users.io/sessions/" + sessionid,
        data: {session : {'slot_id' : slotid }, 'domchange' : domchange },
        dataType: "json",
        context: mythis,
        success: function(){
            console.log("done - dragged session " + this.dragged.attr('id') + " to slot " + this.id + " from " + this.dragged.context.parentElement.id );
            moveelement(domchange);
        },
        error: function(request, textStatus, errorThrown){
            //$(this).addClass( "processingerror" );
            console.log("ajax error occured: " + request.status.to_s + " - " + textStatus );
            alert("ajax error occured: " + request.status.to_s + " - " + textStatus );
        }
    });
  }

  function moveelement( domchange ){
    //  action:             "move"
    //  ele_new_parent_id:  "Wod201705291630l002"  -- slot
    //  ele_old_parent_id:  "Wod201705291600l001"  -- slot
    //  move_ele_id:        "Wod201705291600n003"  -- session
    //console.log("called moveelement");
    //console.dir(domchange);
    var newid = domchange['ele_new_parent_id'].substr(0, 3+12) + 
                domchange['move_ele_id'].substr(3+12, 4);
    //console.log("moveelement - newid: " + newid);
    var oldid = domchange['move_ele_id'];
    //console.log("moveelement - oldid: " + oldid);
    var elemoving = document.getElementById(oldid);
    var parent_element = document.getElementById(domchange['ele_new_parent_id']);
    console.log("element type: " + domchange['element_type']);
    if ('tutor' == domchange['element_type']) {
      parent_element.insertBefore(elemoving, parent_element.firstChild);
    }else{
      parent_element.append(elemoving);
    }
    elemoving.id = newid;
  }

});

