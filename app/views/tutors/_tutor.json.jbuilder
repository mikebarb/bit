json.extract! tutor, :id, :gname, :sname, :pname, :initials, :sex, :comment, :created_at, :updated_at
json.url tutor_url(tutor, format: :json)