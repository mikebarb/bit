class Api::V1::UsersController < ApiController
  respond_to :json
  #skip_before_action :authenticate_user!
  # ensure authenticated before use
  ### skip_before_action :authenticate_with_token! # testing only
  
  # Curl command to test the show api
  # Note: you need to create the session first to get
  # the authorisation header value
  # curl -v -H 'Accept: application/vnd.bit3.v1', -H 'Content-Type: application/json', -H 'Authorization: cYyrPmi5N_5Q2uYK73vA' http://bit3-micmac.c9users.io/api/users

  # curl -v 
  # -H 'Accept: application/vnd.bit3.v1', 
  # -H 'Content-Type: application/json',
  # -H 'Authorization: 12bybwoBC2QnUur5sAHK'
  # http://bit3-micmac.c9users.io/api/users
  # to create the session (put in correct email & password), do:
  # curl -H 'Accept: application/vnd.bit3.v1' -d "session[email]=barb@mikebarb.net" -d "session[password]=password" http://bit3-micmac.c9users.io/api/sessions -v


  def show
    respond_with User
                 .select('id','email','daystart','daydur','history_back','history_forward')
                 .find(params[:id])
  end

  def index
    respond_with User
                 .select('id','email','daystart','daydur','history_back','history_forward')
                 .all
  end

end
