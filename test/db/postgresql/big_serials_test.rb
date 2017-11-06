# encoding: utf-8
require 'test_helper'
require 'db/postgres'

class PostgresqlLargeKeysTest < Test::Unit::TestCase # ActiveRecord::TestCase

  def setup
    connection.create_table('big_serials', :id => :bigserial) do |t|
      t.string 'name'
    end
  end

  def test_omg
    schema = StringIO.new
    ActiveRecord::SchemaDumper.dump(connection, schema)
    assert_match "create_table \"big_serials\", id: :bigserial, force: :cascade",
      schema.string
  end

  def teardown
    connection.drop_table "big_serials"
  end

end
