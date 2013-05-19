require 'rake_test_support'
require 'db/mysql'

class MySQLRakeDbCreateTest < Test::Unit::TestCase
  include RakeTestSupport

  def db_config
    MYSQL_CONFIG
  end

  test 'rake db:create (and db:drop)' do
    # omit_unless find_executable?("mysql")
    Rake::Task["db:create"].invoke
    with_mysql do |mysql|
      mysql << "show databases where `Database` = '#{db_name}';"
      mysql.close_write
      output = mysql.read
      assert output =~ /#{db_name}/m, "db name: #{db_name.inspect} not matched in:\n#{output}"
    end if find_executable?("mysql")
    
    Rake::Task["db:drop"].invoke
    with_mysql do |mysql|
      mysql << "show databases where `Database` = '#{db_name}';"
      mysql.close_write
      output = mysql.read
      assert_nil output =~ /#{db_name}/m, "db name: #{db_name.inspect} matched in:\n#{output}"
    end if find_executable?("mysql")
  end

  test 'rake db:test:purge' do
    Rake::Task["db:create"].invoke
    Rake::Task["db:test:purge"].invoke
  end
  
  private
  
  def with_mysql(args = nil)
    exec = "mysql -u #{db_config[:username]} --password=#{db_config[:password]} #{args}"
    IO.popen(exec, "r+") { |mysql| yield(mysql) }
  end
  
end