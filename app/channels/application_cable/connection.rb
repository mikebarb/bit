# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user
 
    def connect
      logger.debug " in ws connect"
      self.current_user = find_verified_user
      logger.debug "current_user: " + self.current_user.inspect 
    end
 
    private
      def find_verified_user
        #if verified_user = User.find_by(id: cookies.encrypted[:user_id])
        if verified_user = env['warden'].user
          verified_user
        else
          reject_unauthorized_connection
        end
      end
  end
end