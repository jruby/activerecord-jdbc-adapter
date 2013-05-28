require 'rake_test_support'
require 'db/oracle'

class OracleRakeDbCreateTest < Test::Unit::TestCase
  include RakeTestSupport
  
  def db_name; nil; end # using same Oracle DB
  
  test 'rake db:drop' do
    create_rake_test_database do |connection|
      connection.create_table('oraclers_test') { |t| t.string :name }
    end
    
    Rake::Task["db:drop"].invoke

    establish_test_connection
    assert_false ActiveRecord::Base.connection.table_exists?('oraclers_test')
    ActiveRecord::Base.connection.disconnect!
  end
  
  test 'rake db:test:purge' do
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      create_schema_migrations_table(connection)
      connection.create_table('oraclers_test') { |t| t.string :name }
    end
    
    Rake::Task["db:test:purge"].invoke

    establish_test_connection
    assert_false ActiveRecord::Base.connection.table_exists?('oraclers_test')
    ActiveRecord::Base.connection.disconnect!
  end

  test 'rake db:structure:dump (and db:structure:load)' do
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      drop_all_database_tables(connection)
      create_schema_migrations_table(connection)
      connection.create_table('oraclers') { |t| t.string :name; t.timestamps }
    end
    
    structure_sql = File.join('db', structure_sql_filename)
    begin
      Dir.mkdir 'db' # db/structure.sql
      Rake::Task["db:structure:dump"].invoke
      
      assert File.exists?(structure_sql)
      assert_match /CREATE TABLE \"?ORACLERS\"?/i, File.read(structure_sql)
      
      # db:structure:load
      drop_all_database_tables
      create_rake_test_database
      Rake::Task["db:structure:load"].invoke
      
      establish_test_connection
      assert ActiveRecord::Base.connection.table_exists?('oraclers')
      ActiveRecord::Base.connection.disconnect!
    ensure
      File.delete(structure_sql) if File.exists?(structure_sql)
      Dir.rmdir 'db'
    end
  end
  
  setup { rm_r 'db' if File.exist?('db') }

  test 'rake db:charset' do
    create_rake_test_database
    expect_rake_output 'AL32UTF8'
    Rake::Task["db:charset"].invoke
  end

  test 'rake db:collation' do
    create_rake_test_database
    expect_rake_output /BINARY/
    Rake::Task["db:collation"].invoke
  end
  
  private
  
  def establish_test_connection
    config = db_config.dup
    config.merge! :database => db_name if db_name
    ActiveRecord::Base.establish_connection config
  end
  
  def drop_all_database_tables(connection = nil)
    established = nil
    connection ||= begin 
      ActiveRecord::Base.connection
    rescue
      ActiveRecord::Base.establish_connection db_config
      established = true
      ActiveRecord::Base.connection
    end
    connection.tables.each { |table| connection.drop_table(table) }
    ActiveRecord::Base.connection.disconnect! if established
  end
  
end
