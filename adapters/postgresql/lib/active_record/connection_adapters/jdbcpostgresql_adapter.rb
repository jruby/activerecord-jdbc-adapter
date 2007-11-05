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
  require "jdbc/postgres"
rescue LoadError
  raise if tried_gem
  require 'rubygems'
  gem "jdbc-postgres"
  tried_gem = true
  retry
end

require 'active_record/connection_adapters/jdbc_adapter'

module ActiveRecord
  class Base
    class << self
      alias_method :jdbcpostgresql_connection, :postgresql_connection
    end
  end
end