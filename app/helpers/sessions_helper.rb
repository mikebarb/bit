module SessionsHelper
  def setup_session(session)
    studentcount = 2 - session.roles.count
    logger.debug "setup_session1s - (studentcount) " + studentcount.to_s
    while studentcount > 0 do
      session.roles.build()
      logger.debug "setup_session2s- loop " + session.roles.inspect
      studentcount -= 1
    end
    logger.debug "setup_session3s- " + session.inspect
    logger.debug "setup_session4s- " + session.roles.inspect

    tutorcount = 1 - session.tutroles.count
    logger.debug "setup_session1t - (tutorcount) " + tutorcount.to_s
    while tutorcount > 0 do
      session.tutroles.build()
      logger.debug "setup_session2t- loop " + session.tutroles.inspect
      tutorcount -= 1
    end
    logger.debug "setup_session3t- " + session.inspect
    logger.debug "setup_session4t- " + session.tutroles.inspect

    session
  end
end
