require 'abstract_db_create'
require 'db/mysql'

class MysqlDbCreateTest < Test::Unit::TestCase
  include AbstractDbCreate

  def db_config
    MYSQL_CONFIG
  end

  if find_executable?("mysql")
    def test_rake_db_create
      Rake::Task["db:create"].invoke
      output = nil
      IO.popen("mysql -u #{MYSQL_CONFIG[:username]} --password=#{MYSQL_CONFIG[:password]}", "r+") do |mysql|
        mysql << "show databases where `Database` = '#{@db_name}';"
        mysql.close_write
        assert mysql.read =~ /#{@db_name}/m
      end
    end
  else
    def test_skipped
    end
  end
end
