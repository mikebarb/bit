module LessonsHelper
  def setup_lesson(lesson)
    studentcount = 2 - lesson.roles.count
    logger.debug "setup_lesson1s - (studentcount) " + studentcount.to_s
    while studentcount > 0 do
      lesson.roles.build()
      logger.debug "setup_lesson2s- loop " + lesson.roles.inspect
      studentcount -= 1
    end
    logger.debug "setup_lesson3s- " + lesson.inspect
    logger.debug "setup_lesson4s- " + lesson.roles.inspect

    tutorcount = 1 - lesson.tutroles.count
    logger.debug "setup_lesson1t - (tutorcount) " + tutorcount.to_s
    while tutorcount > 0 do
      lesson.tutroles.build()
      logger.debug "setup_lesson2t- loop " + lesson.tutroles.inspect
      tutorcount -= 1
    end
    logger.debug "setup_lesson3t- " + lesson.inspect
    logger.debug "setup_lesson4t- " + lesson.tutroles.inspect

    lesson
  end
end
