tried_gem = false
begin
  require "jdbc/derby"
rescue LoadError
  unless tried_gem
    require 'rubygems'
    gem "jdbc-derby"
    tried_gem = true
    retry
  end
  # trust that the derby jar is already present
end

require 'arjdbc/jdbc'

module ActiveRecord
  class Base
    class << self
      alias_method :jdbcderby_connection, :derby_connection
    end
  end
end
