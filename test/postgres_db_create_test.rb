require 'abstract_db_create'
require 'db/postgres'

class PostgresDbCreateTest < Test::Unit::TestCase
  include AbstractDbCreate

  def db_config
    POSTGRES_CONFIG
  end

  if find_executable?("psql")
    def test_rake_db_create
      Rake::Task["db:create"].invoke
      output = `psql -c '\\l'`
      assert output =~ /#{@db_name}/m
    end

    def test_rake_db_test_purge
      Rake::Task["db:create"].invoke
      Rake::Task["db:test:purge"].invoke
    end
  else
    def test_skipped
    end
  end

  def test_rake_db_create_does_not_load_full_environment
    Rake::Task["db:create"].invoke
    assert @rails_env_set
    assert !@full_environment_loaded
  end
end
