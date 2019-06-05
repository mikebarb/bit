# Load the Rails application.
require File.expand_path('../application', __FILE__)
# the following line added to match the bakery program.
#require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!

# The following logging is added according to 
# https://dzone.com/articles/rails-logger-and-rails-logging-best-practices
Rails.logger = Logger.new(STDOUT)
#Rails.logger = Logger.new("log/#{Rails.env}.log")
#config.logger = ActiveSupport::Logger.new("log/#{Rails.env}.log")
#Rails.logger.level=Logger::DEBUG
#Rails.logger.datetime_format = "%Y-%m-%d %H:%M:%S"

