require 'rake_test_support'
require 'db/hsqldb'

class HSQLDBRakeTest < Test::Unit::TestCase
  include RakeTestSupport

  def db_name; 'mem:rake-test.hsqldb'; end
  
  def do_teardown
    drop_rake_test_database
  end

  test 'rake db:create (and db:drop)' do
    @db_name = 'rake-create-test.hsqldb'
    Rake::Task["db:create"].invoke
    assert_true File.exists?("#{@db_name}.lck")
    
    Rake::Task["db:drop"].invoke
    assert_false File.exists?("#{@db_name}.lck")
  end

  test 'rake db:create (and db:drop) in memory db' do
    Rake::Task["db:create"].invoke
    # assert_true File.exists?("#{db_name}.lck")
    
    Rake::Task["db:drop"].invoke
    # assert_false File.exists?("#{db_name}.lck")
  end
  
  test 'rake db:test:purge' do
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      connection.create_table('loosers') { |t| t.string :name }
    end
    
    Rake::Task["db:test:purge"].invoke
    
    ActiveRecord::Base.establish_connection db_config.merge :database => db_name
    assert_false ActiveRecord::Base.connection.table_exists?('loosers')
    ActiveRecord::Base.connection.disconnect!
  end
  
  test 'rake db:structure:dump (and db:structure:load)' do
    db_name = @db_name = 'test-dump-rake.hsqldb'
    create_rake_test_database(db_name) do |connection|
      create_schema_migrations_table(connection)
      connection.create_table('loosers') { |t| t.string :name; t.timestamps }
    end
    
    structure_sql = File.join('db', structure_sql_filename)
    begin
      Dir.mkdir 'db' # db/structure.sql
      Rake::Task["db:structure:dump"].invoke
      
      assert File.exists?(structure_sql)
      # CREATE MEMORY TABLE PUBLIC.LOOSERS
      assert_match /CREATE .*? TABLE PUBLIC.LOOSERS/i, File.read(structure_sql)
      
      # db:structure:load
      drop_rake_test_database(:silence)
      Rake::Task["db:structure:load"].invoke
      
      ActiveRecord::Base.establish_connection db_config.merge :database => db_name
      assert ActiveRecord::Base.connection.table_exists?('loosers')
      ActiveRecord::Base.connection.disconnect!
    ensure
      File.delete(structure_sql) if File.exists?(structure_sql)
      Dir.rmdir 'db'
    end
  end
  
#  test 'rake db:charset' do
#    expect_rake_output('UTF-8')
#    Rake::Task["db:charset"].invoke
#  end
  
  def create_rake_test_database(db_name = self.db_name)
    ActiveRecord::Base.establish_connection db_config.merge :database => db_name
    if block_given?
      yield ActiveRecord::Base.connection
    end
    ActiveRecord::Base.connection.shutdown
    ActiveRecord::Base.connection.disconnect!
  end
  
  def drop_rake_test_database(silence = nil)
    ActiveRecord::Base.establish_connection db_config.merge :database => @db_name
    ActiveRecord::Base.connection.shutdown
    ActiveRecord::Base.connection.disconnect!
    
    Dir.glob("#{@db_name}*").each do |f|
      if silence
        FileUtils.rm_rf(f) if File.exists?(f)
      else
        FileUtils.rm_rf(f)
      end
      FileUtils.rmdir(f) if File.directory?(f)
    end
  end
  
end
