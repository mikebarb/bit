class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :lockable
         
  before_create :set_defaults
  
  private

    def set_defaults
      if self.email =~ /bigimprovementstutoring/i ||
         self.email =~ /mikebarb.net/i
        self.role = 'admin'
      elsif Tutor.find_by( email: self.email.downcase)
        self.role = 'tutor'
      elsif Student.find_by( email: self.email.downcase)
        self.role = 'student'
      end
    end

end
