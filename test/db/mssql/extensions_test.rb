require 'test_helper'
require 'db/mssql'

class MSSQLExtensionsTest < Test::Unit::TestCase
  class CreateAccounts < ActiveRecord::Migration
    def self.up
      create_table :accounts do |t|
        t.string :first_name
        t.string :last_name
        t.string :username

        t.timestamps
      end
    end

    def self.down
      drop_table :accounts
    end
  end

  class Account < ActiveRecord::Base
  end

  def self.startup
    CreateAccounts.up
  end

  def self.shutdown
    CreateAccounts.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_attributes_for_update_override_create_with_after_create_callback
    other_account = Class.new(Account) do
      after_create do
        update_attributes!(username: "#{first_name}#{last_name[0]}")
      end
    end

    assert_nothing_raised do
      other_account.create(first_name: 'Alan', last_name: 'Turing')
    end
  end

  def test_attributes_for_update_override_save_with_after_create_callback
    other_account = Class.new(Account) do
      after_create do
        update_attributes!(username: "#{first_name}#{last_name[0]}")
      end
    end
    marie = other_account.new(first_name: 'Marie')
    marie.last_name = 'Curie'

    assert_nothing_raised do
      marie.save
    end
  end
end
