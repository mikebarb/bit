# app/channels/stats_channel.rb
# This channel broadcasts all the updates to the stats page
# so the browser is updated dynammically following moves, copies
# status changes etc. including allocation of catchups.
class StatsChannel < ApplicationCable::Channel
  # Called when the consumer has successfully
  # become a subscriber to this channel.
  def subscribed
    # stream_from "some_channel"
    logger.debug "StatsChannel class - subscribed called"
    stream_from "stats_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
  
end
