class Role < ActiveRecord::Base
  belongs_to :session
  belongs_to :student
  
  validates :session_id, uniqueness: {scope: :student_id}
end
