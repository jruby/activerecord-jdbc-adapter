source "https://rubygems.org"

if ENV['RAILS']  # Use local clone of Rails
  rails_dir = ENV['RAILS']    
  activerecord_dir = ::File.join(rails_dir, 'activerecord')
  
  if !::File.exist?(rails_dir) && !::File.exist?(activerecord_dir)
    raise "ENV['RAILS'] set but does not point at a valid rails clone"
  end

  activemodel_dir =  ::File.join(rails_dir, 'activemodel')
  activesupport_dir =  ::File.join(rails_dir, 'activesupport')
  
  gem 'activerecord', require: false, path: activerecord_dir
  gem 'activemodel', require: false, path: activemodel_dir
  gem 'activesupport', require: false, path: activesupport_dir
elsif ENV['AR_VERSION'] # Use specific version of AR and not .gemspec version
  version = ENV['AR_VERSION']
  
  if !version.eql?('false') # Don't bundle any versions of AR; use LOAD_PATH
    # Specified as raw number. Use normal gem require.
    if version =~ /^([0-9.])+(_)?(rc|RC|beta|BETA|PR|pre)*([0-9.])*$/
      gem 'activerecord', version, require: nil
    else # Asking for git clone specific version
      if version =~ /^[0-9abcdef]+$/ ||                                 # SHA
         version =~ /^v([0-9.])+(_)?(rc|RC|beta|BETA|PR|pre)*([0-9.])*$/# tag
        opts = {ref: version}
      else                                                              # branch
        opts = {branch: version}
      end
    
      git 'https://github.com/rails/rails.git', **opts do
        gem 'activerecord', require: false
        gem 'activemodel', require: false
        gem 'activesupport', require: false
      end
    end
  end
else
  gemspec name: 'activerecord-jdbc-adapter' # Use versiom from .gemspec
end

gem 'rake', '>= 11.1', require: nil

group :test do
  gem 'test-unit', '~> 2.5.4', require: nil
  gem 'test-unit-context', '>= 0.4.0', require: nil
  gem 'mocha', '~> 1.2', require: false # Rails has '~> 0.14'

  gem 'bcrypt', '~> 3.1.11', require: false
  gem 'builder', require: false
  gem 'jdbc-mssql', '~> 0.7.0', require: nil
end

group :rails do
  group :test do
    # FIX: Our test suite isn't ready to run in random order yet.
    gem 'minitest', '< 5.3.4', require: nil
    gem 'minitest-excludes', '~> 2.0.1', require: nil
    gem 'minitest-rg', require: nil

    gem 'benchmark-ips', require: nil
  end

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
