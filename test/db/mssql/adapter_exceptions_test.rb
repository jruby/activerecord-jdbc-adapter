require 'test_helper'
require 'db/mssql'

class MSSQLExceptionsTest < Test::Unit::TestCase
  class CreateSystemExceptions < ActiveRecord::Migration
    def self.up
      create_table :system_exceptions do |t|
        t.string :name, limit: 50
        t.text :notes

        t.timestamps
      end
      create_table :exception_sources do |t|
        t.references :system_exception, foreign_key: true
        t.string :source_name, limit: 20
        t.string :source_ip
        t.binary :logfile

        t.timestamps
      end

      add_index :system_exceptions, :name, unique: true
    end

    def self.down
      drop_table :exception_sources
      drop_table :system_exceptions
    end
  end

  class SystemException < ActiveRecord::Base
  end

  class ExceptionSource < ActiveRecord::Base
  end

  def setup
    CreateSystemExceptions.up
  end

  def teardown
    CreateSystemExceptions.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_uniqueness_violations_are_translated_to_specific_exception
    SystemException.create!(name: 'uniqueness_violation')

    error = assert_raises(ActiveRecord::RecordNotUnique) do
      SystemException.create!(name: 'uniqueness_violation')
    end

    assert_not_nil error.cause
  end

  def test_foreign_key_violations_are_translated_to_specific_exception
    exception = SystemException.create!(name: 'foreign_key_violation')
    the_id = exception.id
    exception.destroy

    error = assert_raises(ActiveRecord::InvalidForeignKey) do
      ExceptionSource.create!(
        system_exception_id: the_id, source_name: 'accounting_system'
      )
    end

    assert_not_nil error.cause
  end

  def test_value_too_long_violations_are_translated_to_specific_exception
    exception = SystemException.create!(name: 'value_too_long_violation')

    error = assert_raises(ActiveRecord::ValueTooLong) do
      ExceptionSource.create!(
        system_exception_id: exception.id, source_name: 'portal_' * 5
      )
    end

    assert_not_nil error.cause
  end
end
