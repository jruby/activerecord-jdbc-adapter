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
  else
    def test_skipped
    end
  end
end
