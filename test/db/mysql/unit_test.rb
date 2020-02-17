# encoding: ASCII-8BIT
require 'test_helper'

class MySQLUnitTest < Test::Unit::TestCase

  class MySQLImpl
    include ArJdbc::MySQL
    def initialize; end
  end
  mySQL = MySQLImpl.new

  test "quotes string value" do
    {
      "\x00" => "\\0",
      "\n" => "\\n",
      "\r" => "\\r",
      "\x1A" => "\\Z",
      '"' => "\\\"",
      "'" => "\\'",
      "\\" => "\\\\",
    }.each do |s, q|
      assert_equal q, mySQL.quote_string(s)
      assert_equal "string #{q}", mySQL.quote_string(v = "string #{s}"), "while quoting #{v.inspect}"
      assert_equal " #{q}", mySQL.quote_string(v = " #{s}"), "while quoting #{v.inspect}"
      assert_equal "#{q}str", mySQL.quote_string(v = "#{s}str"), "while quoting #{v.inspect}"
    end
  end

  test "quote string (with encoding mysql2 style)" do
    s = "'' \\| \" \x00 \x01 \x1A \xA1 \r \n \\nOiZe \r\n'\x01\X\xA1\xA1\n"
    q = "\\'\\' \\\\| \\\" \\0 \x01 \\Z \xA1 \\r \\n \\\\nOiZe \\r\\n\\'\x01X\xA1\xA1\\n"
    if RUBY_VERSION > '1.9' # mysql2 compatibility
      q2 = q.dup.force_encoding 'UTF-8'
      assert_equal q2, mySQL.quote_string(s)
    else
      assert_equal q, mySQL.quote_string(s)
    end

    if s.respond_to?(:force_encoding)
      s.force_encoding('UTF-8')
      q.force_encoding('UTF-8')
      v = mySQL.quote_string(s)
      assert_equal q, v
      assert_equal q.encoding, v.encoding

      s.force_encoding('ASCII-8BIT')
      v = mySQL.quote_string(s)
      assert_equal q, v
      # Mysql2::Client.new(...).escape(s) compatible :
      assert_equal 'UTF-8', v.encoding.name
      # Mysql.escape_string(s) returns ASCII-8BIT
    end
  end

  test "quote string (utf-8)" do
    s = "\x1Akôň ůň löw9876\r\nqűáéőú\n.éáű-mehehehehehehe0 \x01\x00\x00\\\x02\\'"
    q = "\\Zkôň ůň löw9876\\r\\nqűáéőú\\n.éáű-mehehehehehehe0 \x01\\0\\0\\\\\x02\\\\\\'"
    if RUBY_VERSION > '1.9' # mysql2 compatibility
      q2 = q.dup.force_encoding 'UTF-8'
      assert_equal q2, mySQL.quote_string(s.dup)

      q.force_encoding('UTF-8')
      s.force_encoding('UTF-8')
      assert_equal q, mySQL.quote_string(s)
    else
      assert_equal q, mySQL.quote_string(s.dup)
    end
    assert_equal q, mySQL.quote_string(s)
  end

  test "quote string keeps original string" do
    s = "mehehehehehehe0 \x01 \x02 nothing-to-quote-here ..."
    assert_equal s, mySQL.quote_string(s.dup)

    if s.respond_to?(:force_encoding)
      s.force_encoding('UTF-8')
      assert_equal s, mySQL.quote_string(s.dup)
    end
    assert_equal s, mySQL.quote_string(s)
  end

  test "quote string keeps original (utf-8)" do
    s = "kôň ůň löw9876qűáéőú.éáű-mehehehehehehe0 \x01 \x02 nothing-to-quote"
    assert_equal s, mySQL.quote_string(s.dup)

    if s.respond_to?(:force_encoding)
      s.force_encoding('UTF-8')
      assert_equal s, mySQL.quote_string(s.dup)
    end
    assert_equal s, mySQL.quote_string(s)
  end

  context 'connection' do

    test 'jndi configuration' do
      connection_handler = connection_handler_stub

      config = { :jndi => 'jdbc/TestDS' }
      connection_handler.expects(:jndi_connection).with() { |c| config = c }
      connection_handler.mysql_connection config

      # we do not complete username/database etc :
      assert_nil config[:username]
      assert_nil config[:database]
      assert ! config.key?(:database)
      assert ! config.key?(:url)
      assert ! config.key?(:port)

      assert config[:adapter_class]
    end

    test 'configuration attempts to load MySQL driver by default' do
      skip 'jdbc/mysql not available' if load_jdbc_mysql.nil?

      connection_handler = connection_handler_stub

      config = { database: 'MyDB' }
      connection_handler.expects(:jdbc_connection)
      ::Jdbc::MySQL.expects(:load_driver).with(:require)
      connection_handler.mysql_connection config
    end

    test 'configuration uses driver_name from Jdbc::MySQL' do
      skip 'jdbc/mysql not available' if load_jdbc_mysql.nil?

      connection_handler = connection_handler_stub

      config = { database: 'MyDB' }
      connection_handler.expects(:jdbc_connection).with() { |c| config = c }
      ::Jdbc::MySQL.expects(:driver_name).returns('com.mysql.CustomDriver')
      connection_handler.mysql_connection config
      assert_equal 'com.mysql.CustomDriver', config[:driver]
    end

    test 'configuration sets up properties according to connector/j driver (>= 8.0)' do
      skip 'jdbc/mysql not available' if load_jdbc_mysql.nil?

      connection_handler = connection_handler_stub

      config = { database: 'MyDB' }
      connection_handler.expects(:jdbc_connection).with() { |c| config = c }
      ::Jdbc::MySQL.expects(:driver_name).returns('com.mysql.cj.jdbc.Driver')
      connection_handler.mysql_connection config
      assert_equal 'com.mysql.cj.jdbc.Driver', config[:driver]
      assert_equal 'CONVERT_TO_NULL', config[:properties]['zeroDateTimeBehavior']
      assert_equal false, config[:properties]['useLegacyDatetimeCode']
      assert_equal false, config[:properties]['jdbcCompliantTruncation']
      assert_equal false, config[:properties]['useSSL']
    end

  end

  context 'connection (Jdbc::MySQL missing)' do

    module ::Jdbc; end

    @@jdbc_mysql = false
    def setup
      load_jdbc_mysql
      @@jdbc_mysql = ::Jdbc::MySQL rescue nil
      ::Jdbc.send :remove_const, :MySQL if @@jdbc_mysql
    end

    def teardown
      ::Jdbc.const_set :MySQL, @@jdbc_mysql if @@jdbc_mysql
    end

    test 'configuration sets url and properties assuming mysql driver (<= 5.1)' do
      connection_handler = connection_handler_stub

      config = { host: '127.0.0.1', database: 'MyDB' }
      connection_handler.expects(:jdbc_connection).with() { |c| config = c }
      connection_handler.mysql_connection config

      # we do not complete username/database etc :
      assert_equal 'root', config[:username]
      assert_equal 'com.mysql.jdbc.Driver', config[:driver]
      assert_equal 'jdbc:mysql://127.0.0.1/MyDB', config[:url]
      assert_equal 'UTF-8', config[:properties]['characterEncoding']
      assert_equal 'convertToNull', config[:properties]['zeroDateTimeBehavior']
      assert_equal false, config[:properties]['useLegacyDatetimeCode']
      assert_equal false, config[:properties]['jdbcCompliantTruncation']
      assert_equal false, config[:properties]['useSSL']
    end

    test 'configuration attempts to load MySQL driver by default' do
      connection_handler = connection_handler_stub

      config = { database: 'MyDB' }
      connection_handler.expects(:jdbc_connection)
      connection_handler.expects(:require).with('jdbc/mysql')
      connection_handler.mysql_connection config
    end

    test 'configuration allows to skip driver loading' do
      connection_handler = connection_handler_stub

      config = { database: 'MyDB', driver: false }
      connection_handler.expects(:jdbc_connection).with() { |c| config = c }
      connection_handler.expects(:require).never
      connection_handler.mysql_connection config
      assert_not config[:driver] # allow Java's service discovery mechanism (with connector/j 8.0)
    end

    test 'configuration works with MariaDB driver specified' do
      connection_handler = connection_handler_stub

      config = { database: 'MyDB', driver: 'org.mariadb.jdbc.Driver' }
      connection_handler.expects(:jdbc_connection).with() { |c| config = c }
      connection_handler.mysql_connection config

      # we do not complete username/database etc :
      assert_equal 'root', config[:username]
      assert_equal 'org.mariadb.jdbc.Driver', config[:driver]
      assert_equal 'jdbc:mysql://localhost/MyDB', config[:url]
      assert_equal false, config[:properties]['useLegacyDatetimeCode']
      assert_equal false, config[:properties]['useSsl']
    end

  end

  def load_jdbc_mysql
    require 'jdbc/mysql'
  rescue LoadError
    return nil
  end

end if defined? JRUBY_VERSION
