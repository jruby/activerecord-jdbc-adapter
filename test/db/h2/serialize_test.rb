require 'db/h2'
require 'serialize'

class H2SerializeTest < Test::Unit::TestCase
  include SerializeTestMethods

  def test_serialized_attribute_should_raise_exception_on_save_with_wrong_type
    Topic.serialize(:content, Hash)
    begin
      topic = Topic.new(:content => "string")
      topic.save
      fail "SerializationTypeMismatch not raised"
    rescue ActiveRecord::SerializationTypeMismatch
      # OK
    rescue ActiveRecord::JDBCError => e
      e.sql_exception.printStackTrace if e.sql_exception
    end
  end if Test::Unit::TestCase.ar_version('3.2')

end
