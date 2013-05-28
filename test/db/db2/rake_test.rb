require 'rake_test_support'
require 'db/db2'

class DB2RakeDbCreateTest < Test::Unit::TestCase
  include RakeTestSupport
  
  def db_name; nil; end # using same DB (db:create is a bit IBM-plicated)
  
  test 'rake db:test:purge' do
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      create_schema_migrations_table(connection)
      connection.create_table('ibmers_test') { |t| t.string :name }
    end
    
    Rake::Task["db:test:purge"].invoke

    establish_test_connection
    assert_false ActiveRecord::Base.connection.table_exists?('ibmers_test')
    ActiveRecord::Base.connection.disconnect!
  end

  test 'rake db:structure:dump (and db:structure:load)' do
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      drop_all_database_tables(connection)
      create_sample_database_data(connection)
      create_schema_migrations_table(connection)
      connection.create_table('ibmers') { |t| t.string :name; t.timestamps }
    end
    
    structure_sql = File.join('db', structure_sql_filename)
    begin
      Dir.mkdir 'db' # db/structure.sql
      Rake::Task["db:structure:dump"].invoke
      
      assert File.exists?(structure_sql)
      assert_match /CREATE TABLE ibmers/im, File.read(structure_sql)
      
      # db:structure:load
      drop_all_database_tables
      create_rake_test_database
      Rake::Task["db:structure:load"].invoke
      
      establish_test_connection
      assert ActiveRecord::Base.connection.table_exists?('ibmers')
      ActiveRecord::Base.connection.disconnect!
    ensure
      File.delete(structure_sql) if File.exists?(structure_sql)
      Dir.rmdir 'db'
    end
  end
  
  setup { rm_r 'db' if File.exist?('db') }
  
  private
  
  def establish_test_connection
    config = db_config.dup
    config.merge! :database => db_name if db_name
    ActiveRecord::Base.establish_connection config
  end
  
  def create_sample_database_data(connection)
    filename = File.expand_path('rake_test_data.sql', File.dirname(__FILE__))
    File.read(filename).split(/;\n\n/).each { |ddl| connection.execute(ddl) }
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
