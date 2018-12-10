Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send.
  #config.action_mailer.raise_delivery_errors = false

  # devise action mailer configuration 
  # - required to properly generate links inside the e-mail views
  config.action_mailer.default_url_options = { :host => ENV['DEFAULT_HOST'] }
  config.action_mailer.delivery_method = :mailgun
  config.action_mailer.perform_deliveries = true
  config.action_mailer.mailgun_settings = {
    :api_key              => ENV['MAILGUN_API_KEY'],
    :domain               => ENV['MAILGUN_DOMAIN']
  }

  # Disable Action View Logger in production for Ruby on Rails
  # see http://www.jakobbeyer.de/disable-action-view-logger-in-production-for-ruby-on-rails
  config.action_view.logger = nil

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
  
  #google api stuff - added by Mike
  #GOOGLE_API_USE_RAILS_LOGGER = true
  
  # action cable configuration - not sure where it should go!!!!!
  #config.action_cable.url = 'ws:bit3-micmac.c9users.io:3000/cable'
  
  # refer https://github.com/rails/rails/issues/31524 
  # **** remove-action-cable
  ###config.action_cable.allowed_request_origins = [/http:\/\/*/, /https:\/\/*/]
  
end
