require 'test_helper'
require 'db/mssql'

class MSSQLColumnPrimaryKeysTest < Test::Unit::TestCase
  class CreatePrimaryKeysTests < ActiveRecord::Migration
    def self.up
      create_table :primary_keys_tests, force: true, id: false do |t|
        t.string :custom_id
        t.string :content
      end
    end

    def self.down
      drop_table :primary_keys_tests
    end
  end

  class PrimaryKeysTest < ActiveRecord::Base
    self.primary_key = :custom_id
  end

  def self.startup
    CreatePrimaryKeysTests.up
  end

  def self.shutdown
    CreatePrimaryKeysTests.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_custom_primary_key
    record = PrimaryKeysTest.create!(custom_id: '666')

    record.id = '711'
    record.save!

    record = PrimaryKeysTest.first
    assert_equal '711', record.id
  end
end
