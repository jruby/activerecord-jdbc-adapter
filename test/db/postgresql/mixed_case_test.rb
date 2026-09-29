require 'db/postgres'
require 'models/entry'
require 'models/mixed_case'

class PostgreSQLMixedCaseTest < Test::Unit::TestCase
  
  def setup
    Migration::MixedCase.up
    @table_name = User.table_name
    User.table_name = 'tblUsers'
    User.reset_column_information
  end

  def teardown
    User.table_name = @table_name
    User.reset_column_information
    Migration::MixedCase.down
  end

  def test_create
    mixed_case = MixedCase.create :SOME_value => 'some value'
    assert_equal 'some value', mixed_case.SOME_value
  end

  def test_find_mixed_table_name
    # BUG(?): This never worked on CRuby either when using non-returning inserts due to mixed-case table names not being handled properly.
    # This should probably be fixed in rails/PG.
    omit "CRuby PG doesn't handle mixed-case tables without insert_returning" unless connection.use_insert_returning?

    User.create :firstName => "Nick", :lastName => "Sieger"
    u = User.first
    assert_equal "Nick Sieger", "#{u.firstName} #{u.lastName}"
  end

end