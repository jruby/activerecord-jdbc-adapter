require File.expand_path('test_helper', File.dirname(__FILE__))

class DerbySchemaTest < Test::Unit::TestCase

  def test_current_schema
    assert_equal 'SA', connection.current_schema
  end

  def test_create_and_change_schema
    schema = connection.current_schema
    connection.create_table(:muu)
    assert_include connection.tables, 'muu'

    connection.create_schema('FOO')
    connection.current_schema = 'FOO'
    assert_equal 'FOO', connection.current_schema
    assert_not_include connection.tables, 'muu'
  ensure
    connection.drop_schema('FOO')
    connection.set_schema schema
    connection.drop_table(:muu)
  end

end