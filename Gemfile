source "https://rubygems.org"

gem 'activerecord'
gem 'jruby-openssl', :platform => :jruby

group :development do
  gem 'ruby-debug', :require => nil
end

gem 'appraisal'
gem 'rake', :require => nil
# appraisal ignores group block declarations :
gem 'test-unit', '2.5.4', :group => :test
gem 'test-unit-context', :group => :test
gem 'mocha', '>= 0.13.0', :require => nil, :group => :test
gem 'simplecov', :require => nil, :group => :test
gem 'bcrypt-ruby', '~> 3.0.0', :require => nil, :group => :test

group :rails do
  gem 'erubis', :require => nil
  # NOTE: due rails/activerecord/test/cases/session_store/session_test.rb
  gem 'actionpack', :require => nil
end
