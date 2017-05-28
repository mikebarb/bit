class Session < ActiveRecord::Base
  belongs_to :slot
  belongs_to :tutor
  has_many :roles
  has_many :students, through: :roles
  accepts_nested_attributes_for :roles,
    :allow_destroy => true,
    :reject_if     => :all_blank
  #attr_accessible :slot_id, :student_id, :tutor_id
end
