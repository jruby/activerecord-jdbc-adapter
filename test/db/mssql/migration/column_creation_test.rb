require 'test_helper'
require 'db/mssql'
require 'db/mssql/migration/helper'

module MSSQLMigration
  class ColumnCreationTest < Test::Unit::TestCase
    include TestHelper

    def test_add_column_without_limit
      assert_nothing_raised do
        add_column :entries, :description, :string, limit: nil
      end

      Entry.reset_column_information
      assert_nil Entry.columns_hash['description'].limit
    end

  end
end
