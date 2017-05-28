module SessionsHelper
  def setup_session(session)
    studentcount = 2 - session.roles.count
    logger.debug "setup_session1 - (studentcount) " + studentcount.to_s
    while studentcount > 0 do
      session.roles.build()
      logger.debug "setup_session2- loop " + session.roles.inspect
      studentcount -= 1
    end
    logger.debug "setup_session3- " + session.inspect
    logger.debug "setup_session4- " + session.roles.inspect
    session
  end
end
