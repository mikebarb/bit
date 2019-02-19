#class Student < ActiveRecord::Base
class Student < ApplicationRecord    # required migrating to rails 5.0
  has_many :roles
  has_many :lessons, through: :roles
  accepts_nested_attributes_for :lessons

  validates :pname, presence:true, uniqueness:true
  validates :sex, allow_blank: false, format: {
    with: %r{\A(male|female|unknown)\z},
    message: 'must be male, female or unknown.'
  }
  # additional validations as of 8/2/19
  validates :comment, presence:true, format: {
    with: %r{\w+},
    message: "You must at least have the free lesson details"
  }
  validates :status, presence:true, allow_blank: false, format: {
    with: %r{\A(inactive|new|standard|fortnightly|onetoone)\z},
    message: 'must be male, female or unknown.'
  }
  validates :year, presence:true, allow_blank: false
  validates :study, presence:true, allow_blank: false
  # end of additional validation 

  before_destroy :ensure_not_referenced_by_lessons
  after_save  :record_change_save
  after_destroy :record_change_destroy

  def displayname
    "#{gname} #{sname}"
  end
  
  private

  def record_change_save
    if self.changed_attributes.count > 0
      @mychange = Change.new
      @mychange.user = Thread.current[:current_user_id]
      @mychange.rid = self.id
      @mychange.table = self.class.to_s
      my_changed_attributes = self.changed_attributes.dup
      if my_changed_attributes['updated_at'] != nil
        @mychange.modified = my_changed_attributes.delete('updated_at')
      elsif my_changed_attributes['created_at'] != nil
        @mychange.modified = my_changed_attributes.delete('updated_at')
      else
        @mychange.modified = self['created_at']
      end        
      my_changed_attributes.delete_if do |k, v|
        if ['status', 'comment', 'study'].include?(k)
          @mychange1 = @mychange.dup
          @mychange1.field = k
          @mychange1.value = self[k]
          @mychange1.save
          true
        else
          false
        end
      end
      if my_changed_attributes.count == 1
          @mychange.field = my_changed_attributes.keys.first
          @mychange.value = self[@mychange.field]
          @mychange.save
          my_changed_attributes.delete(@mychange.field)
      end
      if my_changed_attributes.count > 1
          # multiple fields to store: make field name "mulit" & store values as json.
          @mychange.field = 'multi'
          my_changed_attributes.each do |k, v|
            my_changed_attributes[k] = self[k]
          end
          @mychange.value = my_changed_attributes.to_json
          @mychange.save
      end
    end
  end

  def record_change_destroy
    @mychange = Change.new
    @mychange.modified = Time.now
    @mychange.user = Thread.current[:current_user_id]
    @mychange.rid = self.id
    @mychange.table = self.class.to_s
    @mychange.field = 'destroy'
    @mychange.value = ''
    #byebug
    @mychange.save
  end

  def ensure_not_referenced_by_lessons
    returnvalue = true
    unless lessons.empty?
      errors.add(:base, 'This student is in at least one lesson!')
      returnvalue = false
    end
    return returnvalue
  end


end
