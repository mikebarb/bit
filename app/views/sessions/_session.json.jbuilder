json.extract! session, :id, :slot_id, :comments, :created_at, :updated_at
json.url session_url(session, format: :json)
