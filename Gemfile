source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
#gem 'rails', '4.1.1'
#gem 'rails', '~> 4.2'
#gem 'rails', '~> 5.0.0', '>= 5.0.0.1'
# backlevel to this as a know working active cable connection.
# see https://github.com/rails/rails/issues/27421 
#gem 'rails', '5.0.0.1'
# ***** remove action-cable *******
#gem 'rails', '5.0.6'
gem "activerecord", '5.0.6'
gem "activemodel", '5.0.6'
gem "actionpack", '5.0.6'
gem "actionview", '5.0.6'
gem "actionmailer", '5.0.6'
gem "activejob", '5.0.6'
gem "activesupport", '5.0.6'
gem "railties", '5.0.6'
gem "sprockets-rails", '>=2.0.0'

# force active support version to make bundle updat work
# was not in here before rails 5.
#gem 'activesupport', '=5.1.1'

# Use sqlite3 as the database for Active Record
#gem 'sqlite3'
# Use postgres as the database for Active Record
#gem 'pg', '0.18'
gem 'pg', '~>0.18'
gem 'rails_12factor'
# Use Puma as the app server
gem 'puma', '~> 3.0'
# Use SCSS for stylesheets
#gem 'sass-rails', '~> 4.0.3'
gem 'sass-rails', '~> 5.0'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .js.coffee assets and views
#gem 'coffee-rails', '~> 4.0.0'
gem 'coffee-rails', '~> 4.2'
# See https://github.com/sstephenson/execjs#readme for more supported runtimes
# gem 'therubyracer',  platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'
# Use jquery-ui-rails
gem 'jquery-ui-rails'
# Use jQuery-contextMenu plug-in https://github.com/swisnl/jQuery-contextMenu
# ??????????????????????????
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
#gem 'turbolinks'
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
#gem 'jbuilder', '~> 2.0'
gem 'jbuilder', '~> 2.5'
#gem 'jbuilder'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0',          group: :doc

# Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
gem 'spring',        group: :development

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Use debugger
#gem 'debugger', group: [:development, :test]

# support google spreadsheets
gem 'googleauth', :require => ['googleauth/stores/file_token_store', 'googleauth']
gem 'google-api-client', '~> 0.19', require: 'google/apis/sheets_v4'

#gem 'google-api-client', '0.8.2', require: 'google/api_client'
#gem 'cloudprint'
#gem 'mime-types', '~> 3.0'

group :development, :test do
  # debugging gem
  gem 'byebug'
  ###gem "rspec-rails", "~> 2.14"
  gem "rspec-rails", "~> 3.7.0"
  #gem "factory_girl_rails"
  gem "factory_bot_rails"
  gem 'ffaker'

end

# Devise gems
#gem 'devise', '3.4.1'
gem 'devise', '~>4.4.3'

# mailgun support - used by devise in cloud9 as it block smtp
gem 'mailgun-ruby'
gem 'rest-client'

# to maintain certificates at current level
# then run the “certified-update” executable on the console and
# this command will make sure that all your certificates are up-to-date.
gem 'certified', '~> 1.0'

# Ruby version 
# This was 2.3.0p0 locally before moving to version 2.4.1 as per article 
#https://devcenter.heroku.com/articles/getting-started-with-rails5 
ruby "2.3.0"
#ruby "2.4.0p0"

# Managing secrets
gem 'figaro', '~> 1.0'

# A Scope & Engine based, clean, powerful, customizable and sophisticated
# paginator for modern web app frameworks and ORMs.
gem 'kaminari'

# ably gem for web-socket messaging
gem 'ably-rest', '~>1.0'

