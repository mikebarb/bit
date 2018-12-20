#class Role < ActiveRecord::Base
class Role < ApplicationRecord    # required migrating to rails 5.0
  belongs_to :lesson
  belongs_to :student
  #belongs_to :student_small, -> {select(:id, :pname, :sex, :comment, :status, :year, :study)}, 
  #                              class_name: 'Student'
  
  validates :lesson_id, uniqueness: {scope: :student_id}

  after_save  :record_change_save
  after_destroy :record_change_destroy

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
        if ['status', 'kind', 'comment'].include?(k)
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
    @mychange.save
  end

end
