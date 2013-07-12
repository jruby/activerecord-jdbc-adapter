require 'java'
require 'arjdbc/jdbc/adapter_java'

module ActiveRecord
  module ConnectionAdapters
    module Jdbc
      # @private
      DriverManager = ::Java::JavaSql::DriverManager
      # @private
      Types = ::Java::JavaSql::Types
    end
    # @private JdbcConnectionFactory
    java_import "arjdbc.jdbc.JdbcConnectionFactory"
  end
end