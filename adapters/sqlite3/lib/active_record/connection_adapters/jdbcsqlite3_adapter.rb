tried_gem = false
begin
  require "jdbc_adapter"
rescue LoadError
  raise if tried_gem
  require 'rubygems'
  gem "activerecord-jdbc-adapter"
  tried_gem = true
  retry
end
tried_gem = false
begin
  require "jdbc/sqlite3"
rescue LoadError
  raise if tried_gem
  require 'rubygems'
  gem "jdbc-sqlite3"
  tried_gem = true
  retry
end

require 'active_record/connection_adapters/jdbc_adapter'

module ActiveRecord
  class Base
    class << self
      alias_method :jdbcsqlite3_connection, :sqlite3_connection
    end
  end
end