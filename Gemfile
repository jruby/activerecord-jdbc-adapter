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
  gem 'activerecord', '~> 5.0.6', :require => false
end

gem 'thread_safe', :require => nil # "optional" - we can roll without it
gem 'rake', :require => nil

group :test do
  gem 'minitest', '< 5.3.4'
  gem 'test-unit', '~> 2.5.4'
  gem 'test-unit-context', '>= 0.4.0'
  gem 'mocha', '~> 1.2', :require => nil

  gem 'simplecov', :require => nil
  gem 'bcrypt-ruby', '~> 3.0.0', :require => nil
  #gem 'trinidad_dbpool', :require => nil
end

group :development do
  gem 'ruby-debug', :require => nil # if ENV['DEBUG']
  group :doc do
    gem 'yard', :require => nil
    gem 'yard-method-overrides', :git => 'https://github.com/kares/yard-method-overrides.git', :require => nil
    gem 'kramdown', :require => nil
  end
end

group :rails do
  gem 'erubis', :require => nil
  # NOTE: due rails/activerecord/test/cases/connection_management_test.rb (AR 5.0)
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
