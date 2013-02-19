require 'abstract_db_create'
require 'db/mssql'

class MSSQLDbCreateTest < Test::Unit::TestCase
  include AbstractDbCreate

  def db_config
    MSSQL_CONFIG
  end
  
  def test_rake_db_create
    begin
      Rake::Task["db:create"].invoke
    rescue => e
      if e.message =~ /CREATE DATABASE permission denied/
        puts "\nwarning: db:create test skipped; add 'dbcreator' role to user '#{db_config[:username]}' to run"
        return
      end
    end
    ActiveRecord::Base.establish_connection(db_config.merge(:database => "master"))
    if ActiveRecord::Base.connection.send(:sqlserver_2000?)
      select = "SELECT name FROM master..sysdatabases ORDER BY name"
    else
      select = "SELECT name FROM sys.sysdatabases"
    end
    databases = ActiveRecord::Base.connection.select_rows(select).flatten
    assert databases.include?(@db_name)
  end
end
