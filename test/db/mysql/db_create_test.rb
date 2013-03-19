require 'abstract_db_create'
require 'db/mysql'

class MysqlDbCreateTest < Test::Unit::TestCase
  include AbstractDbCreate

  def db_config
    MYSQL_CONFIG
  end

  def test_rake_db_create
    omit_unless find_executable?("mysql")
    Rake::Task["db:create"].invoke
    with_mysql do |mysql|
      mysql << "show databases where `Database` = '#{@db_name}';"
      mysql.close_write
      assert mysql.read =~ /#{@db_name}/m      
    end
  end

  def test_rake_db_test_purge
    Rake::Task["db:create"].invoke
    Rake::Task["db:test:purge"].invoke
  end
  
  private
  
  def with_mysql(args = nil)
    exec = "mysql -u #{db_config[:username]} --password=#{db_config[:password]} #{args}"
    IO.popen(exec, "r+") { |mysql| yield(mysql) }
  end
  
end
