require 'abstract_db_create'
require 'db/mysql'

class MysqlDbCreateTest < Test::Unit::TestCase
  include AbstractDbCreate

  def db_config
    MYSQL_CONFIG
  end

  def test_rake_db_create
    Rake::Task["db:create"].invoke
    if find_executable?("mysql")
      output = nil
      IO.popen("mysql -u #{MYSQL_CONFIG[:username]} --password=#{MYSQL_CONFIG[:password]}", "r+") do |mysql|
        mysql << "show databases where `Database` = '#{@db_name}';"
        mysql.close_write
        assert mysql.read =~ /#{@db_name}/m
      end
    end
  end

  def test_rake_db_test_purge
    Rake::Task["db:create"].invoke
    Rake::Task["db:test:purge"].invoke
  end
end
