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
  config.action_mailer.default_url_options = { :host => 'https://bit3-micmac.c9users.io' }
  config.action_mailer.delivery_method = :mailgun
  config.action_mailer.perform_deliveries = true
  config.action_mailer.mailgun_settings = {
    :api_key              => 'key-fb63ea6ac6b4e662d8131f9e9becfcb3',
    :domain               => 'sandbox8e575a70bf914c059e4d49cb8e68bf20.mailgun.org'
}

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
end
