require 'test_helper'
require 'db/postgres'

class PrimaryKeyIsNotTheFirstColumnTest < Test::Unit::TestCase

  class CreateEmployees < ActiveRecord::Migration[4.2]
    def self.up
      create_table 'employees', :id => false do |t|
        t.string :full_name, :null => false
        t.primary_key :id, :serial
      end
    end
    def self.down
      drop_table 'employees'
    end
  end

  def setup
    CreateEmployees.up
  end

  def teardown
    CreateEmployees.down
  end

  class Employee < ActiveRecord::Base
  end

  def test_returning_when_primary_key_is_not_the_first_column
    e = Employee.new
    e.full_name = 'Slartibartfast'
    e.save!
    e.reload
    assert_equal 1, e.id
  end

end
