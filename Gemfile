source "https://rubygems.org"

gem 'activerecord'
gem 'jruby-openssl', :platform => :jruby

group :development do
  gem 'ruby-debug', :require => nil # if ENV['DEBUG']
  group :doc do
    gem 'yard', :require => nil
    gem 'yard-method-overrides', :github => 'kares/yard-method-overrides', :require => nil
    gem 'kramdown', :require => nil
  end
end

gem 'rake', :require => nil
gem 'appraisal', :require => nil

# appraisal ignores group block declarations :

gem 'test-unit', '2.5.4', :group => :test
gem 'test-unit-context', '>= 0.3.0', :group => :test
gem 'mocha', '~> 0.14.0', :require => nil, :group => :test

gem 'simplecov', :require => nil, :group => :test
gem 'bcrypt-ruby', '~> 3.0.0', :require => nil, :group => :test

group :rails do
  gem 'erubis', :require => nil
  # NOTE: due rails/activerecord/test/cases/session_store/session_test.rb
  gem 'actionpack', :require => nil
end
