class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # ensure authenticated before use
  before_action :authenticate_user!
  
  # some variables need to be available accross all controllers
  # number of significant figures used in ids.
  def initialize
    @sf = 5
    super
  end

  def ably_rest
    @ably_rest ||= Ably::Rest.new(key: ENV['ABLY_API_KEY_PUBLISH'] )
  end

  def ably_rest_subscribe
    @ably_rest_subscribe ||= Ably::Rest.new(key: ENV['ABLY_API_KEY'] )
  end

end
