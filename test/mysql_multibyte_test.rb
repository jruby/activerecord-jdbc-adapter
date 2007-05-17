# To run this script, run the following in a mysql instance:
#
#   drop database if exists weblog_development;
#   create database weblog_development;
#   grant all on weblog_development.* to blog@localhost;

require 'jdbc_common'
require 'db/mysql'

require 'java'

include_class 'java.util.Properties'
include_class 'java.sql.DriverManager'

class ActiveRecord::Base
  cattr_accessor :defined_connections
end

class MysqlMultibyteTest < Test::Unit::TestCase
  include MigrationSetup

  def setup
    super
    config = ActiveRecord::Base.defined_connections["ActiveRecord::Base"].config
    props = Properties.new
    props.setProperty("user", config[:username])
    props.setProperty("password", config[:password])
    @java_con = DriverManager.getConnection(config[:url], props)
    @java_con.setAutoCommit(true)
  end

  def teardown
    @java_con.close
    super
  end

  def test_select_multibyte_string
    @java_con.createStatement().execute("insert into entries (title) values ('テスト')")
    entry = Entry.find(:first)
    assert_equal "テスト", entry.title
    assert_equal entry, Entry.find_by_title("テスト")
  end

  def test_update_multibyte_string
    Entry.create!(:title => "テスト")
    rs = @java_con.createStatement().executeQuery("select title from entries")
    assert rs.next
    assert_equal "テスト", rs.getString(1)
  end
end
