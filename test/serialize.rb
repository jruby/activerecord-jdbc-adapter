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

  def test_list_of_serialized_attributes
    assert_equal %w(content created_on), Topic.serialized_attributes.keys
  end if ActiveRecord::VERSION::STRING <= '4.2'

  def test_serialized_attribute
    Topic.serialize("content", MyObject)

    myobj = MyObject.new('value1', 'value2')
    topic = Topic.create("content" => myobj)
    assert_equal(myobj, topic.content)

    topic.reload
    assert_equal(myobj, topic.content)
  end

  def test_serialized_attribute_init_with
    topic = Topic.allocate
    topic.init_with('attributes' => { 'content' => '--- foo' })
    assert_equal 'foo', topic.content
  end if Test::Unit::TestCase.ar_version('3.0') && ActiveRecord::VERSION::STRING < '4.2'

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

    #pend 'need ostruct.rb stdlib update for 2.3.1' if defined?(JRUBY_VERSION) && JRUBY_VERSION == '9.1.2.0'
    if defined?(JRUBY_VERSION) && JRUBY_VERSION == '9.1.2.0'
      require 'ostruct.rb'
      OpenStruct.class_eval do
        class << self
          alias allocate new
        end
      end
    end
    # due:
    # NoMethodError: undefined method `key?' for nil:NilClass
    # /opt/local/rvm/rubies/jruby-9.1.2.0/lib/ruby/stdlib/ostruct.rb:176:in `respond_to_missing?'
    # ... missing in 9.1.2.0 (fixed in 2.3.1 https://github.com/ruby/ruby/commit/4c1ac0bc0)

    t = Topic.new
    t.content.foo = 'bar'
    t.save!
    assert_equal 'bar', t.reload.content.foo
  end if Test::Unit::TestCase.ar_version('3.1')

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

  def test_serialized_attribute_should_raise_exception_on_save_with_wrong_type
    Topic.serialize(:content, Hash)
    topic = Topic.new(:content => "string")
    assert_raise(ActiveRecord::SerializationTypeMismatch) { topic.save }
  end if Test::Unit::TestCase.ar_version('3.2') && ActiveRecord::VERSION::STRING < '4.2'

  def test_serialized_attribute_should_raise_exception_on_new_with_wrong_type
    Topic.serialize(:content, Hash)
    assert_raise(ActiveRecord::SerializationTypeMismatch) { Topic.new(:content => "string") }
  end if Test::Unit::TestCase.ar_version('4.2')

  def test_should_raise_exception_on_serialized_attribute_with_type_mismatch
    myobj = MyObject.new('value1', 'value2')
    topic = Topic.new(:content => myobj)
    assert topic.save
    Topic.serialize(:content, Hash)
    assert_raise(ActiveRecord::SerializationTypeMismatch) { Topic.find(topic.id).content }
  end if Test::Unit::TestCase.ar_version('3.2')

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
  end if Test::Unit::TestCase.ar_version('3.1')

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
  end if Test::Unit::TestCase.ar_version('3.0')

  def test_serialized_boolean_value_false
    Topic.serialize(:content)
    topic = Topic.new(:content => false)
    assert topic.save
    topic = topic.reload
    assert_equal false, topic.content
  end if Test::Unit::TestCase.ar_version('3.0')

  def test_serialize_with_coder
    skip "not supported on AR >= 4.2" if ar_version('4.2')
    coder = Class.new {
      # Identity
      def load(thing)
        thing
      end

      # base 64
      def dump(thing)
        [thing].pack('m')
      end
    }.new

    Topic.serialize(:content, coder)
    s = 'hello world'
    topic = Topic.new(:content => s)
    assert topic.save
    topic = topic.reload
    assert_equal [s].pack('m'), topic.content
  ensure
    Topic.serialize(:content)
  end if Test::Unit::TestCase.ar_version('3.1')

  def test_serialize_with_bcrypt_coder
    skip "not supported on AR >= 4.2" if ar_version('4.2')
    require 'bcrypt'
    crypt_coder = Class.new {
      def load(thing)
        return unless thing
        BCrypt::Password.new thing
      end

      def dump(thing)
        BCrypt::Password.create(thing).to_s
      end
    }.new

    Topic.serialize(:content, crypt_coder)
    password = 'password'
    topic = Topic.new(:content => password)
    assert topic.save
    topic = topic.reload
    assert_kind_of BCrypt::Password, topic.content
    assert_equal(true, topic.content == password, 'password should equal')
  end if Test::Unit::TestCase.ar_version('3.1')

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
  end if Test::Unit::TestCase.ar_version('4.2')

  def test_serialize_attribute_via_select_method_when_time_zone_available
    ActiveRecord::Base.time_zone_aware_attributes = true
    Topic.serialize(:content, MyObject)

    myobj = MyObject.new('value1', 'value2')
    topic = Topic.create(:content => myobj)

    assert_equal myobj, Topic.select(:content).find(topic.id).content
    assert_raise(ActiveModel::MissingAttributeError) { Topic.select(:id).find(topic.id).content }
  ensure
    ActiveRecord::Base.time_zone_aware_attributes = false
  end if Test::Unit::TestCase.ar_version('3.2')

  def test_date_to_integer_serialization
    date  = Date.today
    serialized_date = Topic::StoreDateAsInteger.dump(date)
    topic = Topic.create(created_on: date)
    topic.reload
    assert_equal serialized_date, topic.attributes_before_type_cast['created_on'].to_i
    assert_equal date, topic.created_on
  end if Test::Unit::TestCase.ar_version('4.2')

#  def test_serialize_attribute_can_be_serialized_in_an_integer_column
#    insures = ['life']
#    person = SerializedPerson.new(:first_name => 'David', :insures => insures)
#    assert person.save
#    person = person.reload
#    assert_equal(insures, person.insures)
#  end

end
