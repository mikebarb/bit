module LessonsHelper
  def setup_lesson(lesson)
    studentcount = 2 - lesson.roles.count
    while studentcount > 0 do
      lesson.roles.build()
      studentcount -= 1
    end

    tutorcount = 1 - lesson.tutroles.count
    while tutorcount > 0 do
      lesson.tutroles.build()
      tutorcount -= 1
    end

    lesson
  end
end
