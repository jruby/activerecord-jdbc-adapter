require 'abstract_db_create'
require 'db/mssql'

class MysqlDbCreateTest < Test::Unit::TestCase
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
    select = "SELECT NAME FROM sys.sysdatabases"
    select = "SELECT name FROM master..sysdatabases ORDER BY name" if ActiveRecord::Base.connection.sqlserver_version == "2000"
    databases = ActiveRecord::Base.connection.select_rows(select).flatten
    assert databases.include?(@db_name)
  end
end
