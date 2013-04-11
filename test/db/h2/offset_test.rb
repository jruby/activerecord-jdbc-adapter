require 'db/h2'
require 'jdbc_common'

class H2OffsetTest < Test::Unit::TestCase

  class User < ActiveRecord::Base
  end

  class CreateUsersTable < ActiveRecord::Migration
    def self.up
      create_table :users do |t|
        t.string :firstname
        t.string :lastname
      end
    end

    def self.down
      drop_table :users
    end
  end

  def setup
    CreateUsersTable.up
    User.create(firstname: "John", lastname: "Smith")
    User.create(firstname: "Jill", lastname: "Smith")
    User.create(firstname: "Joan", lastname: "Smith")
    User.create(firstname: "Jason", lastname: "Smith")
    User.create(firstname: "Jack", lastname: "Smith")
    User.create(firstname: "Jenssen", lastname: "Smith")
    User.create(firstname: "Joe", lastname: "Smith")
    User.create(firstname: "Johanna", lastname: "Smith")
    User.create(firstname: "James", lastname: "Smith")
    User.create(firstname: "Jim", lastname: "Smith")
    User.create(firstname: "Jody", lastname: "Smith")
  end

  def teardown
    CreateUsersTable.down
  end

  def test_offset
    query = Arel::Table.new(:users).skip(3)
    assert_nothing_raised do
      sql = query.to_sql
      assert_equal "SELECT LIMIT 3", sql[0..13], "SQL statement was not generated, properly"
    end
  end
end
