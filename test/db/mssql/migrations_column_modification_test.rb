require 'test_helper'
require 'db/mssql'

class MSSQLColumnModificationTest < Test::Unit::TestCase
  class CreateColumnModifications< ActiveRecord::Migration
    def self.up
      create_table :entries do |t|
        t.string :name

        t.timestamps
      end
    end

    def self.down
      drop_table :entries
    end
  end

  class Entry < ActiveRecord::Base
  end

  def self.startup
    CreateColumnModifications.up
  end

  def self.shutdown
    CreateColumnModifications.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_change_column_default
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column :entries, :test_change_column_default, :string, default: 'unchanged'
      end
    end

    columns = Entry.columns
    assert column = columns.find{ |c| c.name == 'test_change_column_default' }
    assert_equal column.default, 'unchanged'

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        change_column_default :entries, :test_change_column_default, 'changed'
      end
    end

    Entry.reset_column_information
    columns = Entry.columns
    assert column = columns.find{ |c| c.name == 'test_change_column_default' }
    assert_equal column.default, 'changed'
  end
end
