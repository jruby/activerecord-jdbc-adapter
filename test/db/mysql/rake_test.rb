require 'rake_test_support'
require 'db/mysql'

class MySQLRakeTest < Test::Unit::TestCase
  include RakeTestSupport

  def db_config
    MYSQL_CONFIG
  end

  def do_teardown
    drop_rake_test_database(:silence)
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
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      connection.create_table('users') { |t| t.string :name }
    end
    
    Rake::Task["db:test:purge"].invoke

    ActiveRecord::Base.establish_connection db_config.merge :database => db_name
    assert_false ActiveRecord::Base.connection.table_exists?('users')
    ActiveRecord::Base.connection.disconnect!
  end

  test 'rake db:structure:dump' do
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      create_schema_migrations_table(connection)
      connection.create_table('users') { |t| t.string :name; t.timestamps }
    end
    
    structure_sql = File.join('db', structure_sql_filename)
    begin
      Dir.mkdir 'db' # db/structure.sql
      Rake::Task["db:structure:dump"].invoke
      
      assert File.exists?(structure_sql)
      assert_match /CREATE TABLE `users`/, File.read(structure_sql)
    ensure
      File.delete(structure_sql) if File.exists?(structure_sql)
      Dir.rmdir 'db'
    end
  end
  
  setup { rm_r 'db' if File.exist?('db') }
  
  test 'rake db:charset' do
    create_rake_test_database
    expect_rake_output 'utf8'
    Rake::Task["db:charset"].invoke
  end

  test 'rake db:collation' do
    create_rake_test_database
    expect_rake_output /utf8_.*?_ci/
    Rake::Task["db:collation"].invoke
  end
  
  private
  
  def with_mysql(args = nil)
    exec = "mysql -u #{db_config[:username]} --password=#{db_config[:password]} #{args}"
    IO.popen(exec, "r+") { |mysql| yield(mysql) }
  end
  
end