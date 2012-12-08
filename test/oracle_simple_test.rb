require 'jdbc_common'
require 'db/oracle'

class OracleSimpleTest < MiniTest::Unit::TestCase
  include SimpleTestMethods

  def test_default_id_type_is_integer
    assert Integer === Entry.first.id
  end

  def test_sequences_are_not_cached
    ActiveRecord::Base.transaction do
      e1 = Entry.create :title => "hello1"
      e2 = Entry.create :title => "hello2"
      assert e1.id != e2.id
    end
  end
end
