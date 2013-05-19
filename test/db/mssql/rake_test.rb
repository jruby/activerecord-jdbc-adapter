require 'rake_test_support'
require 'db/mssql'

class MSSQLRakeDbCreateTest < Test::Unit::TestCase
  include RakeTestSupport

  def db_config
    MSSQL_CONFIG
  end

  test 'rake db:create' do
    begin
      Rake::Task["db:create"].invoke
    rescue => e
      if e.message =~ /CREATE DATABASE permission denied/
        puts "\nwarning: db:create test skipped; add 'dbcreator' role to user '#{db_config[:username]}' to run"
        return
      end
    end

    begin
      ActiveRecord::Base.establish_connection(db_config.merge(:database => "master"))
      
      assert_include databases, db_name
    ensure
      Rake::Task["db:drop"].invoke rescue nil
    end
  end
  
  test 'rake db:drop' do
    begin
      Rake::Task["db:create"].invoke
    rescue => e
      if e.message =~ /CREATE DATABASE permission denied/
        puts "\nwarning: db:drop test skipped; add 'dbcreator' role to user '#{db_config[:username]}' to run"
        return
      end
    end
    
    # ActiveRecord::Base.connection.disconnect!
    
    Rake::Task["db:drop"].invoke
    
    ActiveRecord::Base.establish_connection(db_config.merge(:database => "master"))
      
    assert_not_include databases, db_name
  end
  
  test 'rake db:test:purge' do
    Rake::Task["db:create"].invoke
    # ActiveRecord::Base.connection.disconnect!
    Rake::Task["db:test:purge"].invoke
  end
  
  private
  
  def databases
    if ActiveRecord::Base.connection.send(:sqlserver_2000?)
      select = "SELECT name FROM master..sysdatabases ORDER BY name"
    else
      select = "SELECT name FROM sys.sysdatabases"
    end
    ActiveRecord::Base.connection.select_rows(select).flatten
  end
  
end