require 'test_helper'
require 'db/mssql'
require 'db/mssql/migration/helper'

module MSSQLMigration
  class ColumnModificationTest < Test::Unit::TestCase
    include TestHelper

    def test_rename_column
      assert_nothing_raised do
        add_column :entries, :test_rename_column, :string
      end

      Entry.reset_column_information
      Entry.create(test_rename_column: 'hola')

      assert_nothing_raised do
        rename_column :entries, :test_rename_column, :greetings
      end

      Entry.reset_column_information
      assert Entry.column_names.include? 'greetings'
      assert_equal ['hola'], Entry.all.map(&:greetings)
    end

    def test_rename_column_with_an_index
      add_column 'entries', :hat_name, :string
      add_index :entries, :hat_name

      assert_equal 1, connection.indexes('entries').size
      rename_column 'entries', 'hat_name', 'name'

      assert_equal ['index_entries_on_name'], connection.indexes('entries').map(&:name)
    end

    def test_rename_column_with_multi_column_index
      add_column 'entries', :hat_size, :integer
      add_column 'entries', :hat_style, :string, limit: 100
      add_index 'entries', ['hat_style', 'hat_size'], unique: true

      rename_column 'entries', 'hat_size', 'size'
      assert_equal ['index_entries_on_hat_style_and_size'], connection.indexes('entries').map(&:name)

      rename_column 'entries', 'hat_style', 'style'
      assert_equal ['index_entries_on_style_and_size'], connection.indexes('entries').map(&:name)
    end

    def test_change_column_default
      assert_nothing_raised do
        add_column :entries, :test_change_column_default, :string, default: 'unchanged'
      end

      columns = Entry.columns
      assert column = columns.find{ |c| c.name == 'test_change_column_default' }
      assert_equal column.default, 'unchanged'

      assert_nothing_raised do
        change_column_default :entries, :test_change_column_default, 'changed'
      end

      Entry.reset_column_information
      columns = Entry.columns
      assert column = columns.find{ |c| c.name == 'test_change_column_default' }
      assert_equal column.default, 'changed'
    end
  end
end
