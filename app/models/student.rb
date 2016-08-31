class Student < ActiveRecord::Base
  has_many :sessions, dependent: :destroy

  validates :gname, :sname, :initials, presence:true
  validates :initials, uniqueness:true
  validates :sex, allow_blank: true, format: {
    with: %r{\A(male|female)\z},
    message: 'must be male, female or blank.'
  }

  def displayname
    "#{gname} #{sname}"
  end


end
