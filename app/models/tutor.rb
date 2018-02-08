class Tutor < ActiveRecord::Base
  has_many :tutroles
  has_many :sessions, through: :tutroles
  accepts_nested_attributes_for :sessions

  validates :pname, presence:true, uniqueness:true
  validates :sex, allow_blank: true, format: {
    with: %r{\A(male|female)\z},
    message: 'must be male, female or blank.'
  }

  def displayname
    "#{gname} #{sname}"
  end


end
