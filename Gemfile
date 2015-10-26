source "https://rubygems.org"

if version = ENV['AR_VERSION']
  if version.index('/') && ::File.exist?(version)
    gem 'activerecord', :path => version
  elsif version =~ /^[0-9abcdef]+$/
    gem 'activerecord', :github => 'rails/rails', :ref => version
  elsif version.index('.').nil?
    gem 'activerecord', :github => 'rails/rails', :branch => version
  else
    gem 'activerecord', version, :require => nil
  end
else
  gem 'activerecord', :require => nil
end

gem 'thread_safe', :require => nil # "optional" - we can roll without it

if defined?(JRUBY_VERSION) && JRUBY_VERSION < '1.7.0'
gem 'jruby-openssl', :platform => :jruby
end

gem 'rake', '~> 10.4.2', :require => nil
gem 'appraisal', '~> 0.5.2', :require => nil

# appraisal ignores group block declarations :

gem 'test-unit', '~> 2.5.4', :group => :test
gem 'test-unit-context', '>= 0.4.0', :group => :test
gem 'mocha', '~> 0.13.1', :require => nil, :group => :test

gem 'simplecov', :require => nil, :group => :test
gem 'bcrypt-ruby', '~> 3.0.0', :require => nil, :group => :test
#gem 'trinidad_dbpool', :require => nil, :group => :test

group :development do
  gem 'ruby-debug', :require => nil # if ENV['DEBUG']
  group :doc do
    gem 'yard', :require => nil
    gem 'yard-method-overrides', :github => 'kares/yard-method-overrides', :require => nil
    gem 'kramdown', :require => nil
  end
end

group :rails do
  gem 'erubis', :require => nil
  # NOTE: due rails/activerecord/test/cases/session_store/session_test.rb
  gem 'actionpack', :require => nil
end

if sqlite_version = ENV['JDBC_SQLITE_VERSION'] # for testing against different version(s)
  gem 'jdbc-sqlite3', sqlite_version, :require => nil, :platform => :jruby, :group => :test
end

gem 'mysql2', '< 0.4', :require => nil, :platform => :mri, :group => :test
gem 'pg', :require => nil, :platform => :mri, :group => :test
gem 'sqlite3', :require => nil, :platform => :mri, :group => :test
group :mssql do
  gem 'tiny_tds', :require => nil, :platform => :mri, :group => :test
  gem 'activerecord-sqlserver-adapter', :require => nil, :platform => :mri, :group => :test
end
