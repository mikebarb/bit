class Slot < ActiveRecord::Base
  has_many :lessons

  validates :timeslot, :location, presence:true
  validates :timeslot, uniqueness: {scope: [:location]}
  #validates :location, uniqueness: {scope: [:timeslot]}

  before_destroy :ensure_not_referenced_by_lessons
  after_save  :record_change_save
  after_destroy :record_change_destroy
  
  def timeslot_with_location
    "#{timeslot}: #{location}"
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
        if ['comment'].include?(k)
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
        errors.add(:base, 'Lessons in this slot!')
        returnvalue = false
      end
      return returnvalue
  end

end
