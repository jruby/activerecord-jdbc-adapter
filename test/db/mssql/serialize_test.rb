require 'db/mssql'
require 'serialize'

class MSSQLSerializeTest < Test::Unit::TestCase
  include SerializeTestMethods

  def test_serialized_boolean_value_true
    Topic.serialize(:content)
    topic = Topic.new(:content => true)
    assert topic.save
    topic = topic.reload
    assert_equal true, topic.content
  end

  def test_serialized_boolean_value_false
    Topic.serialize(:content)
    topic = Topic.new(:content => false)
    assert topic.save
    topic = topic.reload
    assert_equal false, topic.content
  end

  def test_serialized_with_json_coder
    Topic.serialize(:content, JSON)
    value = {
      'name' => 'Joe',
      'age' => 23,
      'clean' => true,
      'traits' => ['caring', 'cheerful'],
      'pets' => { 'cat' => 'Gardfield', 'dog' => 'Droopy'}
    }

    topic = Topic.new(:content => value)
    assert topic.save
    topic = topic.reload
    assert_equal value, topic.content
  end


  def test_serialized_with_json_coder_simple_types
    Topic.serialize(:content, JSON)

    topic = Topic.new(:content => nil)
    assert topic.save
    topic = topic.reload
    assert_equal nil, topic.content

    values = [{}, [], 2, 3.1415, 'wow', "hello\nhola"]

    values.each do |item|
      topic.content = item
      assert topic.save
      topic.reload
      assert_equal item, topic.content
    end
  end

  def test_serialized_as_array
    Topic.serialize(:content, Array)

    value = [1, 3.14, 'hola', true]

    topic = Topic.new(:content => value)
    assert topic.save
    topic = topic.reload
    assert_equal value, topic.content

    topic.content << false
    topic.content << '7'

    assert topic.save
    topic = topic.reload
    assert_equal value | [false, '7'], topic.content

    assert_raise ActiveRecord::SerializationTypeMismatch do
      topic.content = 'hello'
    end
  end
end
