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

    def test_rename_nonexistent_column
      exception = ActiveRecord::ActiveRecordError

      assert_raise(exception) do
        rename_column :entries, :nonexistent, :should_fail
      end
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

    def test_remove_column_with_multi_column_index
      # NOTE: This test is specific to this adapter, the PostgreSQL adapter
      # behaves similarly but the MySQL adapter does not, it removes the index.
      add_column 'entries', :hat_size, :integer
      add_column 'entries', :hat_style, :string, limit: 100
      add_index 'entries', ['hat_style', 'hat_size'], unique: true

      assert_equal 1, connection.indexes(:entries).size
      remove_column(:entries, :hat_size)

      assert_equal [], connection.indexes(:entries).map(&:name)
    end

    def test_change_column_default
      assert_nothing_raised do
        add_column :entries, :test_change_column_default, :string, default: 'unchanged'
      end

      Entry.reset_column_information
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

    def test_change_column_default_with_from_and_to
      assert_nothing_raised do
        add_column :entries, :test_change_column_default_from_to, :string
      end

      assert_nothing_raised do
        change_column_default :entries, :test_change_column_default_from_to, from: nil, to: "Tester"
      end

      Entry.reset_column_information
      assert_equal "Tester", Entry.new.test_change_column_default_from_to
    end

    def test_change_column_null
      assert_nothing_raised do
        add_column :entries, :test_change_column_null_one, :string, null: false
        add_column :entries, :test_change_column_null_two, :string
      end

      Entry.reset_column_information
      sample = Entry.create!(
        test_change_column_null_one: 'something',
        test_change_column_null_two: nil
      )

      assert_nothing_raised do
        change_column_null :entries, :test_change_column_null_one, true
      end

      assert_nothing_raised do
        change_column_null :entries, :test_change_column_null_two, false, 'used to be null'
      end

      Entry.reset_column_information
      columns = Entry.columns
      assert column_one = columns.find{ |c| c.name == 'test_change_column_null_one' }
      assert column_two = columns.find{ |c| c.name == 'test_change_column_null_two' }
      assert_equal column_one.null, true
      assert_equal column_two.null, false
      sample.reload
      assert_equal sample.test_change_column_null_two, 'used to be null'
    end
  end
end
