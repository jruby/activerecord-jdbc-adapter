source "http://rubygems.org"

gem 'activerecord'
gem 'jruby-openssl', :platform => :jruby

group :development do
  gem 'ruby-debug', :require => nil
end

gem 'appraisal'
gem 'rake', :require => nil
# appraisal ignores group block declarations :
gem 'test-unit', :group => :test
gem 'mocha', :require => nil, :group => :test # '>= 0.13.0'