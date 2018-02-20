class Tutrole < ActiveRecord::Base
  belongs_to :lesson
  belongs_to :tutor
  
  validates :lesson_id, uniqueness: {scope: :tutor_id}
end
