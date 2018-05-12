#app/controllers/concerns/historyutilities.rb
module Historyutilities
  extend ActiveSupport::Concern

  # Note:
  #      includes -> minimum number of db queries
  #      joins    -> lazy loads the db query

  # Obtain the history for a single tutor
  # @tutorhistory holds everything required in the view
  def tutor_history(tutor_id)
    # put everything in a hash for use in the view.
    @tutorhistory = Hash.new
    # keep the tutor details
    @tutorhistory["tutor"] = Tutor.find(tutor_id)
    # control how much history to provide
    startdate = Date.today - (Integer(current_user.history_back) rescue 100)
    enddate = Date.today + (Integer(current_user.history_forward) rescue 7)
    @tutorhistory["startdate"] = startdate
    @tutorhistory["enddate"]   = enddate
    # get all lessons this tutor is in - all history
    # link to lessons for this tutor through the tutroles
    tutrole_objs = Tutrole.where (["tutor_id = ?", tutor_id])
    # get all the lessons found through tutroles 
    lesson_ids = tutrole_objs.map { |obj| obj.lesson_id }.uniq
    lesson_objs = Lesson.includes(:slot, :students, :tutors)
                        .where( id: lesson_ids, slots: { timeslot: startdate..enddate})
                        .order('slots.timeslot')
    @tutorhistory["lessons"] = lesson_objs.map { |obj| [
                                            obj.id,
                                            obj.status,
                                            obj.slot.timeslot,
                                            obj.slot.location,
                                            obj.tutors.map {|t| t.pname },
                                            obj.students.map{|s| s.pname },
                                            obj.tutroles.where(tutor_id: tutor_id).first.status == nil ?
                                              "" : obj.tutroles.where(tutor_id: tutor_id).first.status
                                            ] }
    @tutorhistory
  end
  
  # Obtain the history for a single student
  # @studenthistory holds everything required in the view
  def student_history(student_id)
    # put everything in a hash for use in the view.
    @studenthistory = Hash.new
    # keep the student details
    @studenthistory["student"] = Student.find(student_id)
    # control how much history to provide
    startdate = Date.today - (Integer(current_user.history_back) rescue 100)
    enddate = Date.today + (Integer(current_user.history_forward) rescue 7)
    @studenthistory["startdate"] = startdate
    @studenthistory["enddate"]   = enddate
    # get all lessons this student is in - all history
    # link to lessons for this student through the roles
    role_objs = Role.where (["student_id = ?", student_id])
    # get all the lessons found through tutroles 
    lesson_ids = role_objs.map { |obj| obj.lesson_id }.uniq
    lesson_objs = Lesson.includes(:slot, :students, :tutors)
                        .where( id: lesson_ids, slots: { timeslot: startdate..enddate})
                        .order('slots.timeslot')
    @studenthistory["lessons"] = lesson_objs.map { |obj| [
                                            obj.id,
                                            obj.status,
                                            obj.slot.timeslot,
                                            obj.slot.location,
                                            obj.tutors.map {|t| t.pname },
                                            obj.students.map{|s| s.pname },
                                            obj.roles.where(student_id: student_id).first.status == nil ?
                                              "" : obj.roles.where(student_id: student_id).first.status
                                            ] }
    @studenthistory
  end
  
end