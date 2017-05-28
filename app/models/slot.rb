class Slot < ActiveRecord::Base
  has_many :sessions, dependent: :destroy

  validates :timeslot, :location, presence:true
  validates :timeslot, uniqueness: {scope: [:location]}
  #validates :location, uniqueness: {scope: [:timeslot]}

  def timeslot_with_location
    "#{timeslot}: #{location}"
  end

end
