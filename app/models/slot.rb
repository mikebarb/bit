class Slot < ActiveRecord::Base
  has_many :lessons

  validates :timeslot, :location, presence:true
  validates :timeslot, uniqueness: {scope: [:location]}
  #validates :location, uniqueness: {scope: [:timeslot]}

  before_destroy :ensure_not_referenced_by_lessons
  

  def timeslot_with_location
    "#{timeslot}: #{location}"
  end

  private
  
    def ensure_not_referenced_by_lessons
        returnvalue = true
        unless lessons.empty?
          errors.add(:base, 'Lessons in this slot!')
          returnvalue = false
        end
        return returnvalue
    end

end
