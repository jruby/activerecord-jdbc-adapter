source "https://rubygems.org"

if version = ( ENV['AR_VERSION'] || ENV['RAILS'] )
  if version.eql?('false')
    # NO gem declaration (Rails test -> manipulating LOAD_PATH)
  elsif version.index('/') && ::File.exist?(version)
    if Dir.entries(version).include?('activerecord') # Rails directory
      gem 'activerecord', require: false, path: ::File.join(version, 'activerecord')
      gem 'activemodel', require: false, path: ::File.join(version, 'activemodel')
      gem 'activesupport', require: false, path: ::File.join(version, 'activesupport')
    else
      gem 'activerecord', path: version
    end
  elsif version =~ /^[0-9abcdef]+$/ || version.start_with?('v')
    git 'https://github.com/rails/rails.git', ref: version do
      gem 'activerecord', require: false
      gem 'activemodel', require: false
      gem 'activesupport', require: false
    end
  elsif version.index('.').nil?
    git 'https://github.com/rails/rails.git', branch: version do
      gem 'activerecord', require: false
      gem 'activemodel', require: false
      gem 'activesupport', require: false
    end
  else
    gem 'activerecord', version, require: nil
  end
else
  gemspec name: 'activerecord-jdbc-adapter' # gem 'activerecord' declared in .gemspec
end

gem 'rake', '>= 11.1', require: nil

group :test do
  gem 'test-unit', '~> 2.5.4', require: nil
  gem 'test-unit-context', '>= 0.4.0', require: nil
  gem 'mocha', '~> 1.2', require: false # Rails has '~> 0.14'

  gem 'bcrypt', '~> 3.1.11', require: false
end

group :rails do
  group :test do
    # FIX: Our test suite isn't ready to run in random order yet.
    gem 'minitest', '< 5.3.4', require: nil
    # FIX: Update to 2.0.1 or higher once this gem is released
    gem 'minitest-rg', require: nil

    gem 'benchmark-ips', require: nil
  end

  # AR expects this for testing xml in postgres (maybe others?)
  gem 'builder', require: nil

  gem 'erubis', require: nil # "~> 2.7.0"
  # NOTE: due rails/activerecord/test/cases/connection_management_test.rb
  gem 'rack', require: nil
end

group :development do
  gem 'ruby-debug', require: nil # if ENV['DEBUG']
  group :doc do
    gem 'yard', require: nil
    gem 'kramdown', require: nil
  end
end

group :test do
  # for testing against different version(s)
  if sqlite_version = ENV['JDBC_SQLITE_VERSION'] 
    gem 'jdbc-sqlite3', sqlite_version, require: nil, platform: :jruby
  end

  gem 'mysql2', '>= 0.4.4', require: nil, platform: :mri
  gem 'pg', '>= 0.18.0', require: nil, platform: :mri
  gem 'sqlite3', '~> 1.3.6', require: nil, platform: :mri

  # group :mssql do
  #   gem 'tiny_tds', require: nil, platform: :mri
  #   gem 'activerecord-sqlserver-adapter', require: nil, platform: :mri
  # end
end
