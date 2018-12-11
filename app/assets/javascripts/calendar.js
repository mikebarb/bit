/* Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
*/

/* global $ */
/* global Ably */

// Web Socket receives a new message - calendar updates received.

// Note: this is called with turbolinks at bottom of page.
// Written as a callable function to provide this flexibility.
// Found that we need to be careful this does not get called twice
// e.g. from from both tuboload and page load - causes double triggers.


// the order of this class list is important - searches are done from 
// finest to broadest when looking for relevant elements(divs).
var taskItemClassList_calendar = ['slot', 'lesson', 'tutor', 'student'];
var taskItemClassList_stats = ['slot', 'lesson', 'tutor', 'student', 'allocate'];

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
var myhost = window.location.protocol + '//' + window.location.hostname;   // base url for ajax
var ably;             // messaging global identifier

var ready = function() {
  console.log("called ready");
  if(document.getElementById('page_name')){
    var page_name = document.getElementById('page_name').innerHTML;
    console.log("page name: " + page_name);
    if((page_name == 'calendar') ||
        (page_name == 'stats')){
      ready_common();
    }
    if(page_name == 'calendar'){
      ready_calendar();
    }else if(page_name == 'stats'){
      ready_stats();
    }
  }else{
    return;
  }
};

//var ready_common = function() {
function ready_common() {
/*
  ably = new Ably.Realtime({ authUrl: '/auth' });
  ably.connection.on('connecting', function() { showStatus('Connecting to Ably...'); });
  ably.connection.on('connected', function() { clearStatus(); });
  ably.connection.on('disconnected', function() { showStatus('Disconnected from Ably...'); });
  ably.connection.on('suspended', function() { showStatus('Disconnected from Ably for a while...'); });
   
  var $status = $('#status');
  function showStatus(text) {
    $status.text(text).show();
  }
  function clearStatus() {
    $status.hide();
  }
*/
};

