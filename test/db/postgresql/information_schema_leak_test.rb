require 'test_helper'
require 'db/postgres'

class PostgreSQLInformationSchemaLeakTest < Test::Unit::TestCase

  class CreateISLSchema < ActiveRecord::Migration[4.2]
    def self.up
      execute "CREATE TABLE domains (id int, name varchar(16))"
    end

    def self.down
      execute "DROP TABLE domains"
    end
  end

  class Domain < ActiveRecord::Base
  end

  def setup
    CreateISLSchema.up
  end

  def teardown
    CreateISLSchema.down
  end

  def test_domain_columns
    assert_equal(%w{id name}, Domain.column_names)
  end

end
