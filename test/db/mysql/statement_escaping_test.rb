require 'jdbc_common'
require 'db/mysql'

class StatementEscapingTest < Test::Unit::TestCase
  include FixtureSetup

  def setup
    super
    ActiveRecord::Base.clear_active_connections!
    @config = ActiveRecord::Base.connection.config
  end

  def teardown
    ActiveRecord::Base.clear_active_connections!
    ActiveRecord::Base.establish_connection @config
    super
  end

  def test_false
    set_escape_processing false
    e1 = Entry.create! :title => "\\'{}{"
    e2 = Entry.find(e1.id)
    assert_equal "\\'{}{", e2.title
  end

  def set_escape_processing(value)
    ActiveRecord::Base.establish_connection @config.merge(:statement_escape_processing => value)
  end

  def test_not_set
    set_escape_processing nil
    verify_escaped
  end

  def verify_escaped
    e = Entry.create! :title => 'abc'
    rs = ActiveRecord::Base.connection.execute(
        "SELECT {fn concat(title, 'xyz')} AS title from entries WHERE id = #{e.id}")
    assert_equal 'abcxyz', rs.first['title']
  end

  def test_true
    set_escape_processing true
    verify_escaped
  end
end