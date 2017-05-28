class Role < ActiveRecord::Base
  belongs_to :session
  belongs_to :student
end
