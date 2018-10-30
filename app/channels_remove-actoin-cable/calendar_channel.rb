# app/channels/calendar_channel.rb
# This channel broadcasts all the updates to the calendar
# so the browser is updated dynammically with moves, copies
# status changes etc.
class CalendarChannel < ApplicationCable::Channel
  # Called when the consumer has successfully
  # become a subscriber to this channel.
  def subscribed
    # stream_from "some_channel"
    logger.debug "CalendarChannel class - subscribed called"
    stream_from "calendar_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
  
end
