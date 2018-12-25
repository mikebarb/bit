class Api::V1::SessionsController < ApiController
  # all except create requires authentication
  #skip_before_action :authenticate_user!
  skip_before_action :authenticate_with_token!, only: [:create]

  def create
    # to test using curl use:
    # micmac:~/workspace (api) $ curl -v 
    # -H 'Accept: application/vnd.bit3.v1, 
    # Content-Type: application/json' -X POST 
    # -d "session[email]=barb@mikebarb.net" 
    # -d "session[password]=password" 
    # http://bit3-micmac.c9users.io/api/sessions

    user_password = params[:session][:password]
    user_email = params[:session][:email]
    #user_password = session_params[:password]
    #user_email = session_params[:email]
    user = user_email.present? && User.find_by(email: user_email)

    if user.valid_password? user_password
      sign_in user, store: false
      user.generate_authentication_token!
      user.save
      logger.debug "session create after save - user is " + user.inspect
      #byebug
      response.headers['Authorization'] =  user.auth_token
      ### The following two lines would place the token in the body
      ### of the response.
      ### user = User.select(:id, :auth_token).find(user.id)
      ### render json: user, status: 200, location: [:api, user]
      head 200
      # Vny5N46sZ22gsXNVY59e
    else
      render json: { errors: "Invalid email or password" }, status: 422
    end
  end
  
  # this will log the api user out of the session.
  def destroy
    #+#my_authenticate_token = request.headers['Authorization']
    #user = User.find_by(auth_token: params[:id])
    #+#user = User.find_by(auth_token: my_authenticate_token)
    ###user.generate_authentication_token!
    ###user.save
    logger.debug "session destroy before generate - current user is " + @current_user.inspect
    @current_user.generate_authentication_token!
    @current_user.save
    logger.debug "session destroy after save - current user is " + @current_user.inspect
    head 204
  end

end
