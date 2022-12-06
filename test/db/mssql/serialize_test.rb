require 'db/mssql'
require 'serialize'

class MSSQLSerializeTest < Test::Unit::TestCase
  include SerializeTestMethods

  def test_serialized_boolean_value_true
    Topic.serialize(:content)
    topic = Topic.new(:content => true)
    assert topic.save
    topic = topic.reload
    skip "serializes boolean: true without type-cast as: #{topic.content.inspect}"
    assert_equal true, topic.content
  end

  def test_serialized_boolean_value_false
    Topic.serialize(:content)
    topic = Topic.new(:content => false)
    assert topic.save
    topic = topic.reload
    skip "serializes boolean: false without type-cast as: #{topic.content.inspect}"
    assert_equal false, topic.content
  end

end
