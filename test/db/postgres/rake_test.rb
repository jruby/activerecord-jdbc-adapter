require 'rake_test_support'
require 'db/postgres'

class PostgresRakeTest < Test::Unit::TestCase
  include RakeTestSupport

  def db_config
    POSTGRES_CONFIG
  end

  def do_teardown
    # ...
  end
  
  PSQL_EXECUTABLE = find_executable?("psql")
  
  test 'rake db:create (and db:drop)' do
    Rake::Task["db:create"].invoke
    if PSQL_EXECUTABLE
      output = psql("-d template1 -c '\\\l'")
      assert_match /#{db_name}/m, output
    end
    
    Rake::Task["db:drop"].invoke
    if PSQL_EXECUTABLE
      output = psql("-d template1 -c '\\\l'")
      assert_no_match /#{db_name}/m, output
    end
  end

  test 'rake db:drop (non-existing database)' do
    Rake::Task["db:drop"].invoke
  end
  
  test 'rake db:test:purge' do
    Rake::Task["db:test:purge"].invoke
  end

  test 'rake db:create does not load full environment' do
    begin
      Rake::Task["db:create"].invoke
      assert @rails_env_set
      assert ! defined?(@full_environment_loaded) || ! @full_environment_loaded
    ensure
      Rake::Task["db:drop"].invoke rescue nil
    end
  end if ActiveRecord::VERSION::MAJOR < 4
  
  private
  
  def psql(args)
    args = args.join(' ') unless args.is_a?(String)
    if db_config[:host] != 'localhost'
      args = "--host=#{db_config[:host]} #{args}"
    end
    if username = ENV['PSQL_USERNAME']
      args = "--username=#{username} #{args}"
    end
    `psql #{args}`
  end
  
end