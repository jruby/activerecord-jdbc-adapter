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
  end
end
