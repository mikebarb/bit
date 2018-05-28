class Tutrole < ActiveRecord::Base
  belongs_to :lesson
  belongs_to :tutor
  
  before_save do 
    logger.debug "Tutrole - before_save called: " + self.inspect
  end
  
  after_save do 
    logger.debug "Tutrole - after_save called: " + self.inspect
  end

  validates :lesson_id, uniqueness: {scope: :tutor_id}
end
