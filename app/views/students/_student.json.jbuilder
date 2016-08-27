json.extract! student, :id, :gname, :sname, :pname, :initials, :sex, :comment, :created_at, :updated_at
json.url student_url(student, format: :json)