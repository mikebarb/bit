class Student < ActiveRecord::Base
  has_many :roles
  has_many :lessons, through: :roles
  accepts_nested_attributes_for :lessons

  validates :pname, presence:true, uniqueness:true
  validates :sex, allow_blank: true, format: {
    with: %r{\A(male|female)\z},
    message: 'must be male, female or blank.'
  }
  
  before_destroy :ensure_not_referenced_by_lessons


  def displayname
    "#{gname} #{sname}"
  end
  
  private
    def ensure_not_referenced_by_lessons
      returnvalue = true
      unless lessons.empty?
        errors.add(:base, 'This student is in at least one lesson!')
        returnvalue = false
      end
      return returnvalue
    end


end
