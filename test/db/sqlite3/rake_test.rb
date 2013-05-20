require 'rake_test_support'
require 'db/sqlite3'

class SQLite3RakeTest < Test::Unit::TestCase
  include RakeTestSupport

  def db_config; SQLITE3_CONFIG; end
  def db_name; 'rake_test.sqlite3'; end
  
  def do_setup
    File.delete('rake_test.sqlite3') if File.exists?('rake_test.sqlite3')
  end
  
  def do_teardown
    File.delete('rake_test.sqlite3') if File.exists?('rake_test.sqlite3')
  end

  test 'rake db:create (and db:drop)' do
    Rake::Task["db:create"].invoke
    assert_true File.exists?('rake_test.sqlite3')
    
    Rake::Task["db:drop"].invoke
    assert_false File.exists?('rake_test.sqlite3')
  end
  
  test 'rake db:test:purge' do
    # Rake::Task["db:create"].invoke
    ActiveRecord::Base.establish_connection db_config.merge :database => db_name
    ActiveRecord::Base.connection.create_table('users') { |t| t.string :name }
    ActiveRecord::Base.connection.disconnect!
    
    Rake::Task["db:test:purge"].invoke
    
    ActiveRecord::Base.establish_connection db_config.merge :database => db_name
    assert_false ActiveRecord::Base.connection.table_exists?('users')
    ActiveRecord::Base.connection.disconnect!
  end
  
  test 'rake db:charset' do
    main = TOPLEVEL_BINDING.eval('self')
    main.expects(:puts).with('UTF-8')
    Rake::Task["db:charset"].invoke
  end
  
end
