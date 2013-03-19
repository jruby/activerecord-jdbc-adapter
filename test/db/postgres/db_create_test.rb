require 'abstract_db_create'
require 'db/postgres'

class PostgresDbCreateTest < Test::Unit::TestCase
  include AbstractDbCreate

  def db_config
    POSTGRES_CONFIG
  end

  PSQL_EXECUTABLE = find_executable?("psql")
  
  def test_rake_db_create
    omit_unless PSQL_EXECUTABLE
    Rake::Task["db:create"].invoke
    assert_match /#{@db_name}/m, psql("-d template1 -c '\\\l'")
  end

  def test_rake_db_test_purge
    # omit_unless PSQL_EXECUTABLE
    Rake::Task["db:create"].invoke
    Rake::Task["db:test:purge"].invoke
  end

  def test_rake_db_create_does_not_load_full_environment
    Rake::Task["db:create"].invoke
    assert @rails_env_set
    assert !defined?(@full_environment_loaded) || !@full_environment_loaded
  end
  
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
