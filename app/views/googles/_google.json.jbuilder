json.extract! google, :id, :user, :client_id, :access_token, :refresh_token, :scope, :expiration_time_millis, :created_at, :updated_at
json.url google_url(google, format: :json)
