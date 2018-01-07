class Tutrole < ActiveRecord::Base
  belongs_to :session
  belongs_to :tutor
  
  validates :session_id, uniqueness: {scope: :tutor_id}
end
