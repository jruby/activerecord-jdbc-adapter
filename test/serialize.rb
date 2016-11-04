require 'models/topic'
require 'ostruct'

# borrowed from AR/test/cases/serialized_attribute_test.rb

module SerializeTestMethods

  def self.included(base)
    base.extend UpAndDown
  end

  module UpAndDown

    def startup
      super
      TopicMigration.up
    end

    def shutdown
      super
      TopicMigration.down
    end

  end

  def setup
    super
  end

  def teardown
    super
    Topic.serialize("content")
  end

  MyObject = Struct.new :attribute1, :attribute2

  def test_serialized_attribute
    Topic.serialize("content", MyObject)

    myobj = MyObject.new('value1', 'value2')
    topic = Topic.create("content" => myobj)
    assert_equal(myobj, topic.content)

    topic.reload
    assert_equal(myobj, topic.content)
  end

  def test_serialized_attribute_in_base_class
    Topic.serialize("content", Hash)

    hash = { 'content1' => 'value1', 'content2' => 'value2' }
    important_topic = ImportantTopic.create("content" => hash)
    assert_equal(hash, important_topic.content)

    important_topic.reload
    assert_equal(hash, important_topic.content)
  end

  # This test was added to fix GH #4004. Obviously the value returned
  # is not really the value 'before type cast' so we should maybe think
  # about changing that in the future.
#  def test_serialized_attribute_before_type_cast_returns_unserialized_value
#    Topic.serialize :content, Hash
#
#    t = Topic.new :content => { :foo => :bar }
#    assert_equal({ :foo => :bar }, t.content_before_type_cast)
#    t.save!
#    t.reload
#    assert_equal({ :foo => :bar }, t.content_before_type_cast)
#  end

#  def test_serialized_attributes_before_type_cast_returns_unserialized_value
#    Topic.serialize :content, Hash
#
#    t = Topic.new :content => { :foo => :bar }
#    assert_equal({ :foo => :bar }, t.attributes_before_type_cast["content"])
#    t.save!
#    t.reload
#    assert_equal({ :foo => :bar }, t.attributes_before_type_cast["content"])
#  end

  def test_serialized_ostruct
    Topic.serialize :content, OpenStruct

    t = Topic.new
    t.content.foo = 'bar'
    t.save!
    assert_equal 'bar', t.reload.content.foo
  end

  def test_serialized_attribute_declared_in_subclass
    hash = { 'important1' => 'value1', 'important2' => 'value2' }
    important_topic = ImportantTopic.create("important" => hash)
    assert_equal(hash, important_topic.important)

    important_topic.reload
    assert_equal(hash, important_topic.important)
    assert_equal(hash, important_topic.read_attribute(:important))
  end

  def test_serialized_time_attribute
    myobj = Time.local(2008,1,1,1,0)
    topic = Topic.create("content" => myobj).reload
    assert_equal(myobj, topic.content)
  end

  def test_serialized_string_attribute
    myobj = "Yes"
    topic = Topic.create("content" => myobj).reload
    assert_equal(myobj, topic.content)
  end

  def test_nil_serialized_attribute_with_class_constraint
    topic = ImportantTopic.new
    assert_nil topic.content
  end

  def test_nil_serialized_attribute_without_class_constraint
    topic = Topic.new
    assert_nil topic.content
  end

  def test_nil_not_serialized_without_class_constraint
    #ActiveRecord::Base.logger.level = Logger::DEBUG
    topic = Topic.new(:content => nil); topic.save!
    # NOTE: seems smt broken on AR 3.2's side inserts '--- \n' !
    #assert_equal 1, Topic.where(:content => nil).count
    assert_nil topic.reload.content
  ensure
    #ActiveRecord::Base.logger.level = Logger::WARN
  end

  def test_nil_not_serialized_with_class_constraint
    #ActiveRecord::Base.logger.level = Logger::DEBUG
    topic = ImportantTopic.new(:content => nil); topic.save!
    # NOTE: seems smt broken on AR 3.2's side inserts '--- \n' !
    #assert_equal 1, ImportantTopic.where(:content => nil).count
    assert_nil topic.reload.content
  ensure
    #ActiveRecord::Base.logger.level = Logger::WARN
  end

  def test_serialized_attribute_should_raise_exception_on_new_with_wrong_type
    Topic.serialize(:content, Hash)
    assert_raise(ActiveRecord::SerializationTypeMismatch) { Topic.new(:content => "string") }
  end

  def test_should_raise_exception_on_serialized_attribute_with_type_mismatch
    myobj = MyObject.new('value1', 'value2')
    topic = Topic.new(:content => myobj)
    assert topic.save
    Topic.serialize(:content, Hash)
    assert_raise(ActiveRecord::SerializationTypeMismatch) { Topic.find(topic.id).content }
  end

  def test_serialized_attribute_with_class_constraint
    settings = { "color" => "blue" }
    Topic.serialize(:content, Hash)
    topic = Topic.new(:content => settings)
    assert topic.save
    assert_equal(settings, Topic.find(topic.id).content)
  end

  def test_serialized_default_class
    Topic.serialize(:content, Hash)
    topic = Topic.new
    assert_equal Hash, topic.content.class
    assert_equal Hash, topic.read_attribute(:content).class
    topic.content["beer"] = "MadridRb"
    assert topic.save
    topic.reload
    assert_equal Hash, topic.content.class
    assert_equal "MadridRb", topic.content["beer"]
  end

  def test_serialized_no_default_class_for_object
    topic = Topic.new
    assert_nil topic.content
  end

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

  def test_serialize_with_coder
    some_class = Struct.new(:foo) do
      def self.dump(value)
        value.foo
      end

      def self.load(value)
        new(value)
      end
    end

    Topic.serialize(:content, some_class)
    topic = Topic.new(:content => some_class.new('my value'))
    topic.save!
    topic.reload
    assert_kind_of some_class, topic.content
    assert_equal topic.content, some_class.new('my value')
  end

  def test_serialize_attribute_via_select_method_when_time_zone_available
    ActiveRecord::Base.time_zone_aware_attributes = true
    Topic.serialize(:content, MyObject)

    myobj = MyObject.new('value1', 'value2')
    topic = Topic.create(:content => myobj)

    assert_equal myobj, Topic.select(:content).find(topic.id).content
    assert_raise(ActiveModel::MissingAttributeError) { Topic.select(:id).find(topic.id).content }
  ensure
    ActiveRecord::Base.time_zone_aware_attributes = false
  end
end
