source "http://rubygems.org"

# This may wreak havoc on the lockfile, but we need a way to test
# different AR versions
gem 'activerecord', ENV['AR_VERSION']
gem 'rails', ENV['AR_VERSION']

gem 'rake'

gem 'jruby-openssl', :group => :development

group :test do
  gem 'ruby-debug'
  gem 'mocha'
end
