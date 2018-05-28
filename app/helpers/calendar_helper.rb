module CalendarHelper
  def set_class_status(person, entry)
    if person.class == Tutor
      status = person.tutroles.where(lesson_id: entry.id).first.status
      if status != nil && status != ''
        result = 't-status-' + status
      else
        result = 't-status-standard'  
      end
    elsif person.class == Student
      status = person.roles.where(lesson_id: entry.id).first.status
      if status != nil && status != ''
        result = 't-status-' + status
      else
        result = 't-status-standard'  
      end
    elsif person.class == Lesson
      status = entry.status
      if status != nil && status != ''
        result = 'n-status-' + status
      else
        result = 'n-status-standard'  
      end
    end
    result
  end

# for fast version of display
  def set_class_status_f(personRole)
    status = personRole.status
    if status != nil && status != ''
      result = status
    else
      result = 'standard'  
    end
    result
  end
  
  def set_class_kind(person, entry)
    if person.class == Tutor
      kind = person.tutroles.where(lesson_id: entry.id).first.kind
      if kind != nil && kind != ''
        result = 't-kind-' + kind
      else
        result = 't-kind-standard'  
      end
    elsif person.class == Student
      kind = person.roles.where(lesson_id: entry.id).first.kind
      if kind != nil && kind != ''
        result = 's-kind-' + kind
      else
        result = 's-kind-standard'  
      end
    end
    result
  end
  
  def set_class_kind_f(personRole)
    kind = personRole.kind
    if kind != nil && kind != ''
      result = kind
    else
      result = 'standard'  
    end
    result
  end
  

  # Sort the values in display2 (cell of lessons/sessions) by status and then by tutor name
  # as some lessons have no tutor, this returns the tutor name if available.
  # This can then be used as the second attribute in the sort.
  def valueOrder(obj)
    if obj.tutors.exists?
      obj.tutors.sort_by {|t| t.pname }.first.pname
    else
      "_"
    end
  end

  def valueOrderStatus(obj)
    if obj.status != nil
      obj.status
    else
      ""
    end
  end

end
