module Authenticable

  # Devise methods overwrites
  def current_user
    @current_user ||= User.find_by(auth_token: request.headers['Authorization'])
  end
  
  def authenticate_with_token!
    #byebug
    unless current_user.present?
      logger.debug "failed current user is " + @current_user.inspect
      render json: { errors: "Not authenticated" },
                  status: :unauthorized
    end
    logger.debug "current user is " + @current_user.inspect
  end  
  
end
