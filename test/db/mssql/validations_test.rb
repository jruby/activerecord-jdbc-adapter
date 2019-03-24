require 'test_helper'
require 'db/mssql'

class MSSQLValidationTest < Test::Unit::TestCase
  class CreateValidationTests < ActiveRecord::Migration
    def self.up
      create_table :validation_tests do |t|
        t.string :name
        t.string :email

        t.timestamps
      end
    end

    def self.down
      drop_table :validation_tests
    end
  end

  class ValidationTest < ActiveRecord::Base
    # By default case_sensitive is true
    validates :name, uniqueness: true
    validates :email, uniqueness: { case_sensitive: false, allow_nil: true }
  end

  def setup
    CreateValidationTests.up
  end

  def teardown
    CreateValidationTests.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_validate_case_sensitive_uniqueness
    poet1 = ValidationTest.new(name: 'César Vallejo')

    assert poet1.valid?
    assert poet1.save

    poet2 = ValidationTest.new(name: 'césar vallejo')

    assert poet2.valid?
    assert poet2.save

    poet3 = ValidationTest.new(name: 'cesar vallejo')

    assert poet3.valid?
    assert poet3.save
  end

  def test_validate_case_sensitive_uniqueness_accent_insensitive
    adapter = ActiveRecord::ConnectionAdapters::MSSQLAdapter
    adapter.cs_equality_operator = 'COLLATE Latin1_General_CS_AI_WS'

    poet1 = ValidationTest.new(name: 'César Vallejo')

    assert poet1.valid?
    assert poet1.save

    poet2 = ValidationTest.new(name: 'césar vallejo')

    assert poet2.valid?
    assert poet2.save

    poet3 = ValidationTest.new(name: 'cesar vallejo')

    assert poet3.invalid?
  end
end
