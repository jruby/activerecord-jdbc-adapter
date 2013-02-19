require 'test_helper'

class PostgresUnitTest < Test::Unit::TestCase

  test 'create_database (with options)' do
    connection = connection_stub
    connection.expects(:execute).with '' + 
      "CREATE DATABASE \"mega_development\" ENCODING='utf8' TABLESPACE = \"TS1\" OWNER = \"kimcom\""
    connection.create_database 'mega_development', 
      :tablespace => :'TS1', 'owner' => 'kimcom', :invalid => 'ignored'
  end
  
  test 'create_database (no options)' do
    connection = connection_stub
    connection.expects(:execute).with "CREATE DATABASE \"mega_development\" ENCODING='utf8'"
    connection.create_database 'mega_development'
  end
  
  private
  
  def connection_stub
    connection = mock('connection')
    (class << connection; self; end).class_eval do
      def self.alias_chained_method(*args); args; end
    end
    def connection.configure_connection; nil; end
    connection.extend ArJdbc::PostgreSQL
    connection
  end
  
end