//var ready_calendar = function() {
function ready_calendar() {
  console.log("called ready_calendar");
/* No longer needed with Ably
  //App.cable.subscriptions.create("CalendarChannel", {  
  App.calendar = App.cable.subscriptions.create("CalendarChannel", {  
    received: function(data) {
      console.log("calendar.js - entered ws received function for calendar");
      console.dir(data);
      //var returnedDomData = JSON.parse(data['json']);
      var returnedDomData = data['json'];
      returnedDomData['actioncable'] = true;
      //moveelement_update(returnedDomData);
      //console.log("dom update done!!!");
      return;
    }
  });
*/

  // Set up to subscribe to the Ably messages
  ably = new Ably.Realtime({ authUrl: '/auth' });
  var calendarChannel = ably.channels.get('calendar');
  calendarChannel.subscribe(function(message){
    console.log("calendar.js - entered ably subscribe function for calendar - about to call moveelement_update");
    //console.log(JSON.parse(message.data));
    var returnedDomData = message.data;
    console.log(message.data);
    returnedDomData['ably'] = true;
    moveelement_update(returnedDomData);
    console.log("ably_receiver - dom update done!!!");
  });
    var calendarChannelListener = function(stateChange) {
    console.log('stats channel state is ' + stateChange.current);
    console.log('previous state was ' + stateChange.previous);
    if(stateChange.reason) {
      console.log('the reason for the state change was: ' + stateChange.reason.toString());
    }
  };
  calendarChannel.on(calendarChannelListener);

  // some global variables for this page
  //var sf = 5;     // significant figures for dom id components e.g.lesson ids, etc.

  // These are used in the quick status setting.
  var validTutorStatuses   = ["Away", "Absent", "Deal", "Scheduled", "Notified", "Confirmed", "Attended"];
  var validStudentStatuses = ["Away", "Absent", "Deal", "Bye", "Attended", "Scheduled"];
  var validTutorKinds    = ["Standard"];
  var validStudentKinds    = ["Standard"];
  var validStudentPersonStatuses  = ["new", "fortnightly", "onetoone", "standard"];

  // want to set defaults on some checkboxes on page load
  var flagViewOptions = false;
  if(document.getElementById('options')){
    //var passedOptions     = document.getElementById('options').innerHTML;
    var passedOptionsJson = JSON.parse(document.getElementById('options').innerHTML);
    for(var key in passedOptionsJson){            // loop json through the keys
      if(passedOptionsJson.hasOwnProperty(key)){
        if(key.indexOf("v_") == 0){               // initial chars in key
          flagViewOptions = true;
          var thisEleId = key.substr(2);
          var thisEle = document.getElementById(thisEleId);
          if(thisEle){                            // element is present on this page
            if(thisEle.type == "checkbox"){
              thisEle.checked = (passedOptionsJson[key] == "true");
            }else if(thisEle.id == 'quickStatusValue'){
              thisEle.value = passedOptionsJson[key];
            }else if(thisEle.id == 'personInput'){
              thisEle.value = passedOptionsJson[key];
              filterPeople();
            }
          }
        }
      }
    }
  }

  if (document.getElementById("hidetutors") &&
      document.getElementById("hidestudents") &&
      flagViewOptions == false ){
    var showList = document.getElementsByClassName("selectsite");
    if(showList.length > 0){
      showList[0].checked = true;
    }
  }
  selectshows(document);  // call the functions that invokes the checkbox values.
  

  $("ui-draggable");
  
  // scroll to same location when user refreshes the screen
  // using the refresh button that has been added to the flexible display.
  // https://stackoverflow.com/questions/17642872/refresh-page-and-keep-scroll-position

  if(document.getElementById('refreshthis')){
    document.getElementById('refreshthis').onclick = function() {
      var passedOptions = JSON.parse(document.getElementById('options').innerHTML);
      passedOptions.refresh = true;  // let them know this is our refresh
      // Now find the checked checkboxes
      var eleAllCheckboxes = document.getElementsByClassName('selectshow');
      for(var i=0;i<eleAllCheckboxes.length;i++){
        var mykey   = 'v_' + eleAllCheckboxes[i].id;
        var myvalue = eleAllCheckboxes[i].checked;
        passedOptions[mykey] = myvalue;
      }
      passedOptions['v_' + 'enableQuickStatus'] = 
                    document.getElementById('enableQuickStatus').checked;
      passedOptions['v_' + 'quickStatusValue'] = 
                    document.getElementById('quickStatusValue').value;
      passedOptions['v_' + 'enableQuickKind'] = 
                    document.getElementById('enableQuickKind').checked;
      passedOptions['v_' + 'quickKindValue'] = 
                    document.getElementById('quickKindValue').value;
      passedOptions['v_' + 'enableQuickPersonStatus'] = 
                    document.getElementById('enableQuickPersonStatus').checked;
      passedOptions['v_' + 'quickPersonStatusValue'] = 
                    document.getElementById('quickPersonStatusValue').value;
      passedOptions['v_' + 'personInput'] = 
                    document.getElementById('personInput').value;

      var myurl = window.location.origin + window.location.pathname;
      var currentYOffset = window.pageYOffset;  // save current page postion.
      setCookie("jumpToScrollPostion", currentYOffset, 1);
      var queryString = Object.keys(passedOptions).map(function(key) {
                          return encodeURIComponent(key) + '=' +
                                 encodeURIComponent(passedOptions[key]);
                        }).join('&');
      myurl = myurl + '?' + queryString;
      window.open(myurl,"_self");
    };
  }
  
  // check if we should jump to postion.
  var jumpTo = getCookie('jumpToScrollPostion');
  if(jumpTo != "") {
    window.scrollTo(0, jumpTo);
    setCookie('jumpToScrollPostion', '', 0);  // and delete cookie so we don't jump again.
  }

  function setCookie(cname, cvalue, exdays) {
    var d = new Date();
    d.setTime(d.getTime() + (exdays*24*60*60*1000));
    var expires = "expires="+ d.toUTCString();
    document.cookie = cname + "=" + cvalue + ";" + expires + ";path=/";
  }
  
  function getCookie(cname) {
    var name = cname + "=";
    var decodedCookie = decodeURIComponent(document.cookie);
    var ca = decodedCookie.split(';');
    for(var i = 0; i <ca.length; i++) {
        var c = ca[i];
        while (c.charAt(0) == ' ') {
            c = c.substring(1);
        }
        if (c.indexOf(name) == 0) {
            return c.substring(name.length, c.length);
        }
    }
    return "";
  }
  
  //------------------------ Context Menu - calendar -----------------------------
  // This is the context menu for the lesson, tutor and student elements.
  // It is the first context menu to be displayed when you right click on an
  // element.
  // When some context menu item are selected, a tertiary menu is opened
  // enabling further options to be selected.



  $('.jumptosite').click(function(){
    var thisInputEle = this.firstElementChild;
    if(thisInputEle.checked == true){
      var thisSiteId = 'site-' + thisInputEle.id.substr(4); 
      document.getElementById(thisSiteId).scrollIntoView(true);
      scrollBy(0, -500);
    }
  });

  // Initialise our application's code.
  // Made modular so that you have more control over initialising them. 
  function init() {
    menu_common();
    contextListener_calendar();
    clickListener_calendar();
    keyupListener();
    resizeListener();
    // disply the up to now hidden scheduler
    document.getElementsByClassName('schedule')[0].classList.remove('hideme');
  }
  
  // Sticky header allows us to shrink the index region of the page.
  // This makes more effective use of teh calendar region.
  if ($('#sticky-header').length) {
    /*var stickyHeaderTop = $('#sticky-header').offset().top;
    $(window).scroll(function (event) {
      var y = $(this).scrollTop();
      if (y >= stickyHeaderTop)
        $('#sticky-header').addClass('fixed');
      else
        $('#sticky-header').removeClass('fixed');
      $('#sticky-header').width($('#sticky-header').parent().width());
    });*/
    
    $('.sticky-header__title').click(function() {
      $('#sticky-header__collapsible').slideToggle();
    });
  }

  // Listens for contextmenu events.
  // Add the listeners for the main menu items.
  // contextmenu is an integrated javascript library function.
  // We detect the element right clicked on and position the context
  // menu adjacent to it.
  function contextListener_calendar() {
    document.addEventListener( "contextmenu", function(e) {
      menu = document.querySelector("#context-menu");
      tmenu = document.querySelector("#tertiary-menu");
      taskItemInContext = clickInsideElementClassList( e, taskItemClassList_calendar);
      if ( taskItemInContext ) {
        e.preventDefault();
        enableMenuItems_calendar();
        toggleMenuOn();
        clickPosition = getPosition(e);  // global variable
        positionMenu(menu);
        positionMenu(tmenu);
        eleClickedOn = e;                 // global variable
      } else {
        taskItemInContext = null;
        toggleMenuOff();
      }
    });
  }

  // Listens for click events on context menu items element.
  // On selection an item on the context menu, an appropriate action is triggered.
  function clickListener_calendar() {
    document.addEventListener( "click", function(e) {
      console.log("in clickListerner");
      console.dir(currentActivity);
      // determine if clicked inside main context menu or tertiary context menu.
      var clickEleIsAction   = clickInsideElementClassList( e, [contextMenuItemClassName]);
      var clickEleIsChoice   = clickInsideElementClassList( e, [tertiaryMenuItemClassName]);
      var clickEleIsTutor    = clickInsideElementClassList( e, ["tutor"]);
      var clickEleIsStudent  = clickInsideElementClassList( e, ["student"]);
  
      if ( clickEleIsAction ) {      // clicked in main context menu
        e.preventDefault();
        menuItemActioner_calendar( clickEleIsAction );   // call main menu item actioner.
      } else if (clickEleIsChoice) {     // clicked in tertiary menu or text edits
        //if (clickEleIsChoice.id == 'edit-comment' ||   // clicked in an edit box
        //    clickEleIsChoice.id == 'edit-subject') {  
        if (clickEleIsChoice.id == 'edit-comment' ) {  
          // determine if clicked on edit-comment update button
          var thisTarget = e.target;
          if (thisTarget.id == 'edit-comment-button' ){  // do comment update
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
          // This time delay is inserted to avoid critical races at the server!
          var timedelay = 10;
          var timedelayinterval = 250;
          if (document.getElementById('enableQuickStatus').checked){
            var newStatus = document.getElementById('quickStatusValue').value;
            if (clickEleIsTutor){     // clicked on tutor
              if (validTutorStatuses.indexOf(newStatus) >= 0){
                console.log("set tutor status to: " + newStatus);
                currentActivity['action'] = "tutor-status-" + newStatus.toLowerCase(); 
                currentActivity['move_ele_id'] = clickEleIsTutor.id;
                currentActivity['object_id'] = clickEleIsTutor.id;
                currentActivity['object_type'] = objectidToObjecttype(currentActivity['object_id']);
                personupdatestatuskindcomment( currentActivity );
                console.log("testing: " + new Date().toLocaleTimeString() + " no delay.");
                timedelay = timedelay + timedelayinterval;
              }
            } else {                // clicked on student
              if (validStudentStatuses.indexOf(newStatus) >= 0){
                console.log("set student status to: " + newStatus);
                currentActivity['action'] = "student-status-" + newStatus.toLowerCase(); 
                currentActivity['move_ele_id'] = clickEleIsStudent.id;
                currentActivity['object_id'] = clickEleIsStudent.id;
                currentActivity['object_type'] = objectidToObjecttype(currentActivity['object_id']);
                personupdatestatuskindcomment( currentActivity );
                console.log("testing: " + new Date().toLocaleTimeString() + " no delay.");
                timedelay = timedelay + timedelayinterval;
              }
            }
          }
          if (document.getElementById('enableQuickKind').checked){
            var newKind = document.getElementById('quickKindValue').value;
            if (clickEleIsTutor){     // clicked on tutor
              if (validTutorKinds.indexOf(newKind) >= 0){
                console.log("set tutor kind to: " + newKind);
                currentActivity['action'] = "tutor-kind-" + newKind.toLowerCase(); 
                currentActivity['move_ele_id'] = clickEleIsTutor.id;
                currentActivity['object_id'] = clickEleIsTutor.id;
                currentActivity['object_type'] = objectidToObjecttype(currentActivity['object_id']);
                //personupdatestatuskindcomment( currentActivity );
                var currentActivity_hold1 = JSON.parse(JSON.stringify(currentActivity));
                setTimeout(personupdatestatuskindcomment.bind(null, currentActivity_hold1 ), timedelay);
                setTimeout(function(){ console.log("testing: " + new Date().toLocaleTimeString() )}, timedelay);
                timedelay = timedelay + timedelayinterval;
              }
            } else {                // clicked on student
              if (validStudentKinds.indexOf(newKind) >= 0){
                console.log("set student kind to: " + newKind);
                currentActivity['action'] = "student-kind-" + newKind.toLowerCase(); 
                currentActivity['move_ele_id'] = clickEleIsStudent.id;
                currentActivity['object_id'] = clickEleIsStudent.id;
                currentActivity['object_type'] = objectidToObjecttype(currentActivity['object_id']);
                //personupdatestatuskindcomment( currentActivity );
                var currentActivity_hold2 = JSON.parse(JSON.stringify(currentActivity));
                setTimeout(personupdatestatuskindcomment.bind(null, currentActivity_hold2 ), timedelay);
                setTimeout(function(){ console.log("testing: " + new Date().toLocaleTimeString() )}, timedelay);
                timedelay = timedelay + timedelayinterval;
              }
            }
          }
          if (document.getElementById('enableQuickPersonStatus').checked){
            var newPersonStatus = document.getElementById('quickPersonStatusValue').value;
            if (clickEleIsStudent){     // clicked on student, ingnore tutor
              if (validStudentPersonStatuses.indexOf(newPersonStatus) >= 0){
                console.log("set student persontStatus to: " + newPersonStatus);
                currentActivity['action'] = "student-personstatus-" + newPersonStatus.toLowerCase(); 
                currentActivity['move_ele_id'] = clickEleIsStudent.id;
                currentActivity['object_id']   = clickEleIsStudent.id;
                currentActivity['object_type'] = objectidToObjecttype(currentActivity['object_id']);
                //personupdatestatuskindcomment( currentActivity );
                var currentActivity_hold3 = JSON.parse(JSON.stringify(currentActivity));
                setTimeout(personupdatestatuskindcomment.bind(null, currentActivity_hold3 ), timedelay);
                setTimeout(function(){ console.log("testing: " + new Date().toLocaleTimeString() )}, timedelay);
              }
            }
          }
          console.log ("end timedelay: " + timedelay.toString());
          //       <li id="student-personstatus-fortnightly" class="tertiary-menu__choice" data-choice="student-personstatus-fortnightly">
          //          <p>personStatus: Fortnightly</p>
          //       </li>

      } else {    // clicked anywhere else
        var button = e.which || e.button;
        if ( button === 1 ) {
          toggleMenuOff();
          toggleTMenuOff();
        }
      }
    });
  }

/*  
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
    return ele_id.substr(ele_id.length-sf-1-sf, sf);
  }
*/

  // As these are context sensitive menus, we need to determine what actions
  // are displayed.
  // Basically, all items are in the browser page. They are simply shown or
  // hidden depending on what element is right clicked on.
  // Elements identified are tutor, students, lessons and slots.
  // Also, selecting tutors and students in the top of the page (index area) 
  // causes different actions to selecting them in the scheduling section (lesson).
  // Names are choosen to be self explanatory - hopefully.
  function enableMenuItems_calendar(){
    //var thisEleId = taskItemInContext.id;    // element clicked on
    var object_id      = taskItemInContext.id;  // element clicked on.
    var object_type    = objectidToObjecttype(object_id); // 'lesson' 'tutor' or 'student'
    var object_context = objectidToContext(object_id); //'index' or 'lesson'
    var thisEle = document.getElementById(object_id);
    var object_run = taskItemInContext.classList.contains('run'); // true or false
    var scmi_copy = false;          //scmi - set comtext menu items.
    var scmi_move = false;          // to show or not show in menu
    var scmi_moverun = false;       // set the dom display value at end.  
    var scmi_moverunsingle = false;  
    var scmi_paste = false;  
    var scmi_remove = false;
    var scmi_removerun = false;
    var scmi_extendrun = false;
    var scmi_addLesson = false;
    var scmi_extendLessonrun = false;
    var scmi_removeLesson = false;
    var scmi_removeLessonrun = false;
    var scmi_setStatus = false;
    var scmi_setKind = false;
    var scmi_setPersonStatus = false;
    var scmi_editComment = false;
    var scmi_editDetail = false;
    var scmi_history = false;
    var scmi_changes = false;
    var scmi_editSubject = false;
    var scmi_editEntry = false;

    // You can only paste if a source for copy, moverrun or move has been identified.
    if(currentActivity.action  == 'move' ||     // something has been copied,
       currentActivity.action  == 'copy'){      // ready to be pasted
      scmi_paste = true;
    }else if(currentActivity.action  == 'moverun' ||
             currentActivity.action  == 'moverunsingle') {
      // also need to check that the source and target element are in the same week
      // compare object_id(destination element) to currentActivity.object_id(source element)
      //testSuiteForWeekOfYear();   // for testing day of week function
      if(getWeekOfYear(currentActivity.object_id.substring(3,11)).substring(0, 8) == 
         getWeekOfYear(object_id.substring(3,11)).substring(0, 8)){
        scmi_paste = true;
      }
    }

    switch(object_type){     // student, tutor, lesson.
      case 'student':   //student
          scmi_setPersonStatus = true;     // done in both index and main schedule area for student 
      case 'tutor':   //tutor
        if(object_context == 'index'){   // index area
          // this element in student and tutor list
          scmi_copy  = true;
          scmi_paste = false;   //nothing can be pasted into the index space
          //scmi_editComment = true;
          scmi_editDetail  = true; // consistency in context menu naming for user.
          scmi_editSubject = true;
          scmi_editEntry   = true;
          //scmi_setPersonStatus = true;     // only in index area for tutors 
        }else{  // in the main schedule area (lesson)
          scmi_addLesson        = true;
          scmi_extendLessonrun  = true;
          // can only do a moverun if this element contains a class of 'run'
          scmi_extendrun        = true;
          if(taskItemInContext.classList.contains('run')){
            scmi_moverun        = true;
            scmi_moverunsingle  = true;
            scmi_removerun      = true;
            //scmi_extendrun    = true;
          }else{
            scmi_copy = scmi_move = scmi_remove = true;
          }
          scmi_setStatus = scmi_setKind = scmi_editComment = scmi_editDetail = true;
          scmi_history = true;
          scmi_changes = true;
        }
        break;
      case 'lesson':   //lesson which is always in the main scheduling area.
          scmi_move = scmi_addLesson = scmi_setStatus = true;
          scmi_extendLessonrun    = true;
          // if there are no tutors or students in this lesson, can remove
          var mytutors = thisEle.getElementsByClassName('tutor'); 
          var mystudents = thisEle.getElementsByClassName('student');
          if( (mytutors && mytutors.length == 0 )  &&
              (mystudents && mystudents.length == 0 )  ){
            scmi_removeLesson = true;
            scmi_removeLessonrun = true;
          }
          scmi_editComment = true;
          break;
      case 'slot':   //slot which is always in the main scheduling area.
          scmi_addLesson = true;
          break;
    }
    
    // Here we simply hide or show the menu items based on above settings.
    setscmi('context-move', scmi_move);
    setscmi('context-moverun', scmi_moverun);
    setscmi('context-moverunsingle', scmi_moverunsingle);
    setscmi('context-copy', scmi_copy);
    setscmi('context-paste', scmi_paste);
    setscmi('context-remove', scmi_remove);
    setscmi('context-removerun', scmi_removerun);
    setscmi('context-extendrun', scmi_extendrun);
    setscmi('context-addLesson', scmi_addLesson);
    setscmi('context-extendLessonRun', scmi_addLesson);
    setscmi('context-removeLesson', scmi_removeLesson);
    setscmi('context-removeLessonrun', scmi_removeLessonrun);
    setscmi('context-setStatus', scmi_setStatus);
    setscmi('context-setKind', scmi_setKind);
    setscmi('context-setPersonStatus', scmi_setPersonStatus);
    setscmi('context-editComment', scmi_editComment);
    setscmi('context-editDetail', scmi_editDetail);
    setscmi('context-editSubject', scmi_editSubject);
    setscmi('context-history', scmi_history);
    setscmi('context-changes', scmi_changes);
    setscmi('context-editEntry', scmi_editEntry);
  }
  

  //***********************************************************************
  // Helper function                                                      *
  // Pass: date in text format "yyyymmdd"                                 *
  // Return: Week of year in format yyyy-Wdd                              *
  //***********************************************************************

function testSuiteForWeekOfYear(){
      // for testing only!!!!
      // https://en.wikipedia.org/wiki/ISO_week_date
      testWeekOfYear("20050101", '2004-W53-6');
      testWeekOfYear("20050102", '2004-W53-7');
      testWeekOfYear("20051231", '2005-W52-6');
      testWeekOfYear("20060101", '2005-W52-7');
      testWeekOfYear("20060102", '2006-W01-1');
      testWeekOfYear("20061231", '2006-W52-7');
      testWeekOfYear("20070101", '2007-W01-1');
      testWeekOfYear("20071230", '2007-W52-7');
      testWeekOfYear("20071231", '2008-W01-1');
      testWeekOfYear("20080101", '2008-W01-2');
      testWeekOfYear("20081228", '2008-W52-7');
      testWeekOfYear("20081229", '2009-W01-1');
      testWeekOfYear("20081230", '2009-W01-2');
      testWeekOfYear("20081231", '2009-W01-3');
      testWeekOfYear("20090101", '2009-W01-4');
      testWeekOfYear("20091231", '2009-W53-4');
      testWeekOfYear("20100101", '2009-W53-5');
      testWeekOfYear("20100102", '2009-W53-6');
      testWeekOfYear("20100103", '2009-W53-7');
      testWeekOfYear("20100104", '2010-W01-1');
}

  function testWeekOfYear(mydate, expect){
    var outputtext = mydate + "=>" + expect; 
    var myresult = getWeekOfYear(mydate); 
    if (myresult == expect){
      console.log(outputtext + "  OK" );
    }else{
      console.log(outputtext + "  FAILED got " + myresult);
    }
  }

  function getWeekOfYear(stringDate){
    var mySourceDate = new Date(stringDate.substring(0,4) + '-' +
                                stringDate.substring(4,6) + '-' + 
                                stringDate.substring(6,8));
    var myyear = parseInt(stringDate.substring(0,4), 10);
    // determine start of dow (day of week) year.
    var temp = new Date(myyear + '-01-04');    // must occur in first week
    var mydow = temp.getUTCDay();              // get day of week for this date
    mydow = mydow == 0 ? 7 : mydow;            // convert from java dow - Sunday becomes day 7.
    var SourceStartCurrentYear = new Date(temp.getTime() - ((mydow - 1) * 24 * 3600000)); // first day of dow year
    //console.log("SourceStartCurrentYear: " + SourceStartCurrentYear.toUTCString());
    var myDiff = mySourceDate.getTime() - SourceStartCurrentYear.getTime();
    var weekOfYear = myDiff / (7 * 24 * 3600000);   // still one week out!!! adjusted later
    var weekYear = myyear;                          // track the week_of_year year.
    var weekday = mySourceDate.getUTCDay();
    weekday = weekday == 0 ? 7 : weekday;
    if( myDiff < 0 ){          // check if the last week in the prevous year
      temp = new Date((myyear - 1) + '-01-04');
      mydow = temp.getUTCDay();
      mydow = mydow == 0 ? 7 : mydow; 
      var SourceStartPrevYear = new Date(temp.getTime() - ((mydow - 1) * 24 * 3600000));
      //console.log("SourceStartPrevYear: " + SourceStartPrevYear.toUTCString());
      weekOfYear = (mySourceDate.getTime() - SourceStartPrevYear.getTime()) / (7 * 24 * 3600000);
      weekYear = myyear - 1;
    }else if (weekOfYear > 50){
      // check if it is in the first week in the next year
      temp = new Date((myyear + 1) + '-01-04');
      mydow = temp.getUTCDay();
      mydow = mydow == 0 ? 7 : mydow; 
      var SourceStartNextYear = new Date(temp.getTime() - ((mydow - 1) * 24 * 3600000));
      //console.log("SourceStartNextYear: " + SourceStartNextYear.toUTCString());
      myDiff = mySourceDate.getTime() - SourceStartNextYear.getTime();
      if(myDiff >= 0){
        weekOfYear = myDiff / (7 * 24 * 3600000);
        weekYear = myyear + 1;
      }
    }
    weekOfYear= Number(String(1 + weekOfYear).replace(/\..*/,""));    // truncate
    var weekYearWeek = weekYear + (weekOfYear < 10 ? '-W0' : '-W') + weekOfYear + '-' + weekday;
    //console.log(stringDate + "=>" + weekYearWeek);
    //console.log("week of year: " + weekOfYear);
    //console.log("week of year: " + weekYearWeek);
    return weekYearWeek;
  }

  //***********************************************************************
  // Perform the actions invoked by the context menu items.                *
  // Some actions will invoke a second level (tertialy) menu.              *
  //***********************************************************************
  // action is the element clicked on in the menu.
  // The menu element clicked on has an attribute "data-action" that 
  // describes the required action.

  // currentActivity['action'] = thisAction;             //**update**
  // currentActivity['object_id'] = thisEleId;           //**update**
  // currentActivity['object_type'] = thisEleId -> type; //**update**
  // currentActivity['to'] = thisEleId;                  //**update**

  function menuItemActioner_calendar( action ) {
    //dom_change['action'] = "move";
    //dom_change['move_ele_id'] = ui.draggable.attr('id');
    //dom_change['ele_old_parent_id'] = document.getElementById(dom_change['move_ele_id']).parentElement.id;
    //dom_change['ele_new_parent_id'] = this.id;
    //dom_change['element_type'] = "lesson";
    toggleMenuOff();
    var thisAction =  action.getAttribute("data-action");
    // taskItemInContext is a global variable set when context menu first invoked.
    var thisEleId = taskItemInContext.id;    // element 'right clicked' on
    var thisEle = document.getElementById((thisEleId));

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
      if(!('object_id' in currentActivity)){   // must be something to paste from.
        return;
      }
      currentActivity['to']   = thisEleId;  // everthing else required is still there.
    } else {
      // but for all other actions, we need to set action, element_id and 
      // the old (pre-manimpulation) parent of the element being manipulated.
      // i.e. tutor and student -> nearest session as old parent
      //      session           -> nearest slot as old parent
      currentActivity = {};                             // clear array.
      currentActivity['action']      = thisAction;      
      //currentActivity['move_ele_id'] = thisEleId;
      currentActivity['object_id']   = thisEleId;     
      currentActivity['object_type'] = objectidToObjecttype(currentActivity['object_id']);
      thisEle = document.getElementById(thisEleId);
    }

    switch( thisAction ) {     
      case "copy":
      case "move":
      case "moverun":
      case "moverunsingle":
        // Nothing else to do, need a paste before any action can be taken!!!
        break;
      case "extendrun":
          switch (currentActivity['object_type']) {
            case 'student':   //student
            case 'tutor':   //tutor
              personupdateslesson_Update( currentActivity );      //**update**
              break;
          }
        break;
      case "paste":
        //Note, we need the action for the move/copy, not paste.
        // On dropping, need to move up parent tree of the destination element
        // till find the appropriate parent
        //console.log(currentActivity);
        if( currentActivity ) {   // been a cut or move initiated so can do a paste
          // based on the type of element we are moving
          // Note, currentActiviey['move_ele_id'/'object_id]'is the element right clicked on when
          // copy or move was selected - held over in this variable.
          currentActivity['to'] = thisEleId;         //**update**
          //*switch ( getRecordType(currentActivity['move_ele_id']) ) {
          switch (currentActivity['object_type']) {
            //*case 's':   //student
            //*case 't':   //tutor
            case 'student':   //student
            case 'tutor':   //tutor
              // find the 'lesson' element in the tree working upwards
              // as thisEle is the dom location we are moving this element to.
              //*currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['lesson']).id;
              //******************************************************
              // Need the database changes and manipulation called here
              //******************************************************
              personupdateslesson_Update( currentActivity );      //**update**
              //----- contained in currentActivity ------------(example)
              //  move_ele_id: "Wod201705301600s002",
              //  ele_old_parent_id: "Wod201705301600n001", 
              //  element_type: "student"
              //  ele_new_parent_id: "Wod201705291630n003"
              //----------required in ajax (domchange)---------------------------------
              break;
            //*case 'n':   //lesson
            case 'lesson':   //lesson
              // find the 'slot' element in the tree working upwards
              // as thisEle is the dom location we are moving this element to.
              //*currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['slot']).id;
              lessonupdateslot_Update( currentActivity );
              break;
          }
          currentActivity = {};     // clear when done - can't paste twice.
        }  // end of if currentActivity
        // Of course, if there is no currentActivity on a paste, then ignore.
        break;
      case "remove":
      case "removerun":
        // This removed the selected element
        // Actually deletes the mapping record for tutor and student
        deleteentry_Update(currentActivity);
        break;
      case "addLesson":
        // This will add a new lesson within the slot holding the element clicked.
        // Will add a new lesson record with this slot value.
        addLesson_Update(currentActivity);
        break;
      case "extendLessonrun":
        // This will extend the clicked on lesson to the end of the parent slot chain.
        extendLessonrun_Update(currentActivity);
        break;
      case "removeLesson":
      case "removeLessonrun":
        // For removeLesson - This will remove a lesson clicked on.
        // For removeLessonrun - This will remove the lessons in the chain including and followig 
        // the lesson clicked on.
        // Will delete the lesson record for a lesson only if empty 
        // i.e. not tutors or students.
        // This is needed as no matter what element was clicked on, we still need
        // to find the nearest slot - prevous setting could have been tutor 
        // finding lesson as parent.
        removeLesson_Update(currentActivity);
        break;
      case "setStatus":
        // Set Status has been selected on an element.
        // It will open up another menu to select the status required.
        // This will set the status of this item (tutor, student, lesson).
        enableTertiaryMenu(currentActivity);
        break;
      case "setKind":
        // Set Kind has been selected on an element.
        // It will open up another menu to select the status requried.
        // This will set the status of this item (tutor, student, lesson).
        enableTertiaryMenu(currentActivity);
        break;
      case "setPersonStatus":
        // Set Person Status has been selected on an element.
        // It will open up another menu to select the status requried.
        // This will set the status of this item (tutor, student).
        enableTertiaryMenu(currentActivity);
        break;
      case "editDetail":
        // this case edits the tutor or student comment when we have clicked 
        // on the student or tutor in the scheduler area.
        // This is actioned by making believe that we have clicked on this 
        // tutor or student in the index area, then let editComment take its
        // course. (Hence no break after this section!)
        // generate the element id of this person in the index area
        // and override existing values.
        // We need to get the comment text which is to be edited.
        // This has to be obtained from the appropriate location in the html doc.
        if(currentActivity['object_type'] == 'tutor'   ||
           currentActivity['object_type'] == 'student'    ){
           var thisPersonComment = thisEle.getElementsByClassName('p-comment')[0].innerHTML;
        }else{
           return;
        }
        // Now that we have the text, we need to place it into the text eniting 
        // field in the browser doc and then show it in the tertiary menu.
        document.getElementById('edit-comment-text').value = thisPersonComment;
        document.getElementById('edit-comment-elementid').innerHTML = thisEleId;
        document.getElementById('edit-comment-action').innerHTML = thisAction;
        enableTertiaryMenu(currentActivity);
        break;

      case "editComment":
        // Edit Comment has been selected on an element.
        // It will open up a text field to key in your updates.
        // This will update the relevant comment.*/
        // We need to get the comment text which is to be edited.
        // This has to be obtained from the appropriate location in the html doc.
        if(currentActivity['object_type'] == 'tutor'   ||
           currentActivity['object_type'] == 'student'    ){
           var thisComment = thisEle.getElementsByClassName('np-comment')[0].innerHTML;
        }else if(currentActivity['object_type'] == 'lesson' ){
           thisComment = thisEle.getElementsByClassName('n-comments')[0].innerHTML;
        }else{
          return;
        }
        // Now that we have the text, we need to place it into the text eniting 
        // field in the browser doc and then show it in the tertiary menu.
        document.getElementById('edit-comment-text').value = thisComment;
        document.getElementById('edit-comment-elementid').innerHTML = thisEleId;
        document.getElementById('edit-comment-action').innerHTML = thisAction;
        enableTertiaryMenu(currentActivity);
        break;

      case "editSubject":
        // Edit Subject has been selected on an element.
        // It will open up a text field to key in your updates.
        // This will update the relevant subject.
        // The editing dialogue is the same one as for editing
        // comments.
        // We need to get the subject text which is to be edited.
        // This has to be obtained from the appropriate location in the html doc.
        if(currentActivity['object_type'] == 'tutor'  ){
           var thisSubjects = thisEle.getElementsByClassName('p-subjects')[0].innerHTML;
        }else if(currentActivity['object_type'] == 'student'    ){
           thisSubjects = thisEle.getElementsByClassName('p-study')[0].innerHTML;
        }else{
          return;
        }
        // Now that we have the text, we need to place it into the text eniting 
        // field in the browser doc and then show it in the tertiary menu.
        document.getElementById('edit-comment-text').value = thisSubjects;
        document.getElementById('edit-comment-elementid').innerHTML = thisEleId;
        document.getElementById('edit-comment-action').innerHTML = thisAction;
        enableTertiaryMenu(currentActivity);
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
        if(currentActivity['object_type'] == 'tutor' ||
           currentActivity['object_type'] == 'student' ){
          var parseId = currentActivity['object_id'].match( /\w(\d+)$/);
          var myurl = myhost + '/' + currentActivity['object_type'] + 's/' + parseId[1] + '/edit';
        }else{
          return;
        }
        window.open(myurl, '_blank');
        break;
      case "editEntry":
        // Edit tutor has been selected on an element.
        // Want to open the tutor edit screen.
        // url is "https//:myhost/tutors or students/n/edit"
        if(currentActivity['object_type'] == 'tutor' ||
           currentActivity['object_type'] == 'student' ){
          parseId = currentActivity['object_id'].match( /\w(\d+)$/);
          myurl = myhost + '/' + currentActivity['object_type'] + 's/' + parseId[1] + '/edit';
        }else{
          return;
        }
        window.open(myurl, '_blank');
        break;
      }
  }
  
  // This determines what is displayed in the tertiary menu.
  // It is context sensitive so depends on what element is
  // right clicked on.
  //function enableTertiaryMenu(etmEle, etmAction, currentActivity){
  function enableTertiaryMenu(currentActivity){
    // ** etm    = element tertiary menu **
    // etmEle    = original element right clicked on - tutor, student, lesson.
    // etmAction = action selected within the primary context menu.
    var etmAction = currentActivity['action'];
    // Need to add another context menu with selection choices
    // based on action and move_ele_id
    // etmAction = action of the first (main) context menu e.g set tutor status
    var recordType = currentActivity['object_type'];
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
    var stmi_tutor_kind_fifteen       = false;

    var stmi_student_status_scheduled = false;
    var stmi_student_status_attended  = false;
    var stmi_student_status_bye       = false;
    var stmi_student_status_deal      = false;
    var stmi_student_status_absent    = false;
    var stmi_student_status_away      = false;
    var stmi_student_status_queued    = false;

    var stmi_student_kind_free        = false;
    var stmi_student_kind_first       = false;
    var stmi_student_kind_catchup     = false;
    var stmi_student_kind_fortnightly = false;
    var stmi_student_kind_onetoone    = false;
    var stmi_student_kind_standard    = false;
    var stmi_student_kind_bonus       = false;

    var stmi_student_personstatus_new          = false;
    var stmi_student_personstatus_fortnightly  = false;
    var stmi_student_personstatus_onetoone     = false;
    var stmi_student_personstatus_standard     = false;
    var stmi_student_personstatus_inactive     = false;

    var stmi_lesson_status_oncall     = false;
    var stmi_lesson_status_onsetup    = false;
    var stmi_lesson_status_free       = false;
    var stmi_lesson_status_onbfl      = false;
    var stmi_lesson_status_standard   = false;
    var stmi_lesson_status_routine    = false;
    var stmi_lesson_status_flexible   = false;
    var stmi_lesson_status_allocate   = false;
    var stmi_lesson_status_global     = false;
    var stmi_lesson_status_park       = false;

    var stmi_edit_comment             = false;
    var stmi_edit_subject             = false;
    
    // First, identify type of element being actioned e.g. tutor, lesson, etc..
    switch(recordType){
      case 'tutor':   // tutor
        // Now show the tertiary choices for this element.
        switch(etmAction){
          case 'setStatus':   // tutor set Status options
            stmi_tutor_status_scheduled = true;   // stmi - set tertiary menu item
            stmi_tutor_status_notified  = true;
            stmi_tutor_status_confirmed = true;
            stmi_tutor_status_attended  = true;
            stmi_tutor_status_deal      = true;
            stmi_tutor_status_absent    = true;
            stmi_tutor_status_away      = true;
            break;
          case 'setKind':   // tutor set Kind options
            stmi_tutor_kind_bfl         = true;
            stmi_tutor_kind_oncall      = true;
            stmi_tutor_kind_onsetup     = true;
            stmi_tutor_kind_training    = true;
            stmi_tutor_kind_standard    = true;
            stmi_tutor_kind_called      = true;
            stmi_tutor_kind_relief      = true;
            stmi_tutor_kind_fifteen     = true;
            break;
          case 'editComment':   // show the text edit box & populate
          case 'editSubject':   // show the text edit box & populate
          case 'editDetail':
            stmi_edit_comment           = true;
            break;
        }     // switch(etmAction)
        break;
      case 'student':   // student
        // Now show the tertiary choices for this element.
        switch(etmAction){
          case 'setStatus':   // student set Status options
            stmi_student_status_scheduled = true;
            stmi_student_status_attended  = true;
            stmi_student_status_bye       = true;
            stmi_student_status_deal      = true;
            stmi_student_status_absent    = true;
            stmi_student_status_away      = true;
            stmi_student_status_queued    = true;
            break;
          case 'setKind':   // student set Kind options
            stmi_student_kind_free        = true;            
            stmi_student_kind_first       = true;
            stmi_student_kind_catchup     = true;
            stmi_student_kind_fortnightly = true;
            stmi_student_kind_onetoone    = true;
            stmi_student_kind_standard    = true;
            stmi_student_kind_bonus       = true;
            break;
          case 'setPersonStatus':   // student set student status options
            stmi_student_personstatus_new          = true;
            stmi_student_personstatus_fortnightly  = true;
            stmi_student_personstatus_onetoone     = true;
            stmi_student_personstatus_standard     = true;
            stmi_student_personstatus_inactive     = true;
            break;
          case 'editComment':   // show the text edit box & populate
          case 'editSubject':
          case 'editDetail':
            stmi_edit_comment             = true;
            break;
        }     // switch(etmAction)
        break;

      case 'lesson':   //lesson
        // Now show the tertiary choices for this element.
        switch(etmAction){
          case 'setStatus':   // lesson set Status options
            stmi_lesson_status_oncall     = true;
            stmi_lesson_status_onsetup    = true;
            stmi_lesson_status_free       = true;
            stmi_lesson_status_onbfl      = true;
            stmi_lesson_status_standard   = true;
            stmi_lesson_status_routine    = true;
            stmi_lesson_status_flexible   = true;
            stmi_lesson_status_allocate   = true;
            stmi_lesson_status_global     = true;
            stmi_lesson_status_park       = true;
            break;
          case 'editComment':   // show the text edit box & populate
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
    setscmi('tutor-kind-fifteen', stmi_tutor_kind_fifteen);

    setscmi('student-status-scheduled', stmi_student_status_scheduled);
    setscmi('student-status-attended', stmi_student_status_attended);
    setscmi('student-status-bye', stmi_student_status_bye);
    setscmi('student-status-deal', stmi_student_status_deal);
    setscmi('student-status-absent', stmi_student_status_absent);
    setscmi('student-status-away', stmi_student_status_away);
    setscmi('student-status-queued', stmi_student_status_queued);

    setscmi('student-kind-free', stmi_student_kind_free);            
    setscmi('student-kind-first', stmi_student_kind_first);
    setscmi('student-kind-catchup', stmi_student_kind_catchup);
    setscmi('student-kind-fortnightly', stmi_student_kind_fortnightly);
    setscmi('student-kind-onetoone', stmi_student_kind_onetoone);
    setscmi('student-kind-standard', stmi_student_kind_standard);
    setscmi('student-kind-bonus', stmi_student_kind_bonus);

    setscmi('student-personstatus-new', stmi_student_personstatus_new);
    setscmi('student-personstatus-fortnightly', stmi_student_personstatus_fortnightly);
    setscmi('student-personstatus-onetoone', stmi_student_personstatus_onetoone);
    setscmi('student-personstatus-standard', stmi_student_personstatus_standard);
    setscmi('student-personstatus-inactive', stmi_student_personstatus_inactive);

    setscmi('lesson-status-oncall', stmi_lesson_status_oncall);
    setscmi('lesson-status-onsetup', stmi_lesson_status_onsetup);
    setscmi('lesson-status-free', stmi_lesson_status_free);
    setscmi('lesson-status-on_BFL', stmi_lesson_status_onbfl);
    setscmi('lesson-status-standard', stmi_lesson_status_standard);
    setscmi('lesson-status-routine', stmi_lesson_status_routine);
    setscmi('lesson-status-flexible', stmi_lesson_status_flexible);
    setscmi('lesson-status-allocate', stmi_lesson_status_allocate);
    setscmi('lesson-status-global', stmi_lesson_status_global);
    setscmi('lesson-status-park', stmi_lesson_status_park);

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
    toggleTMenuOff();
    currentActivity['action']      = choice.getAttribute("data-choice"); // thisChoice
    currentActivity['move_ele_id'] = taskItemInContext.id;   // thisEleId
    currentActivity['object_id']   = taskItemInContext.id;   // thisEleId
    personupdatestatuskindcomment( currentActivity );
  }

  // This actions the text editing results following the person editing
  // the text and pressing update.
  function editCommentSubjectActioner(editButton){
    // thisTarget.id is one of two options:
    // - 'edit-comment-button'

    // First step is to get required details from text edit box 
    // Gets updated commment + id of the comment field + action taken.
    if (editButton == 'edit-comment-button'){
      //var thisComment = document.getElementById('edit-comment-text').value;
      currentActivity['object_id']   = document.getElementById('edit-comment-elementid').innerHTML;
      currentActivity['object_type'] = objectidToObjecttype(currentActivity['object_id']);
      //object_dbId = currentActivity['object_id'].match(/\w(\d+)$/);
      //currentActivity['action']      = currentActivity['object_type'] + '-comment-edit';
      currentActivity['action']      = document.getElementById('edit-comment-action').innerHTML;
      currentActivity['updatevalue'] = document.getElementById('edit-comment-text').value;
      if(currentActivity['object_type'] == 'tutor'){
        if(currentActivity['action'] == 'editComment'){
          currentActivity['updatefield'] = 'comment';
          currentActivity['controller'] = 'tutrole';
          currentActivity['url-action'] = "/tutorupdateskc"; 
        }else if(currentActivity['action'] == 'editDetail'){
          currentActivity['updatefield'] = 'comment';
          currentActivity['controller'] = 'tutor';
          currentActivity['url-action'] = "/tutordetailupdateskc"; 
        }else if(currentActivity['action'] == 'editSubject'){
          currentActivity['updatefield'] = 'subjects';
          currentActivity['controller'] = 'tutor';
          currentActivity['url-action'] = "/tutordetailupdateskc"; 
        }
      }else if(currentActivity['object_type'] == 'student'){
        if(currentActivity['action'] == 'editComment'){
          currentActivity['updatefield'] = 'comment';
          currentActivity['controller'] = 'role';
          currentActivity['url-action']  = "/studentupdateskc";
        }else if(currentActivity['action'] == 'editDetail'){
          currentActivity['updatefield'] = 'comment';
          currentActivity['controller']  = 'student';
          currentActivity['url-action']  = "/studentdetailupdateskc";
        }else if(currentActivity['action'] == 'editSubject'){
          currentActivity['updatefield'] = 'study';
          currentActivity['controller']  = 'student';
          currentActivity['url-action']  = "/studentdetailupdateskc";
        }
      }else if(currentActivity['object_type'] == 'lesson'){
        if(currentActivity['action'] == 'editComment'){
          currentActivity['updatefield'] = 'comments';
          currentActivity['controller']  = 'lesson';
          currentActivity['url-action']  = "/lessonupdateskc";

        }
      }
    }
    // now update the database, then the dom.
    personupdatecommentsubject( currentActivity );
  } 
  
  //***********************************************************************
  // End of performing the actions invoked by the context menu items.     *
  //***********************************************************************
  

  init();

  //------------------------ End of Context Menu -----------------------------


  //----------------- Get history of Tutor or Student ------------------------
  //This function is called to get a student or tutor history
  //Does ajax to get the student or tutor history
  function getHistory(domchange){
    // domchange['action']      = thisChoice;
    // domchange['object_id'] = thisEleId;
    var parseid = currentActivity['object_id'].match(/\w(\d+)$/);
    //var mydata = {'domchange' : domchange};
    // url format: myhost + "/students/history/" + personid;
    var myurl = myhost + "/" + domchange['object_type'] + "s/history/" + parseid[1];
    $.ajax({
        type: "GET",
        url: myurl,
        //data: mydata,
        dataType: "json",
        context: domchange,

        success: function(data, textStatus, xhr){
          showhistory(data);
        },
        error: function(xhr){
          var error_message = "";
          if (typeof xhr.responseText == 'string'){
            error_message = xhr.responseText;
          }else{
            var errors = $.parseJSON(xhr.responseText);
            for (var error in (errors['person_id'])){     // lesson_id ??????
              error_message += " : " + errors['person_id'][error];
            }
          }
          alert('error fetching history for ' + domchange['object_type'] +
                error_message);
                
            // old verions
            //var errors = $.parseJSON(xhr.responseText);
            //var error_message = "";
            //for (var error in (errors['person_id'])){
            //  error_message += " : " + errors['person_id'][error];
            //}
            //alert('error fetching history for ' + 
            //       domchange['object_type'] + ': ' + error_message);
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

  //----- Update Tutor, Student or Lesson -> Comment, subject ----------
  // This function is called to update: student, tutor, lesson, tutrole, role records
  // with one of comment or subjects. 
  // Called from the tertiary context menu.
  // Does ajax to update the record
  function personupdatecommentsubject( domchange ){
    // domchange['action']    = thisChoice;  // in tertiary menu
    // domchange['object_id'] = thisEleId; //=moveEleId
    var mydata = {'domchange' : domchange};
    //var action = domchange['action'];   //update status or kind with value
    //var object_type = domchange['object_type'];
    var myurl = myhost + domchange['url-action'];
    delete domchange['url-action'];
    console.log('in personupdatecommentsubject');

    $.ajax({
        type: 'POST',
        url: myurl,
        data: mydata,
        dataType: "json",
        context: domchange,

        success: function(result1, result2, result3){
            console.log("personupdatecommentsubject Ajax response OK");
            //moveelement_update( result1 );
        },
        error: function(xhr){
          var error_message = "";
          if (typeof xhr.responseText == 'string'){
            error_message = xhr.responseText;
          }else{
            var errors = $.parseJSON(xhr.responseText);
            for (var error in (errors['person_id'])){     // lesson_id ??????
              error_message += " : " + errors['person_id'][error];
            }
          }
          alert('error updating ' + domchange['object_type'] +
                ' '  + domchange['updatefield'] + ': ' + error_message);
            //var errors = $.parseJSON(xhr.responseText);
            //var error_message = "";
            //for (var error in (errors['person_id'])){
            //  error_message += " : " + errors['person_id'][error];
            //}
            //alert('error updating ' + domchange['object_type'] +
            //      ' '  + domchange['updatefield'] + ': ' + error_message);
        }
     });
  }

  //----- Update Tutor, Student or Lesson -> Status, Kind or Comment ----------
  //This function is called to update a student or tutor record
  // with one of status, kind or comment. 
  // Called from the tertiary context menu.
  //Does ajax to update the student or tutor record
  function personupdatestatuskindcomment( domchange ){
    // domchange['action']    = thisChoice;  // in tertiary menu
    // domchange['object_id'] = thisEleId; //=moveEleId
    console.log( "personupdatestatuskindcomment: " + new Date().toLocaleTimeString() );
    console.dir(domchange);
    var mydata = {'domchange' : domchange};
    var action = domchange['action'];   //update status or kind with value
    var object_type = domchange['object_type'];
    // Need to determine the context - index or lession
    if(domchange['object_id'].match(/^[ts]\d+$/)){
      var personContext = 'index';
    }else{
      personContext = 'lesson';
    }
    // action = "student-status-deal"
    // var updatefield = 'status';
    // var updatevalue = 'deal';
    var parseaction = action.match(/^(\w+)-(\w+)-(\w+)$/);
    var updatefield = parseaction[2];
    var updatevalue = parseaction[3];
    var controllertype = 'role';
    // this check only applies to status changes in the session
    if(updatefield == 'status' &&
       object_type == 'student')   {
      // if current value is 'away', then need to warn the user
      var current_status_value1 = document.getElementById(domchange['object_id']).getElementsByClassName('np-status')[0].innerHTML;
      var current_status_match = current_status_value1.match(/status: (\w+)/i);
      if((current_status_match != null) &&
         (current_status_match[1] == 'away')){
        console.log('we are moveing away for a status of AWAY');
        if(!confirm("Are your sure?  \n" + 
                    "Changing status from AWAY has significant implications!!!! \n" +
                    "You will need to clean up all the catchups.")){
          return;
        }
      }
    }
    // can now make the generic status manipulation - status and person.
    if(updatefield == 'personstatus'){ // treated differently - update person record
      updatefield = 'status';
      controllertype = 'person';
    }
    if (updatefield == 'subject' && object_type == 'tutor') {
      updatefield = 'subjects';
    }
    domchange['updatefield'] = updatefield;
    domchange['updatevalue'] = updatevalue;
 
    //redefine action for processing dom after ajax call.
    domchange['action'] = 'set';
    var myurl;
    if( 'student' == object_type ){       // student
      if ( personContext == 'lesson') {   // scheduler portion of page
        if(controllertype == 'person'){   // student detail status + subject
          myurl = myhost + "/studentdetailupdateskc"; 
          domchange['action'] = 'setDetail';
        }else{    // session/student status, kind, comment
          myurl = myhost + "/studentupdateskc";   // skc = status, kind, comment
        }
      } else {        // index portion of page
        myurl = myhost + "/studentdetailupdateskc";   // student detail status + subject
        domchange['action'] = 'setDetail';
      }
    }else if ( 'tutor' == object_type){    // tutor
      if ( personContext == 'lesson') {
        if(controllertype == 'person'){   // student detail status + subject
          myurl = myhost + "/tutordetailupdateskc";   // skc = status, kind, comment + subject
          domchange['action'] = 'setDetail';
        }else{    // session/student status, kind, comment
          myurl = myhost + "/tutorupdateskc";   // skc = status, kind, comment + subject
        }
      } else {        // index
        myurl = myhost + "/tutordetailupdateskc";   //
        domchange['action'] = 'setDetail';
      }
    }else if ( 'lesson' == object_type){     // lesson
        myurl = myhost + "/lessonupdateskc";   // skc = status, kind, comment
    } else {
      console.log("error - the record being updated is not a tutor, student or lesson");
      return;
    }

    $.ajax({
        type: 'POST',
        url: myurl,
        data: mydata,
        dataType: "json",
        context: domchange,
        success: function(result1, result2, result3){
          console.log("personupdatestatuskindcomment: ajax response OK");
          //moveelement_update( result1 );
        },
        error: function(xhr){
          var error_message = "";
          if (typeof xhr.responseText == 'string'){
            error_message = xhr.responseText;
          }else{
            var errors = $.parseJSON(xhr.responseText);
            for (var error in (errors['person_id'])){     // lesson_id ??????
              error_message += " : " + errors['lesson_id'][error];
            }
          }
          alert('error updating ' + domchange['object_type'] +
                ' '  + updatefield + ': ' + error_message);
        }
     });
  }

  // ------------------------- Draggable History -----------------------------   
  // Draggable history container
    $(".histories").on('mouseover', '.history', function(){
      $(this).draggable();
    });

  //----------------------- Drag and Drop - Calendar -------------------------
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
        dom_change['object_id'] = ui.draggable.attr('id');
        dom_change['object_type'] = objectidToObjecttype(dom_change['object_id']);
        dom_change['to'] = this.id;
        lessonupdateslot_Update( dom_change );
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
        var dom_change = {};
        dom_change['action'] = "move";
        dom_change['object_id'] = ui.draggable.attr('id');
        dom_change['object_type'] = objectidToObjecttype(dom_change['object_id']);
        dom_change['to'] = this.id;
        //
        //m = ele_object.id.match(/^(\w+\d+l\d+)/);
        //var ele_slot_forobject = document.getElementById(m[1]);
        if( dom_change['object_id'].match(/^[st]/)){  // drag from the index area
          dom_change['action'] = "copy";
        } else {                                      // from calendar area
          var eleFrom = document.getElementById(dom_change['object_id']);
          if(eleFrom.classList.contains("run")){       // a chain element
            dom_change['action'] = "moverun";
          }else{
            dom_change['action'] = "move";
          }
        }
        personupdateslesson_Update( dom_change );

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
  
  elementdraggable(".student, .tutor");
  lessondroppable(".lesson");
  
//---------------------- End of Drag and Drop - calendar ---------------------

//----- Common Functions used by both Drag & Drop and Context Menu ---------

  //************************** AJAX ***************************************
  // Ajax functions in this section are:
  //function deleteentry_Update( domchange ){
  //function personupdateslesson_Update( domchange ){
  //function addLesson_Update(domchange){
  //function removeLesson_Update(domchange){
  //function lessonupdateslot_Update( domchange ){
  //------------------------------------------------------------------------

  // delete one of tutor or student 
  function deleteentry_Update( domchange ){
    var itemtype = domchange['object_type'];
    var mytype = 'POST';
    var mydata =  { 'domchange' : domchange };
    var myurl = myhost + "/remove" + itemtype + "fromlesson";
    $.ajax({
        type: mytype,
        url: myurl,
        data: mydata,
        dataType: "json",
        context: domchange,
        success: function(){
            //moveelement_update(domchange);
            console.log("deleteentry_Update Ajax response OK");
        },
        error: function(xhr){
            var error_message = "";
            if (typeof xhr.responseText == 'string'){
              error_message = xhr.responseText;
            }else{
              var errors = $.parseJSON(xhr.responseText);
              for (var error in (errors['lesson_id'])){     // lesson_id ??????
                error_message += " : " + errors['lesson_id'][error];
              }
            }
            alert("error deleting entries: \n" + error_message);
        }
        // old version
        //error: function(request, textStatus, errorThrown){
        //    console.log("ajax error occured: " + request.status.to_s + " - " + textStatus );
        //    alert("ajax error occured: " + request.status.to_s + " - " + textStatus );
        //}
    });
  }

  function removeLesson_Update(domchange){
    var myurl = myhost + "/lessonremove/";
    $.ajax({
        type: "DELETE",
        url: myurl,
        data: {'domchange' : domchange },
        dataType: "json",
        context: domchange,
        success: function(result1, result2, result3){
            console.log("removeLesson_Update Ajax response OK");
            //moveelement_update(result1);
        },
        error: function(xhr){
            var error_message = "";
            if (typeof xhr.responseText == 'string'){
              error_message = xhr.responseText;
            }else{
              var errors = $.parseJSON(xhr.responseText);
              for (var error in (errors['lesson_id'])){     // lesson_id ??????
                error_message += " : " + errors['lesson_id'][error];
              }
            }
            alert("error deleting lessons: \n" + error_message);
        }

        //error: function(request, textStatus, errorThrown){
            //alert("ajax error occured: " + request.status.to_s + " - " + textStatus );
            //var temp = request.responseJSON.base;
            //var errorText = "";
            //for(var i=0; i<temp.length; i++){
            //  errorText += temp[i] + "\n";
            //}
            //console.log("ajax error occured: " + request.status.to_s + " - " + textStatus  + "\n" + errorText);
            //alert("ajax error occured\n" + request.status.to_s + " - " + textStatus + "\n" + errorText);
        //}
    });
  }

  //This function is called for either move or copy
  //Does ajax to move or copy a student or tutor to another lesson
  
  // Update the approach to only use these parameters:
  // currentActivity['action'] = thisAction;           //**update**
  // currentActivity['object_id'] = thisEleId;         //**update**
  // currentActivity['to'] = thisEleId;                //**update**
  // currentActivity['from'] = populated by the controller
  // currentActivity['object_type'] = populated by the controller
  // Note: ['to'] and / or ['from'] can be nil for some actions.
  
  function personupdateslesson_Update( domchange ){
    //var action = domchange['action'];   //move or copy
    var object_type = domchange['object_type'];
    var myurl;
    var mydata;
    if(domchange['action'] != 'extendrun'){
      if(isParentSame(domchange)){  // ignore if dropped in same location
        return;
      }
    }
    mydata =  { 'domchange' : domchange  };
    if( 'student' == object_type || 'tutor'  == object_type){
      myurl = myhost + '/' + object_type + 'movecopylesson/'; 
    } else {
      return;
    }
    $.ajax({
        type: "POST",
        url: myurl,
        data: mydata,
        dataType: "json",
        context: domchange,
        success: function(result1, result2, result3){
            console.log("personupdateslesson_Update Ajax response OK");
            //moveelement_update(result1);
        },
        error: function(xhr){
          var error_message = "";
          if (typeof xhr.responseText == 'string'){
            error_message = xhr.responseText;
          }else{
            var errors = $.parseJSON(xhr.responseText);
            for (var error in (errors['lesson_id'])){     // lesson_id ??????
              error_message += " : " + errors['lesson_id'][error];
            }
          }
          alert("error moving student or tutor to another lesson: \n" + 
                domchange['object_type'] + ' '  + 
                domchange['updatefield'] + ': ' + error_message);
            //var errors = $.parseJSON(xhr.responseText);
            //var error_message = "";
            //if (typeof errors == 'string'){
            //  error_message = errors;
            //}else{
            //  for (var error in (errors['lesson_id'])){
            //    error_message += " : " + errors['lesson_id'][error];
            //  }
            //}
            //alert("error moving student or tutor to another lesson: \n" + error_message);
        }
     });
  }

  function lessonupdateslot_Update( domchange ){
    if(isParentSame(domchange)){
      return;
    }
    var myurl = myhost + "/lessonmoveslot";
    $.ajax({
        type: "POST",
        url: myurl,
        data: {'domchange' : domchange },
        dataType: "json",
        context: domchange,
        success: function(result1, result2, result3){
            console.log("lessonupdateslot_Update Ajax response OK");
            //moveelement_update(result1);
        },
        error: function(request, textStatus, errorThrown){
            console.log("ajax error occured: " + request.status.to_s + " - " + textStatus );
            alert("ajax error occured: " + request.status.to_s + " - " + textStatus );
        }
    });
  }

  function addLesson_Update(domchange){
    domchange["status"] = "free";  // make default for new session.
    var myurl = myhost + "/lessonadd/";
    $.ajax({
        type: "POST",
        url: myurl,
        data: {'domchange' : domchange },
        dataType: "json",
        context: domchange,
        success: function(result1, result2, result3){
            console.log("addLesson_Update Ajax response OK");
            //moveelement_update(result1);
        },
        error: function(request, textStatus, errorThrown){
            //$(this).addClass( "processingerror" );
            alert("ajax error occured: " + request.status.to_s + " - " + textStatus );
        }
    });
  }

  function extendLessonrun_Update(domchange){
    var myurl = myhost + "/lessonextend/";
    $.ajax({
        type: "POST",
        url: myurl,
        data: {'domchange' : domchange },
        dataType: "json",
        context: domchange,
        success: function(result1, result2, result3){
            console.log("addLesson_Update Ajax response OK");
            //moveelement_update(result1);
        },
        error: function(request, textStatus, errorThrown){
            //$(this).addClass( "processingerror" );
            alert("ajax error occured: " + request.status.to_s + " - " + textStatus );
        }
    });
  }


  //********************* END AJAX ***************************************


/*  
  function padleft(num, sigfig){
    var numstr = num.toString();
    var temp = "";
    for(var i = sigfig - (numstr.length); i--;){
      temp = temp + "0";
    }
    return temp + numstr;
  }
*/

/*************************************************************************** 
   This is the major function for manipulation of DOM.
****************************************************************************/
  function moveelement_update( domchange ){
    // This approach allows for the source element not being present on the page
    // or even the destination element may not reside on this page.
    // Web sockets allows all pages to be updated indepent of the dates choosen.
    //
    // domchange['action']        = action to be taken on object.;
    // domchange['object_id']     = thisEleId of element acted on;
    // domchange['object_type']   = type of element acted on;
    // domchange['to']            = destination parent_id to be moved to;
    // domchange['from']          = source parent_id previously attached to. 
    // domchange['html_partial']  = the html for this element generated in
    //                              the controller.
    // domchange['object_id_old'] = move & copy: original id of object;
    //
    // Note: The 'to', 'from' & 'object_id_old' will be populated by the
    //       controller as required.
    //       Also, they will be nil for some actions.
    //
    // The logic for parents is:
    // ele_parent_from/to = the parent of type slot or lesson.
    // ele_parent_from/to_place = the exact parent DOM location to place the html,
    //                            exact location can vary based on the objec type.

    // ------------- common initialisation for all operations ---------------
    
    //if( domchange['actioncable'] ){
    //  console.log("moveelement_update processing - passed through action cable");
    //}else{
    //  console.log("moveelement_update processing - passed through Ably");
    //}
    //console.log(domchange);
    var action      = domchange['action'];
    var object_type = domchange['object_type'];
    var ele_object  = document.getElementById(domchange['object_id']);
    if('html_partial' in domchange){    // partial html passed from controller
      // build the dom object to be inserted from the html segment
      var elecreated = document.createElement('div');
      elecreated.innerHTML = domchange['html_partial'];
      var eletoplace = elecreated.getElementsByClassName(object_type)[0]; 
    }
    // ------------- if replacement of element required ---------------
    // if this is a replace, we simply find the element and replace with
    // the html_partial.
    var ele_to_replace = null;
    if (action == 'replace'){
      if('object_id' in domchange){    // dom object to replace
        ele_to_replace = document.getElementById(domchange['object_id']);
        if (eletoplace){
          ele_to_replace.parentNode.replaceChild(eletoplace, ele_to_replace);
          elementdraggable(eletoplace);
          selectshows_scoped(document, eletoplace);
        }
      }
    }
    // ------------- if removal of element required ---------------
    // if this is a move, we need to make use of object_old for removal.
    // For copy, nothing is removed.
    // all other actions act on the object_id
    var ele_to_remove = null;
    if (action == 'move'){
      if('object_id_old' in domchange){    // dom object to delete
        ele_to_remove = document.getElementById(domchange['object_id_old']);
      }
    }else if (action == 'removeLesson' ||
              action == 'remove'){
      ele_to_remove = document.getElementById(domchange['object_id']);
    }
    // for cases where an old element exists (e.g. remove, move), 
    // delete it if still in the dom - may have already been deleted!.
    if (ele_to_remove != null) {    // still there, delete.
      // something to remove if action is move, leave if action is copy
      ele_to_remove.parentNode.removeChild(ele_to_remove);
    }
    
    // 'to' will be populated if logic requires it.
    // required for move and copy.
    var ele_parent_to = null;
    if('to' in domchange){
      ele_parent_to = document.getElementById(domchange['to']);
    }
    
    // ------------- if adding element required ---------------
    if (ele_object == null) {   // this element is not on this page
      if (action == 'move' ||   // if this is a move or copy
          action == 'copy'  ||
          action == 'addLesson'){
        if(ele_parent_to != null) {   // and there is a place to insert  
          // Ensure there is a place on the page to put this object
          // as possiblity this user is not viewing the region this object is 
          // being moved to.
          
          // get the parent slot for 'to' - needed to update show hide comments etc.
          var m = ele_parent_to.id.match(/^(\w+\d+l\d+)/);
          var ele_slot_to = document.getElementById(m[1]);

          // place tutor or student into destination
          // map specific tutor or student var names generic for this section.
          if (object_type == 'tutor' || object_type == 'student') {    // person
            var grouppersons = 'group' + object_type + 's';
            var personnameclass = object_type + 'name'; 
            // correct placement within the tutor arrangment
            var ele_parent_to_place = ele_parent_to.getElementsByClassName(grouppersons)[0];
            // need to place tutor in alphabethical order
            var name = domchange['name'];
            var mypersons = ele_parent_to_place.getElementsByClassName(object_type);
            if (mypersons.length != 0) {    // have tutors
              var flagInserted = false;
              var myperson;
              for (let i = 0; i < mypersons.length; i++){
                myperson = mypersons[i];
                var mypersonname = myperson.getElementsByClassName(personnameclass)[0].innerHTML;
                console.log(mypersonname);
                if (mypersonname.toLowerCase() > name.toLowerCase()){
                  ele_parent_to_place.insertBefore(eletoplace, myperson);
                  flagInserted = true;
                  break;
                }
              }
              if(flagInserted == false) {
                ele_parent_to_place.append(eletoplace);
              }
            } else {  // no tutors/students, just add.
              console.log ("no tutors / students");
              ele_parent_to_place.insertBefore(eletoplace, ele_parent_to_place.firstChild);
            }
            elementdraggable(eletoplace);
            selectshows_scoped(document, ele_slot_to);
          }
          if (object_type == 'lesson') {    // lesson
            // correct placement within the slot arrangment
            ele_parent_to_place = ele_parent_to;
            // variables required for the sort.
            var lessontutorname_to_place = '';    // always empty for a added lesson.
            var status_to_place = eletoplace.getElementsByClassName('lessonstatusinfo')[0].innerHTML.toLowerCase().trim();
            // lessons to sort through to determine where to place this item.
            var mylessons = ele_parent_to_place.getElementsByClassName(object_type);
            if (mylessons) {    // have lessons
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
                var sortresult = lessonsortorder(status_to_place, lessontutorname_to_place, mylessonstatus, mylessontutorname );
                if (sortresult > -1){
                  ele_parent_to_place.insertBefore(eletoplace, mylesson);
                  flagInserted = true;
                  break;
                }
              }
              if(flagInserted == false) {
                ele_parent_to_place.append(eletoplace);
              }
            } else {  // no lessons in this slot, just add.
              ele_parent_to_place.append(eletoplace);
              //lessonsparent.insertBefore(eletoplace, ele_parent_to_place.firstChild);
            }
            //elementdraggable(".lesson");
            elementdraggable(eletoplace);
            lessondroppable(eletoplace);
            //make all tutor and children draggable
            var mytutors = eletoplace.getElementsByClassName('tutor');
            for (let i = 0; i < mytutors.length; i++){
              elementdraggable(mytutors[i]);
              selectshows_scoped(document, mytutors[i]);
            }
            var mystudents = eletoplace.getElementsByClassName('student');
            for (let i = 0; i < mystudents.length; i++){
              elementdraggable(mystudents[i]);
              selectshows_scoped(document, mystudents[i]);
            }
          }
        }
      }
    }else{      // this element is on the page
                // ele_object is current element being updated
                // eletoplace is to replace ele_obj
      if (action == 'set' ||
          action == 'editComment'){   // if updating aspects of this element.
        console.log("setting status");
        if('updatefield' in domchange){     // updatefield is present
          if(object_type == 'tutor' ||
             object_type == 'student'){   
            m = ele_object.id.match(/^(\w+\d+l\d+)/);
            var ele_slot_forobject = document.getElementById(m[1]);
            ele_object.parentNode.replaceChild(eletoplace, ele_object);
            elementdraggable(eletoplace);
            selectshows_scoped(document, ele_slot_forobject);
          }else if(object_type == 'lesson'){   // lesson
            // for the lesson, we will just update the fields
            // = comments or status
            // overhead on regenerating the lesson object is quite high!
            if(domchange['updatefield'] == 'status'){    // do lesson status
              var eleStatus = ele_object.getElementsByClassName('n-status')[0];
              eleStatus.innerHTML = 'Status: ' + domchange['updatevalue'];
              var these_classes = ele_object.classList;
              // scan these classes for our class of interest
              these_classes.forEach(function(thisClass, index, array){
                if (thisClass.includes('n-status-')) {     // n-status-
                  ele_object.classList.remove(thisClass);  // remove & update later
                }
              });
              ele_object.classList.add('n-status-' + domchange['updatevalue']); // add updated class
            }
            if(domchange['updatefield'] == 'comments'){    // do lesson comment
              var comment_text_ele = ele_object.getElementsByClassName("n-comments")[0];
              comment_text_ele.innerHTML = domchange["updatevalue"];
            }
          }
        }
      }
      // special case - on how to check if updates are required.
      // setdetail is updating info on the tutor or student
      // this can occur multiple times on a page!
      if (action == 'setDetail' ||
          action == 'editDetail' ||
          action == 'editSubject'){   // if updating aspects of this element.
        if('updatefield' in domchange){     // updatefield is present
          //ele_object = object being updated (student or tutor detail)
          var updatefield = domchange['updatefield'];
          var updatevalue = domchange['updatevalue'];
          // first update this entry in the index area
          var ele_toupdate = ele_object.getElementsByClassName('p-' + updatefield)[0];
          if (ele_toupdate) {
            if(updatefield == 'status'){
              ele_toupdate.innerHTML = 'Detail: ' + updatevalue;
            }else if(updatefield == 'comment'){
              ele_toupdate.innerHTML = updatevalue;
            }else if(updatefield == 'subjects'){
              ele_toupdate.innerHTML = updatevalue;
            }else if(updatefield == 'study'){
              ele_toupdate.innerHTML = updatevalue;
            }
          } 
          // now do all the people in the schedule area.
          var eles_toupdate = document.getElementsByClassName('f' + domchange['object_id']);
          for (let i = 0; i < eles_toupdate.length; i++){
            ele_toupdate = eles_toupdate[i].getElementsByClassName('p-' + updatefield)[0];
            if (ele_toupdate) {
              if(updatefield == 'status'){
                ele_toupdate.innerHTML = 'Detail: ' + updatevalue;
              }else if(updatefield == 'comment'){
                ele_toupdate.innerHTML = updatevalue;
              }else if(updatefield == 'subjects'){
                ele_toupdate.innerHTML = updatevalue;
              }else if(updatefield == 'study'){
                ele_toupdate.innerHTML = updatevalue;
              }
            } 
          }
        }
      }
    }
  }

  // provides the sort order for lessons within the slot
  // Becomes complicated as the order is different with postgreql
  // and javascript with stringcomparisions.
  function lessonsortorder(a_status, a_name, b_status, b_name){
    // item1 = [lesson_status, tutor_name]
    // the following statuses must be first on the page
    var baseorder = ['status: oncall', 'status: onsetup', 'status: free',
                     'status: on_bfl', 'status: standard', 'status: routine',
                     'status: flexible', 'status: allocate', 'status: global',
                     'status: park'];
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
      //console.log ("a_status: " + a_status + " aindex: " + aindex + "b_status: " + b_status + " bindex: " + bindex);
      return (aindex > bindex  ? -1 : 1 ); 
    } 
    if (aindex > -1) {
      //console.log ("a_status: " + a_status + " aindex: " + aindex);
      return 1; 
    } 
    if (bindex > -1) {
      //console.log ("b_status: " + b_status + " bindex: " + bindex);
      return -1; 
    }
    // if get to here, do normal alphabetical order check on status
    // remember we have already checked for equal status.
    return (a_status > b_status ? 1 : -1 );

  }

//--- End of Common Functions used by both Drag & Drop and Context Menu ----


  $("#personInput").keyup(filterPeople);

};    //************************** !!!!!!!!!!!!!!!!!!!! **********************

//--------- Filter by name functions for the tutors and students -----------
function filterPeople(){
  hideshowperson('tutor');
  hideshowperson('student');
}

// This function will hide the names in the index area.
// can do students and tutors separately.
function hideshowperson (searchClass ){    // 'student' or 'tutor'
  var eleIndexPersons = document.getElementById("index-" + searchClass + "s");
  var filter = document.getElementById("personInput").value.toUpperCase();
  if(! eleIndexPersons.classList.contains("hideme")){
    var eleAllPersons = eleIndexPersons.getElementsByClassName(searchClass);
    for (var i = 0; i < eleAllPersons.length; i++) {
        var personNameText = eleAllPersons[i].getElementsByClassName('p-name')[0].innerHTML.toUpperCase();
        if (personNameText.indexOf(filter) > -1) {
            eleAllPersons[i].style.display = "";
        } else {
            eleAllPersons[i].style.display = "none";
        }
    }
  }
}

//------ End of Filter by name functions for the tutors and students -------

function selectshows_scoped(ele_checkbox, ele_scope) {
  console.log("called selectshows_scoped");
  if(ele_checkbox == document) {
    // Need to process all checklists
    console.log ('this is called with passed element being document');
    var myShowList = document.getElementById("selectshows");
    if (myShowList == null){
      return;
    }
    var showList = document.getElementById("selectshows").getElementsByTagName("input");
  }else{
    // Need to only process the one just ticked or unticked.
    showList = [ele_checkbox];
  }
  //var flagcomments = false;
  // if I have hidden both tutors and students, then also hide "index"
  var hidetutors_state = document.getElementById("hidetutors").checked;
  var hidestudents_state = document.getElementById("hidestudents").checked;
  for(var i = 0; i < showList.length; i++){
    //console.log("case: " + showList[i].id);
    switch(showList[i].id){
      case "hidetutors":
        // first check if either students or tutors need to be displayed.
        if(hidetutors_state || hidestudents_state) {
          document.getElementById('index-tutor-students').classList.remove("hideme");
        }else{
          document.getElementById('index-tutor-students').classList.add("hideme");
        }
        // now specific display for tutors
        if (showList[i].checked){
          document.getElementById("index-tutors").classList.remove("hideme");
          hideshowperson('tutor');
        }else{
          document.getElementById("index-tutors").classList.add("hideme");
        }
        break;
      case "hidestudents":
        // first check if either students or tutors need to be displayed.
        if(hidetutors_state || hidestudents_state) {
          document.getElementById('index-tutor-students').classList.remove("hideme");
        }else{
          document.getElementById('index-tutor-students').classList.add("hideme");
        }          
        // now specific display for students
        if (showList[i].checked){
          document.getElementById("index-students").classList.remove("hideme");
          hideshowperson('student');
        }else{
          document.getElementById("index-students").classList.add("hideme");
        }
        break;
      case "hidecomments":    // will hide all comments
        showhidecomments(ele_scope.getElementsByClassName("comment"),
        showList[i].checked);
        break;
      case "hidetutorlessoncomments":
        //if  (!flagcomments) {   // if all comments selected, stop here
        showhidecomments(ele_scope.getElementsByClassName("tutrolecomment"),
        showList[i].checked);
        break;
      case "hidestudentlessoncomments":
        //if  (!flagcomments) {   // if all comments selected, stop here
        showhidecomments(ele_scope.getElementsByClassName("rolecomment"),
        showList[i].checked);
        break;
      case "hidetutorcomments":
        showhidecomments(ele_scope.getElementsByClassName("tutorcommentdetail"),
        showList[i].checked);
        break;
      case "hidestudentcomments":
        showhidecomments(ele_scope.getElementsByClassName("studentcommentdetail"),
        showList[i].checked);
        break;
      case "hidelessonsOncall":
        showhidecomments(ele_scope.querySelectorAll(".lesson.n-status-onCall"),
        showList[i].checked);
        break;
      case "hidelessonsOnsetup":
        showhidecomments(ele_scope.querySelectorAll(".lesson.n-status-onSetup"),
        showList[i].checked);
        break;
      case "hidelessonsOnBFL":
        showhidecomments(ele_scope.querySelectorAll(".lesson.n-status-on_BFL"),
        showList[i].checked);
        break;
      case "hidelessonsFree":
        showhidecomments(ele_scope.querySelectorAll(".lesson.n-status-free"),
        showList[i].checked);
        break;
      case "hidelessonsStandard":
        showhidecomments(ele_scope.querySelectorAll(".lesson.n-status-standard"),
        showList[i].checked);
        break;
      case "hidelessonsRoutine":
        showhidecomments(ele_scope.querySelectorAll(".lesson.n-status-routine"),
        showList[i].checked);
        break;
      case "hidelessonsFlexible":
        showhidecomments(ele_scope.querySelectorAll(".lesson.n-status-flexible"),
        showList[i].checked);
        break;
      case "hidelessonsAllocate":
        showhidecomments(ele_scope.querySelectorAll(".lesson.n-status-allocate"),
        showList[i].checked);
        break;
      case "hidelessonsGlobal":
        showhidecomments(ele_scope.querySelectorAll(".lesson.n-status-global"),
        showList[i].checked);
        break;
      case "hidelessonsPark":
        showhidecomments(ele_scope.querySelectorAll(".lesson.n-status-park"),
        showList[i].checked);
        break;
      case "enableQuickStatus":
        // do nothing - ignore.
        break;
      case "enableQuickKind":
        // do nothing - ignore.
        break;
      case "enableQuickPersonStatus":
        // do nothing - ignore.
        break;
      case "selectdowone":
        showhidedowone();
        break;
      case "selectdowtwo":
        showhidedowtwo();
        break;
      case "selectdowthree":
        showhidedowthree();
        break;
      case "selectdowfour":
        showhidedowfour();
        break;
      case "selectdowfive":
        showhidedowfive();
        break;
      default:    // hides sites based on checklists
        var thispattern = /hide(.*)/;
        //console.log("showList[i].id: " + showList[i].id);
        var m = thispattern.exec(showList[i].id);
        if( m ){
          //console.log("m: " + m[1]);
          var siteid = 'site-' + m[1];
          //console.log("siteid: " + siteid);          
          if (showList[i].checked){
            document.getElementById(siteid).classList.remove("hideme");
          }else{
            document.getElementById(siteid).classList.add("hideme");
          }
        }
    }
  }
}

function selectshows(ele_checkbox) {
  console.log("called selectshows");
  console.dir(ele_checkbox);
  selectshows_scoped(ele_checkbox, document);
}


function showhidecomments(theseelements, tohide) {
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


//var ready_stats = function(){
function ready_stats(){

/*//No longer needed with Ably
  //App.cable.subscriptions.create("CalendarChannel", {  
  App.stats = App.cable.subscriptions.create("StatsChannel", {  
    received: function(data) {
      console.log("calendar.js - entered ws received function for stats");
      console.dir(data);
      //var returnedDomData = JSON.parse(data['json']);
      var returnedStatsData = data['json'];
      returnedStatsData['actioncable'] = true;
      stats_update(returnedStatsData);
      console.log("stats update done!!!");
      return;
    }
  });
*/

  ably = new Ably.Realtime({ authUrl: '/auth' });
  // Set up to subscribe to the Ably messages
  var statsChannel = ably.channels.get('stats');
  statsChannel.subscribe(function(message){
    console.log("calendar.js - entered ably subscribe function for stats");
    console.dir(message.data);
    var returnedStatsData = message.data;
    returnedStatsData['ably'] = true;
    stats_update(returnedStatsData);
    console.log("stats update done!!!");
  });
  var statsChannelListener = function(stateChange) {
    console.log('stats channel state is ' + stateChange.current);
    console.log('previous state was ' + stateChange.previous);
    if(stateChange.reason) {
      console.log('the reason for the state change was: ' + stateChange.reason.toString());
    }
  };
  statsChannel.on(statsChannelListener);
  
  console.log("entered ready_status");
  showcatchup();
  showfree();
  showstats();
  showslotlessons();
 
  showhidedowone();  
  showhidedowtwo();  
  showhidedowthree();  
  showhidedowfour();  
  showhidedowfive();  
  
  showhidesites();

  $("#personInput").keyup(hideshowstudent);
  
  init_stats();

  // Initialise our application's code for stats.
  // Made modular so that you have more control over initialising them. 
  function init_stats() {
    menu_common();
    contextListener_stats();
    clickListener_stats();
    keyupListener();
    resizeListener();
  }

  // Listens for contextmenu events.
  // Add the listeners for the main menu items.
  // contextmenu is an integrated javascript library function.
  // We detect the element right clicked on and position the context
  // menu adjacent to it.
  function contextListener_stats() {
    document.addEventListener( "contextmenu", function(e) {
      menu = document.querySelector("#context-menu");
      // this function passes in the event
      taskItemInContext = clickInsideElementClassList( e, taskItemClassList_stats);
      // this caters for the 'allocation' of catchups on the stats screen.
      // allocate is only populated with the id when it is a valid element to click on.
      // As such, if allocate is clicked on, but has no id, then we need to
      // propagate up the ancestry chain till we get the 'student' element.
      if(taskItemInContext && (taskItemInContext.id == '')){
        // this function passes in the dom element
        taskItemInContext = clickInsideElementClassList2( taskItemInContext.parentNode, taskItemClassList_stats);
      }
      if( taskItemInContext ) {
        e.preventDefault();
        enableMenuItems_stats();
        toggleMenuOn();
        clickPosition = getPosition(e);  // global variable
        positionMenu(menu);
        eleClickedOn = e;                 // global variable
      } else {
        taskItemInContext = null;
        toggleMenuOff();
      }
    });
  }

  // As these are context sensitive menus, we need to determine what actions
  // are displayed.
  // Basically, all items are in the browser page. They are simply shown or
  // hidden depending on what element is right clicked on.
  // Elements identified are tutor, students, lessons and slots.
  // Also, selecting tutors and students in the top of the page (index area) 
  // causes different actions to selecting them in the scheduling section (lesson).
  // Names are choosen to be self explanatory - hopefully.
  function enableMenuItems_stats(){
    var object_id      = taskItemInContext.id;  // element clicked on.
    var object_type    = objectidToObjecttype(object_id); // 'lesson' 'tutor' or 'student'
    var object_context = objectidToContext(object_id); //'index' or 'lesson'
    //var thisEle = document.getElementById(object_id);
    var scmi_copy = false;  //scmi - set comtext menu items.
    var scmi_move = false;  // to show or not show in menu
    var scmi_paste = false;  // set the dom display value at end.
    switch(object_type){     // student, tutor, lesson.
      case 'student':   //student
      case 'tutor':   //tutor
      case 'lesson':
        if(object_context == 'index'){   // index area
          // this element in student and tutor list
          scmi_move = true;
          scmi_paste = false;   //nothing can be pasted into the index space
        }
        break;
      case 'slot':   //slot
        if(object_context == 'lesson'){   // index area
          // this element in student and tutor list
          // You can only paste if a source for copy or move has been identified.
          if(currentActivity.action  == 'move' || // something has been copied,
             currentActivity.action  == 'copy'){  // ready to be pasted
            scmi_paste = true;
          }
        }
        break;
    }
    // Here we simply hide or show the menu items based on above settings.
    setscmi('context-move', scmi_move);
    setscmi('context-copy', scmi_copy);
    setscmi('context-paste', scmi_paste);
  }
  
  // Listens for click events on context menu items element.
  // On selection an item on the context menu, an appropriate action is triggered.
  function clickListener_stats() {
    document.addEventListener( "click", function(e) {
      console.log("in clickListerner");
      console.dir(currentActivity);
      // determine if clicked inside main context menu.
      var clickEleIsAction   = clickInsideElementClassList( e, [contextMenuItemClassName]);
      if ( clickEleIsAction ) {      // clicked in main context menu
        e.preventDefault();
        menuItemActioner_stats( clickEleIsAction );   // call main menu item actioner.
      } else {    // clicked anywhere else
        var button = e.which || e.button;
        if ( button === 1 ) {
          toggleMenuOff();
          toggleTMenuOff();
        }
      }
    });
  }

  //***********************************************************************
  // Perform the actions invoked by the context menu items.                *
  // Some actions will invoke a second level (tertialy) menu.              *
  //***********************************************************************
  // action is the element clicked on in the menu.
  // The menu element clicked on has an attribute "data-action" that 
  // describes the required action.

  // currentActivity['action'] = thisAction;             //**update**
  // currentActivity['object_id'] = thisEleId;           //**update**
  // currentActivity['object_type'] = thisEleId -> type; //**update**
  // currentActivity['to'] = thisEleId;                  //**update**

  function menuItemActioner_stats( action ) {
    //dom_change['action'] = "move";
    //dom_change['move_ele_id'] = ui.draggable.attr('id');
    //dom_change['ele_old_parent_id'] = document.getElementById(dom_change['move_ele_id']).parentElement.id;
    //dom_change['ele_new_parent_id'] = this.id;
    //dom_change['element_type'] = "lesson";
    toggleMenuOff();
    var thisAction =  action.getAttribute("data-action");
    // taskItemInContext is a global variable set when context menu first invoked.
    //var thisEleId = taskItemInContext.id;    // element 'right clicked' on
    //var parentTaskItemInContext;
    //if(taskItemInContext.id == null){    // no id so ignore - go to parent with valid class
    //  taskItemInContext = clickInsideElementClassList( taskItemInContext.parentNode, taskItemClassList_stats);
    //}
    var thisEleId = taskItemInContext.id;    // element 'right clicked' on
    
    //var thisEle = document.getElementById((thisEleId));

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
      if(!('object_id' in currentActivity)){   // must be something to paste from.
        return;
      }
      //currentActivity['to']   = thisEleId;  // everthing else required is still there.
    } else {
      // but for all other actions, we need to set action, element_id and 
      // the old (pre-manimpulation) parent of the element being manipulated.
      // i.e. tutor and student -> nearest session as old parent
      //      session           -> nearest slot as old parent
      currentActivity = {};                             // clear array.
      currentActivity['action']      = thisAction;      
      //currentActivity['move_ele_id'] = thisEleId;
      // need to get the session/student to be copied from thisEleId
      var catchupId = null;
      var thisEle = document.getElementById(thisEleId);
      // where are we going to copy from - i.e. which session
      // If a specific lesson is selected, then copy it.
      // If 'person' is selected generically, then copy the earliest lesson.
      console.log(" need to select the lesson");
      if(thisEleId.match(/^allocate/)){    // reallocate an already allocated lesson
        catchupId = thisEle.getAttribute('data-domid');
      }else{   // allocate from the global - oldest first
        var catchupList = thisEle.getElementsByClassName('personlessons')[0].getElementsByClassName('personlesson');
        if(catchupList){
          for (var i=0; i < catchupList.length; i++ ){
            var catchupEle = catchupList[i];
            //.getAttribute("data-action")
            //if(catchupEle.getElementsByClassName('allocate')[0].innerHTML == ''){ // empty, need allocating
            if(catchupEle.getElementsByClassName('allocate')[0].getAttribute("data-domid") == ''){ // empty, need allocating
              //catchupId = catchupEle.getElementsByClassName('global')[0].innerHTML;
              catchupId = catchupEle.getElementsByClassName('global')[0].getAttribute("data-domid");
              break;
            }
          }
        }
      }
      currentActivity['move_ele_id'] = catchupId;
      //currentActivity['object_id']   = thisEleId;     
      currentActivity['object_id']   = catchupId;     
      //currentActivity['object_type'] = objectidToObjecttype(currentActivity['object_id']);
      currentActivity['object_type'] = objectidToObjecttype(catchupId);
      //thisEle = document.getElementById(thisEleId);
    }

    switch( thisAction ) {     
      case "copy":
      case "move":
        // Nothing else to do, need a paste before any action can be taken!!!
        
        break;
      case "paste":
        //Note, we need the action for the move/copy, not paste.
        // On dropping, need to move up parent tree of the destination element
        // till find the appropriate parent
        //console.log(currentActivity);
        if( currentActivity ) {   // been a cut or move initiated so can do a paste
          // based on the type of element we are moving
          // Note, currentActiviey['move_ele_id'/'object_id]'is the element right clicked on when
          // copy or move was selected - held over in this variable.
          //currentActivity['to'] = thisEleId;         //**update**
          currentActivity['to_slot'] = thisEleId;         //**update**
          //*switch ( getRecordType(currentActivity['move_ele_id']) ) {
          switch (currentActivity['object_type']) {
            //*case 's':   //student
            //*case 't':   //tutor
            case 'student':   //student
            //case 'tutor':   //tutor
              // find the 'lesson' element in the tree working upwards
              // as thisEle is the dom location we are moving this element to.
              //*currentActivity['ele_new_parent_id'] = clickInsideElementClassList2(thisEle, ['lesson']).id;
              //******************************************************
              // Need the database changes and manipulation called here
              //******************************************************
              personupdateslesson_Update_stats( currentActivity );      //**update**
              //----- contained in currentActivity ------------(example)
              //  move_ele_id: "Wod201705301600s002",
              //  ele_old_parent_id: "Wod201705301600n001", 
              //  element_type: "student"
              //  ele_new_parent_id: "Wod201705291630n003"
              //----------required in ajax (domchange)---------------------------------
              break;
          }
          currentActivity = {};     // clear when done - can't paste twice.
        }  // end of if currentActivity
        // Of course, if there is no currentActivity on a paste, then ignore.
        break;
      }
  }


  //----------------------- Drag and Drop - stats -------------------------
  // This is the drag and drop code
  // which uses ajax to update the database
  // the drag reverts if database update fails.

  // for moving the lessons
  function elementdraggable_stats(myelement){
    $(myelement).draggable({
      revert: true,
      zIndex: 100,
      //comments display on click, remove when begin the drag
      drag: function(event, ui) {
        console.dir(ui);
        console.dir(event);
        $(this).addClass('make-transparent');
      },
      start: function(event, ui) {
        $('#comments').css('visibility', 'hidden');  
      },
      stop: function(event, ui) {
        $(this).removeClass('make-transparent');
      }
    });
  }

  function slotdroppable_stats(myelement){
    $(myelement).droppable({
      accept: ".student, .allocate",
      drop: function( event, ui ) {
        var dom_change = {};
        dom_change['action'] = "move";
        //var ele_moved = ui.draggable;
        var thisEle = ui.draggable[0];
        var catchupId;
        var flagCatchupFound = false;
        if (thisEle.id.match(/^allocate/)) {
          catchupId = thisEle.getAttribute('data-domid');
          flagCatchupFound = true;
        }else{
          var catchupList = thisEle.getElementsByClassName('personlessons')[0].getElementsByClassName('personlesson');
          if(catchupList){
            for (var i=0; i < catchupList.length; i++ ){
              var catchupEle = catchupList[i];
              //.getAttribute("data-action")
              //if(catchupEle.getElementsByClassName('allocate')[0].innerHTML == ''){ // empty, need allocating
              if(catchupEle.getElementsByClassName('allocate')[0].getAttribute("data-domid") == ''){ // empty, need allocating
                //catchupId = catchupEle.getElementsByClassName('global')[0].innerHTML;
                catchupId = catchupEle.getElementsByClassName('global')[0].getAttribute("data-domid");
                flagCatchupFound = true;
                break;
              }
            }
          }
        }
        if(flagCatchupFound == false){
          return;
        }
        dom_change['object_id'] = catchupId;
        dom_change['move_ele_id'] = catchupId;
        dom_change['object_type'] = objectidToObjecttype(catchupId);
        dom_change['to_slot'] = this.id;
        console.log("drag and drop dropped.");
        personupdateslesson_Update_stats( dom_change );      //**update**
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

  elementdraggable_stats(".student, .allocate");
  slotdroppable_stats(".slot");
  
//---------------------- End of Drag and Drop - stats ---------------------

  function personupdateslesson_Update_stats( domchange ){
    //var action = domchange['action'];   //move or copy
    var object_type = domchange['object_type'];
    var myurl;
    var mydata;
    // Parent cannot be the same in stats.
    //if(isParentSame(domchange)){  // ignore if dropped in same location
    //  return;
    //}
    // show that this is initiated in stats page
    domchange['allocation'] = 'stats';
    mydata =  { 'domchange' : domchange  };
    if( 'student' == object_type || 'tutor'  == object_type){
      myurl = myhost + '/' + object_type + 'movecopylesson/'; 
    } else {
      return;
    }
    $.ajax({
        type: "POST",
        url: myurl,
        data: mydata,
        dataType: "json",
        context: domchange,
        success: function(result1, result2, result3){
            console.log("personupdateslesson_Update_Stats Ajax response OK");
            stats_student_update(result1);
            //moveelement_update(result1);
        },
        error: function(xhr){
            var errors = $.parseJSON(xhr.responseText);
            var error_message = "";
            for (var error in (errors['lesson_id'])){
              error_message += " : " + errors['lesson_id'][error];
            }
            alert("error moving student or tutor to another lesson: " + error_message);
        }
     });
  }
  
  // this function updates the student details:
  // populates the 'allocate' div with the new lesson details
  // This is caleed from the ajax response NOT a Web Socket propagation.
  function stats_student_update(domchange){
    console.log('entered stats_student_update');
    if(domchange['to_slot']) {   // processing correct move
      var fromObjectId = domchange['object_id_old'];
      var toObjectId   = domchange['object_id'];
      var m = toObjectId.match(/^([A-Za-z]+)(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/);
      var h = m[5];
      if(m[5] > 12) {h = m[5] - 12 }
      var d = new Date(m[2],m[3]-1,m[4],h,m[6]);
      var toObjectText = m[1];
          m = d.toString().match(/^(.*)\:\d\d\s+GMT/);
          toObjectText = toObjectText + ' ' + m[1];
      var parseToStudentId     = toObjectId.match(/(s\d+)$/);
      var student_domid = parseToStudentId[1];
      if(student_domid){
        var thisEle = document.getElementById(student_domid);
        var catchupList = thisEle.getElementsByClassName('personlessons')[0].getElementsByClassName('personlesson');
        if(catchupList){
          for (var i=0; i < catchupList.length; i++ ){
            var catchupEle = catchupList[i];
            //.getAttribute("data-domid")
            //if(catchupEle.getElementsByClassName('global')[0].innerHTML == fromObjectId){ // lesson of interest
            // could have been copied from either the global or reallocated from the allocate.
            if((catchupEle.getElementsByClassName('global')[0].getAttribute("data-domid") == fromObjectId) ||
               (catchupEle.getElementsByClassName('allocate')[0].getAttribute("data-domid") == fromObjectId)){ // lesson of interest
              //catchupEle.getElementsByClassName('allocate')[0].innerHTML = toObjectId;
              var eleUpdateDomid = catchupEle.getElementsByClassName('allocate')[0];
              eleUpdateDomid.setAttribute("data-domid", toObjectId);
              eleUpdateDomid.innerHTML = toObjectId + ' = ' + toObjectText;
              eleUpdateDomid.id = 'allocate_' + toObjectId;
              break;
            }
          }
        }
      }
    }
  }


  function stats_update( statschange ){
    // This approach updates the stats for the slot if they are shown on the page.
    //
    // statschange['slot_id']     = dom id of the slot to be updated;
    // domchange['html_partial']  = the html for this element generated in
    //                              the controller.

    // ------------- common initialisation for all operations ---------------
    
    if( statschange['actioncable'] ){
      console.log("stats_update processing - passed through action cable");
    }else{
      console.log("stats_update processing - did not passed through action cable");
    }
    console.log(statschange);
    var slot_id      = statschange['slot_id'];
    // build the dom object to be inserted from the html segment
    var elecreated = document.createElement('div');
    elecreated.className = 'statistics';
    elecreated.innerHTML = statschange['html_partial'];
    var eleslot = document.getElementById(slot_id);
    var eletoreplace = eleslot.getElementsByClassName('statistics')[0];
    eletoreplace.parentNode.replaceChild(elecreated, eletoreplace);
    scoped_showhidestats(eleslot);
  }
};

// Filter students in the stats page
function hideshowstudent(){
  var eleIndexPersons = document.getElementById("index-students");
  var filter = document.getElementById("personInput").value.toUpperCase();
  //if(! eleIndexPersons.classList.contains("hideme")){
    var eleAllPersons = eleIndexPersons.getElementsByClassName('student');
    for (var i = 0; i < eleAllPersons.length; i++) {
      var personNameText = eleAllPersons[i].getElementsByClassName('p-name')[0].innerHTML.toUpperCase();
      if (personNameText.indexOf(filter) > -1) {
          eleAllPersons[i].style.display = "";
      } else {
          eleAllPersons[i].style.display = "none";
      }
    }
  //}
}

// hides sites based on checklists
function showhidesites(){
  var thispattern = /hide(.*)/;
  var showList = document.getElementsByClassName('selectsite');
  for(var i = 0; i < showList.length; i++){
    //console.log("showList[i].id: " + showList[i].id);
    var m = thispattern.exec(showList[i].id);
    if( m ){
      //console.log("m: " + m[1]);
      var siteid = 'site-' + m[1];
      //console.log("siteid: " + siteid);          
      if (showList[i].checked){
        document.getElementById(siteid).classList.remove("hideme");
      }else{
        document.getElementById(siteid).classList.add("hideme");
      }
    }
  }
}


function showhidedowone()  {showhidedow('1', 'selectdowone'  );}
function showhidedowtwo()  {showhidedow('2', 'selectdowtwo'  );}
function showhidedowthree(){showhidedow('3', 'selectdowthree');}
function showhidedowfour() {showhidedow('4', 'selectdowfour' );}
function showhidedowfive() {showhidedow('5', 'selectdowfive' );}

function showhidedow(day, selectdowday){
  var myobjects = document.getElementsByClassName('dow' + day);
  if (document.getElementById(selectdowday).checked){
    for(var i = 0; i < myobjects.length; i++){
      myobjects[i].classList.remove("hideme");
    }
  }else{
    for(i = 0; i < myobjects.length; i++){
      myobjects[i].classList.add("hideme");
    }
  }
}

function showcatchup(){showhidescopestats(document, 'catchup');}
function showfree(){showhidescopestats(document, 'free');}
function showstats(){showhidescopestats(document, 'stats');}
function showslotlessons(){showhidescopestats(document, 'slotlessons');}

// This function allows us to limit the scope to a single slot.
// pass in the dom_id for the slot.
function scoped_showhidestats(scope){
  showhidescopestats(scope, 'catchup');
  showhidescopestats(scope, 'free');
  showhidescopestats(scope, 'stats');
  showhidescopestats(scope, 'slotlessons');
}

function showhidescopestats(scope, type){
  var myobjects = scope.getElementsByClassName(type);
  if (document.getElementById('hide' + type).checked){
    for(var i = 0; i < myobjects.length; i++){
      myobjects[i].classList.remove("hideme");
    }
  }else{
    for(i = 0; i < myobjects.length; i++){
      myobjects[i].classList.add("hideme");
    }
  }
}

/*
function showcatchup(){showhidestats('catchup');}
function showfree(){showhidestats('free');}
function showstats(){showhidestats('stats');}
function showslotlessons(){showhidestats('slotlessons');}
*/
/*
function showhidestats(type){
  var myobjects = document.getElementsByClassName(type);
  if (document.getElementById('hide' + type).checked){
    for(var i = 0; i < myobjects.length; i++){
      myobjects[i].classList.remove("hideme");
    }
  }else{
    for(i = 0; i < myobjects.length; i++){
      myobjects[i].classList.add("hideme");
    }
  }
}
*/
// Common functions called from both scheduling and stats.

// initialisation that is common to both.
function menu_common() {
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
}

// menu functions
function setscmi(elementId, scmi){
  if(document.getElementById(elementId)){
    if(scmi){
      document.getElementById(elementId).classList.remove('hideme');
    }else{
      document.getElementById(elementId).classList.add('hideme');
    }
  }
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


//On windows screen resize, hides the menu - start selection again 
function resizeListener() {
  window.onresize = function(e) {
    toggleMenuOff();
    toggleTMenuOff();

  };
}


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

function objectidToObjecttype(myobjectid){
  // first check if this object is from the 'allocate' div in the students
  // area of the catchup allocations screen.
  var parseAllocate = myobjectid.match(/^allocate_/);
  if(myobjectid.match(/^allocate_/)){
    return 'lesson';
  }
  var parseId = myobjectid.match(/(\w)\d+$/ );
  switch(parseId[1]) {
    case 's':
      return 'student';
    case 't':
      return 'tutor';
    case 'n':
      return 'lesson';
    case 'l':
      return 'slot';
    default:
      return '';
  }
}

// returns context of 'index' or 'lesson'
function objectidToContext(myobjectid){
  if(myobjectid.match(/^allocate_/)){
    return 'index';
  }
  var parseId = myobjectid.match(/^[st]\d+$/);
  if(parseId) {
    return 'index';
  }else{
    return 'lesson';
  }
}

// determine if a user has dropped/copied/moved into the same parent.
// Need for persons (tutors or students) and lessons.
function isParentSame(checkdomchange){
  // only relevant to move and copy.
  if( checkdomchange['action'] == 'move' || checkdomchange['action'] == 'copy'    ) {
    if( checkdomchange['object_type'] == 'lesson') { //copy & move must be either a lesson
      var parseToParent     = checkdomchange['to'].match(/^(\w+\d+)[nl]/);          // slot is parent   
      var parseObjectParent = checkdomchange['object_id'].match(/^(\w+\d+)[nl]/);   // slot is parent   
    }else{                         // or tutor / student.
      if(checkdomchange['object_id'].match(/^[st]\d+$/)){  // index area is parent of object   
        return false;
      }
      parseToParent     = checkdomchange['to'].match(/^(\w+\d+n\d+)/);         // lesson is parent
      parseObjectParent = checkdomchange['object_id'].match(/^(\w+\d+n\d+)/);  // lesson is parent   
    }
    if( parseToParent[1]  ==  parseObjectParent[1]){  // have same parents
      return true;                                         // do nothing
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





//$(document).ready(ready);
$(document).on('turbolinks:load', ready);
