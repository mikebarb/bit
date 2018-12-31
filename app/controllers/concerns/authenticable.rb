module Authenticable

  # Devise methods overwrites
  def current_user
    @current_user ||= User.find_by(auth_token: request.headers['Authorization'])
  end
  
  def authenticate_with_token!
    error_message = ""
    if current_user.present?
      if @current_user.auth_token == nil
        error_message = "Not authenticated"
        @current_user = nil
      end
    else
      error_message = "Not authenticated"
    end
    if error_message != ''
      logger.debug "failed current user is " + @current_user.inspect
      render json: { errors: "Not authenticated" },
                  status: :unauthorized
      return
    end
    logger.debug "current user is " + @current_user.inspect
  end  
  
  def user_signed_in?
    @current_user.present?
  end
end
