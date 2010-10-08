require 'abstract_db_create'
require 'db/postgres'

class PostgresDbDropTest < Test::Unit::TestCase
  include AbstractDbCreate

  def db_config
    POSTGRES_CONFIG
  end

  def test_dropping_nonexistent_database_does_not_raise_exception
    assert_nothing_raised do
      Rake::Task["db:drop"].invoke
    end
  end
end
