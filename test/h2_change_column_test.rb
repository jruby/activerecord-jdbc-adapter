require 'jdbc_common'
require 'db/h2'

class H2ChangeColumnTest < Test::Unit::TestCase

  class Person < ActiveRecord::Base; end

  class CreatePeopleTable < ActiveRecord::Migration
    def self.up
      create_table :people do |t|
        t.integer :phone
      end
    end

    def self.down
      drop_table :people
    end
  end

  def setup
    CreatePeopleTable.up
  end

  def teardown
    CreatePeopleTable.down
  end

  def test_should_change_column_type
    ActiveRecord::Migration.change_column :people, :phone, :string
    Person.reset_column_information

    p = Person.create!(:phone => 'ABC')
    assert_equal 'ABC', p.phone
  end

  def test_sets_defaults_on_column
    ActiveRecord::Migration.change_column :people, :phone, :string, :default => '123456'
    Person.reset_column_information

    p = Person.create!
    assert_equal '123456', p.phone
  end

  def test_should_change_column_default_value
    ActiveRecord::Migration.add_column    :people, :email, :string, :default => 'foo@example.com'
    ActiveRecord::Migration.change_column :people, :email, :string, :default => 'bar@example.com'
    Person.reset_column_information

    p = Person.create!
    assert_equal 'bar@example.com', p.email
  end

  def test_should_set_non_null_restriction
    ActiveRecord::Migration.change_column :people, :phone, :string, :null => false
    Person.reset_column_information
    assert_raises(ActiveRecord::StatementInvalid) { Person.create! }
  end

  def test_should_set_null_restriction_with_default
    p = Person.create!
    ActiveRecord::Migration.change_column :people, :phone, :string, :null => true, :default => '123456'
    Person.reset_column_information

    assert_nil p.reload.phone
    assert_equal '123456', Person.create!.phone
  end
end

