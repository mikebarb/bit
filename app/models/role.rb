class Role < ActiveRecord::Base
  belongs_to :lesson
  belongs_to :student
  
  validates :lesson_id, uniqueness: {scope: :student_id}
end
