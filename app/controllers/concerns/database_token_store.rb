#app/controllers/concerns/DatabaseTokenStore.rb
require 'googleauth/token_store'
module DatabaseTokenStore
  class DatabaseTokenStore < Google::Auth::TokenStore
    # database table: Tokenuser
    # fields:
    #   client_id               text
    #   token_json              text

    # id - a string
    def load(id)
      fail 'expected string parameter for id in Google::Auth::Stores - load' if id == nil
      tokenuser = Tokenuser.where(client_id: id).first
      if tokenuser
        tokenuser.token_json
      else
        nil
      end
    end

    # id - a string
    # token - a string which is actually json.        
    def store(id, token)
      fail 'expected string parameter for id in Google::Auth::Stores - load' if id == nil
      tokenuser = Tokenuser.where(client_id: id).first
      if tokenuser
        tokenuser.update(token_json: token)
      else
        tokenuser = Tokenuser.new(client_id: id,
                                  token_json: token)
        tokenuser.save
      end
      tokenuser.token_json
    end
    
    # id - a string
    def delete(id)
      fail 'expected string parameter for id in Google::Auth::Stores - load' if id == nil
      tokenuser = Tokenuser.where(client_id: id).first
      if tokenuser
        tokenuser.destroy
      end
    end
    
  end
end