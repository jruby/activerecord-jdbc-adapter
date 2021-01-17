require 'jdbc_common'
require 'db/mssql'

class MSSQLIgnoreSystemViewsTest < Test::Unit::TestCase
  include MigrationSetup

  def test_system_views_ignored

    assert_true table_exists?('users')
    assert_false table_exists?('hello')

    assert_not_include tables, 'views'
    assert_false table_exists?("sys.views")
    assert_false table_exists?("information_schema.views")
    assert_false table_exists?("dbo.views"), %{table_exists?("dbo.views")}

    ActiveRecord::Schema.define { suppress_messages { create_table :views } }
    assert_include tables, 'views'
    assert_true table_exists?(:views), %{table_exists?(:views)}
    ActiveRecord::Schema.define { suppress_messages { drop_table :views } }

  ensure
    ActiveRecord::Base.connection.drop_table(:views) rescue nil
  end

  private

  def tables
    ActiveRecord::Base.connection.tables
  end
  
  def table_exists?(*args)
    ActiveRecord::Base.connection.table_exists?(*args)
  end
    
end

