require 'rake_test_support'
require 'db/derby'

class DerbyRakeTest < Test::Unit::TestCase
  include RakeTestSupport
  
  def db_name; 'test-rake.derby'; end
  
  def do_teardown
    drop_rake_test_database(:silence)
  end

  test 'rake db:create' do
    Rake::Task["db:create"].invoke
    assert_true File.directory?('test-rake.derby')
  end

  test 'rake db:drop' do
    create_rake_test_database
    
    Rake::Task["db:drop"].invoke
    assert_false File.directory?('test-rake.derby')
  end
  
  test 'rake db:test:purge' do
    ActiveRecord::Base.connection.disconnect!
    # Rake::Task["db:create"].invoke
    create_rake_test_database do |connection|
      connection.create_table('users') { |t| t.string :name }
    end
    
    Rake::Task["db:test:purge"].invoke
    
    ActiveRecord::Base.establish_connection db_config.merge :database => db_name
    assert_false ActiveRecord::Base.connection.table_exists?('users')
    ActiveRecord::Base.connection.disconnect!
  end
  
  test 'rake db:structure:dump (and db:structure:load)' do
    # NOTE: need to change db name esp. when run with other (rake) tests 
    # since Derby can not handle too much create/rm - gets inconsistent
    db_name = @db_name = 'test-dump-rake.derby'
    create_rake_test_database(db_name) do |connection|
      create_schema_migrations_table(connection)
      connection.create_table('users') { |t| t.string :name; t.timestamps }
    end
    
    structure_sql = File.join('db', structure_sql_filename)
    begin
      Dir.mkdir 'db' # db/structure.sql
      Rake::Task["db:structure:dump"].invoke
      
      assert File.exists?(structure_sql)
      assert_match /CREATE TABLE USERS/i, File.read(structure_sql)
      
      # db:structure:load
      ActiveRecord::Base.connection.disconnect!
      # drop_rake_test_database(:silence)
      ActiveRecord::Base.establish_connection db_config.merge :database => db_name
      ActiveRecord::Base.connection.drop_table('users')
      ActiveRecord::Base.connection.drop_table('schema_migrations')
      ActiveRecord::Base.connection.disconnect!
      
      Rake::Task["db:structure:load"].invoke
      
      ActiveRecord::Base.establish_connection db_config.merge :database => db_name
      assert ActiveRecord::Base.connection.table_exists?('users')
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
    ActiveRecord::Base.connection.disconnect!
  end
  
  def drop_rake_test_database(silence = nil)
    if silence
      FileUtils.rm_rf(@db_name) if File.exists?(@db_name)
    else
      FileUtils.rm_rf(@db_name)
    end
  end
  
end
