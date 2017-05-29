/* Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
*/

/* global $ */

$(document).ready(function() {
  //console.log("documentready");  

  // this will put obvious border on mouse entering selectable items
  $('.session').mouseenter(function(){
     $(this).css('border','3px solid black')
  });
  $('.session').mouseleave(function(){
    $(this).css('border','0px solid grey')
  });
  $('.student').mouseenter(function(){
     $(this).css('border','3px solid blue')
  });
  $('.student').mouseleave(function(){
    $(this).css('border','0px solid grey')
  });

  // single click will display the comment.
  $('.session').mousedown(function(){
    $('.positionable').html("session: " + this.id)
    $(this).css('border','0px solid grey')
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

  /* Testing stuff. 
  $( function() {
    $( ".draggable" ).draggable();

    $( ".droppable" ).droppable({
      drop: function( event, ui ) {
        $( this )
          .addClass( "ui-state-highlight" )
          .find( "p" )
            .html( "Dropped!" );
      }
    });
  });
  */
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
        sessionupdateslot( this.id, ui.draggable.attr('id'), this, ui );    
        $( this )
          //.append(ui.draggable)
          .removeClass( "my-over" );
          //.addClass( "ui-state-highlight" );
      },
      over: function( event, ui ) {
        $( this )
          .addClass( "my-over" )
      },
      out: function( event, ui ) {
        $( this )
          .removeClass( "my-over" )
      }
    });
  });

  // for moving the students
  $( function() {
    $( ".student" ).draggable({
      revert: true,
      //comments display on click, remove when begin the drag
      start: function(event, ui) {
        $('#comments').css('visibility', 'hidden');  
      }
    });

    $( ".session" ).droppable({
      accept: ".student",
      drop: function( event, ui ) {
        studentupdatessession( this.id, ui.draggable.attr('id'), this, ui );   
        console.log ("dropping student");
        
        $( this )
          //.append(ui.draggable)
          .removeClass( "my-over" )
          .addClass( "ui-state-highlight" );
      },
      over: function( event, ui ) {
        $( this )
          .addClass( "my-over" )
      },
      out: function( event, ui ) {
        $( this )
          .removeClass( "my-over" )
      }
    });
  });

  function studentupdatessession( sessionid, studentid, mythis, ui ){
     console.log("calling studentupdatesession");
     var mydata = "{sessionid:" + sessionid + "}";
     //alert("called sessionupdateslot: slotid- " + slotid + " sessionid- " + sessionid + " mydata- " + mydata );
     alert("called studentupdatesession: studentid- " + studentid + " sessionid- to " + sessionid + " from " + ui.draggable.context.parentElement.id );
     mythis.dragged = ui.draggable;
  };


  function sessionupdateslot( slotid, sessionid, mythis, ui ){
     console.log("calling sessionupdateslot");
     var mydata = "{slotid:" + slotid + "}";
     //alert("called sessionupdateslot: slotid- " + slotid + " sessionid- " + sessionid + " mydata- " + mydata );
     alert("called sessionupdateslot: sessionid- " + sessionid + " slotid- to " + slotid + " from " + ui.draggable.context.parentElement.id );
     mythis.dragged = ui.draggable;  
     $.ajax({
        type: "POST",
        url: "https://bit-micmac.c9users.io/sessions/" + sessionid,
        data: {session : {'slot_id' : slotid }},
        dataType: "json",
        context: mythis,

        success: function(){
            console.log("done - dragged session " + this.dragged.attr('id') + " to slot " + this.id + " from " + this.dragged.context.parentElement.id );
            $(this).append(this.dragged);
            $(this).addClass( "processingsuccess" );
        },
        error: function(){
            $(this).addClass( "processingerror" );
            console.log("ajax error occured" );
        }
    });

  };

});

