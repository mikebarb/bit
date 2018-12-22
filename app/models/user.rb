#class User < ActiveRecord::Base
class User < ApplicationRecord    # required migrating to rails 5.0
  #validates :auth_token, uniqueness:true    # used in api
  # Include default devise modules. Others available are:
  # :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :lockable
         
  before_create :set_defaults, :generate_authentication_token!
  

  def generate_authentication_token!
    begin
      self.auth_token = Devise.friendly_token
    end while self.class.exists?(auth_token: auth_token)
  end

  private

    def set_defaults
      if self.email =~ /bigimprovementstutoring/i ||
         self.email =~ /mikebarb.net/i ||
         self.email =~ /lujic.dejan/i
        self.role = 'admin'
      elsif Tutor.find_by( email: self.email.downcase)
        self.role = 'tutor'
      elsif Student.find_by( email: self.email.downcase)
        self.role = 'student'
      end
    end


end
