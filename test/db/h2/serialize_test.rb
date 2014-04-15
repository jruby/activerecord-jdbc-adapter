require 'db/h2'
require 'serialize'

class H2SerializeTest < Test::Unit::TestCase
  include SerializeTestMethods

  def test_serialized_attribute_should_raise_exception_on_save_with_wrong_type
    Topic.serialize(:content, Hash)
    topic = Topic.new(:content => "string")
    if ENV['CI'] == true.to_s
      version = ActiveRecord::Base.connection.jdbc_connection.meta_data.driver_version
      skip "H2 1.4.177 (beta) bug" if version.index '1.4.177' # "1.4.177 (2014-04-12)"
    end
    begin
      topic.save
      fail "SerializationTypeMismatch not raised"
    rescue ActiveRecord::SerializationTypeMismatch
      # OK
    rescue ActiveRecord::JDBCError => e
      e.sql_exception.printStackTrace if e.sql_exception
    end
  end if Test::Unit::TestCase.ar_version('3.2')

end
