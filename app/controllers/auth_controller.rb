class AuthController < ApplicationController
  def issue_token_request
    render json: ably_rest_subscribe.auth.create_token_request
  end
end