class Student < ActiveRecord::Base
validates :gname, :sname, :initial, presence:true
end
