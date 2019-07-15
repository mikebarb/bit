/*
Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
*/
/* global $ */

var myhost = window.location.protocol + '//' + window.location.hostname;   // base url for ajax


//$(document).ready(function() {
function ready_page_addslotedit(){
  if(document.getElementById('page_name')){
    var page_name = document.getElementById('page_name').innerHTML;
    //console.log("page name: " + page_name);
    if(page_name == 'addslotedit'){
      ready_addslotedit();
    }else if (page_name == 'removeslot'){
      ready_removeslot();
    }
  }else{
    return;
  }
 }
 
function ready_addslotedit() {
  showhideotherlocation(document.getElementById('location'));
  $('#location').change(function(e){
    showhideotherlocation(e.target);
  });
}

function showhideotherlocation(obj){
  var selectedValue = obj.value;
  selectedValue == "OTHER" ? $("#otherlocation").show() : $("#otherlocation").hide();
}

//------------- 'ready_catchups' function --------------------------------
function ready_removeslot(){

  init_removeslot();

  // Initialise our application's code for catchups.
  // Made modular so that you have more control over initialising them. 
  function init_removeslot() {


    //***********************************************************************
    // Perform the actions invoked when clicking expire (or revert) button.                *
    //***********************************************************************
    // action is the element clicked on in the menu.
    // The menu element clicked on has an attribute "data-action" that 
    // describes the required action.
  
    // currentActivity['action'] = thisAction;             //**update**
    // currentActivity['object_id'] = thisEleId;           //**update**
    // currentActivity['object_type'] = thisEleId -> type; //**update**
    // currentActivity['to'] = thisEleId;                  //**update**
    //$(".action").on('click', function() {
    $("#removeslottable").on('click', ".action", function(e) {
      e.preventDefault();
      console.log("action clicked for removing a slot");
      var domchange = {}; 
      domchange['action'] = $(this).attr('data-action');
      domchange['object_id'] = $(this)[0].id;
      remove_slot(domchange);
      //will need to call the expire action - ajax call.
    });

  //----------------------------------------------------------------
  // This will set up the ajax action to
  // a) remove this slot
  //----------------------------------------------------------------
  
  function remove_slot(domchange){
    // this function simply calls the controller
    // controller returns a list of students from the global lesson
    var myurl = myhost + '/admins/removeslot'; 
    var mydata = {'domchange' : domchange};
    //alert("about to remove slot: ");
    $.ajax({
        type: "POST",
        url: myurl,
        dataType: "json",
        data: mydata,
        //context: domchange,
        success: function(result1, result2, result3){
            console.log("removeslot Ajax response OK");
            removeslot_domdelete(result1);
        },
        error: function(xhr){
            var errors = $.parseJSON(xhr.responseText);
            var error_message = "";
            for (var error in (errors['lesson_id'])){
              error_message += " : " + errors['lesson_id'][error];
            }
            alert("error removing slot: " + error_message);
        }
     });
  }
  
  //----------------- removeslot_domdelete ----------------------
  // this function updates the catchup details:
  // This is called from the ajax response NOT a Web Socket propagation.
  function removeslot_domdelete(domchange){
    console.log('entered removeslot_domdelete');
    var object_domid = domchange['object_id'];
    var button_ele = document.getElementById(object_domid);
    var row_ele = button_ele.parentElement;
    //alert("about to delete dom object");
    //row_ele.parentNode.replaceChild(eletoplace[0], row_ele);
    row_ele.remove();
  }

}
//------------- End of 'remove_slot' function --------------------------------
}

//$(document).ready(ready);
//$(document).on('turbolinks:load', ready);
$(document).on('turbolinks:load', ready_page_addslotedit);  
