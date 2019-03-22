require 'test_helper'
require 'db/mssql'

class MSSQLExceptionsTest < Test::Unit::TestCase
  class CreateExceptionTests < ActiveRecord::Migration
    def self.up
      create_table :exception_tests do |t|
        t.string :email

        t.timestamps
      end

      add_index :exception_tests, :email, unique: true
    end

    def self.down
      drop_table :exception_tests
    end
  end

  class ExceptionTest < ActiveRecord::Base
  end

  def setup
    CreateExceptionTests.up
  end

  def teardown
    CreateExceptionTests.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_uniqueness_violations_are_translated_to_specific_exception
    ExceptionTest.create!(email: 'cool@awesome.me')

    error = assert_raises(ActiveRecord::RecordNotUnique) do
      ExceptionTest.create!(email: 'cool@awesome.me')
    end

    assert_not_nil error.cause
  end
end
