#! /usr/bin/env jruby

require 'jdbc_common'
require 'db/mssql'

class IgnoreSystemViewsTest < Test::Unit::TestCase

  include MigrationSetup

  def test_system_views_ignored
    assert_equal true, table_exists?("sys.views"), %{table_exists?("sys.views")}
    assert_equal true, table_exists?("information_schema.views"), %{table_exists?("information_schema.views")}
    assert_equal false, table_exists?("dbo.views"), %{table_exists?("dbo.views")}
    assert_equal false, table_exists?(:views), %{table_exists?(:views)}
    ActiveRecord::Schema.define { suppress_messages { create_table :views } }
    assert_equal true, table_exists?(:views), %{table_exists?(:views)}
    ActiveRecord::Schema.define { suppress_messages { drop_table :views } }
    assert_equal false, table_exists?(:views), %{table_exists?(:views)}
  end

  private

    def table_exists?(*args)
      !!ActiveRecord::Base.connection.table_exists?(*args)
    end
end

