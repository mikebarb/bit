class Lesson < ActiveRecord::Base
  belongs_to :slot
  has_many :roles
  has_many :students, through: :roles
  accepts_nested_attributes_for :roles,
    :allow_destroy => true,
    :reject_if     => :all_blank
  has_many :tutroles
  has_many :tutors, through: :tutroles
  accepts_nested_attributes_for :tutroles,
    :allow_destroy => true,
    :reject_if     => :all_blank
  #attr_accessible :slot_id, :student_id, :tutor_id
  before_destroy :ensure_not_referenced_by_tutors_or_students
  after_save  :record_change_save
  after_destroy :record_change_destroy
  
  private

  def record_change_save
    if self.changed_attributes.count > 0
      @mychange = Change.new
      @mychange.user = Thread.current[:current_user_id]
      @mychange.rid = self.id
      @mychange.table = self.class.to_s
      #byebug
      my_changed_attributes = self.changed_attributes.dup
      if my_changed_attributes['updated_at'] != nil
        @mychange.modified = my_changed_attributes.delete('updated_at')
      elsif my_changed_attributes['created_at'] != nil
        @mychange.modified = my_changed_attributes.delete('updated_at')
      else
        @mychange.modified = self['created_at']
      end        
      my_changed_attributes.delete_if do |k, v|
        if ['status', 'comments'].include?(k)
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




    def ensure_not_referenced_by_tutors_or_students
      returnvalue = true
      unless tutors.empty?
        errors.add(:base, 'Tutors in this lesson!')
        returnvalue = false
      end
      unless students.empty?
        errors.add(:base, 'Students in this lesson!')
        returnvalue = false
      end
      return returnvalue
    end
    
end
