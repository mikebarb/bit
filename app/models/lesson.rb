class Lesson < ActiveRecord::Base
  belongs_to :slot
  has_many :roles
  has_many :students, through: :roles
  accepts_nested_attributes_for :roles,
    :allow_destroy => true,
    :reject_if     => :all_blank
  has_many :tutroles
  has_many :tutors, through: :tutroles
  accepts_nested_attributes_for :tutroles,
    :allow_destroy => true,
    :reject_if     => :all_blank
  #attr_accessible :slot_id, :student_id, :tutor_id
  before_destroy :ensure_not_referenced_by_tutors_or_students
  
  private
    def ensure_not_referenced_by_tutors_or_students
      returnvalue = true
      unless tutors.empty?
        errors.add(:base, 'Tutors in this lesson!')
        returnvalue = false
      end
      unless students.empty?
        errors.add(:base, 'Students in this lesson!')
        returnvalue = false
      end
      return returnvalue
    end
    
end
