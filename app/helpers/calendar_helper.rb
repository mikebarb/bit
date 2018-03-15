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

  # Sort the values in display2 (cell of lessons/sessions) by status and then by tutor name
  # as some lessons have no tutor, this returns the tutor name if available.
  # This can then be used as the second attribute in the sort.
  def valueOrder(obj)
    if obj.tutors.exists?
      obj.tutors.first.pname
    else
      "_"
    end
  end

end
