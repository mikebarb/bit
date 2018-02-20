class Student < ActiveRecord::Base
  has_many :roles
  has_many :lessons, through: :roles
  accepts_nested_attributes_for :lessons

  validates :pname, presence:true, uniqueness:true
  validates :sex, allow_blank: true, format: {
    with: %r{\A(male|female)\z},
    message: 'must be male, female or blank.'
  }

  def displayname
    "#{gname} #{sname}"
  end


end
