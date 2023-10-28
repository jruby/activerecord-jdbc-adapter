# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Jdbc
      autoload :TypeCast, 'arjdbc/jdbc/type_cast'
    end
    # The base class for all of {JdbcAdapter}'s returned columns.
    # Instances of {JdbcColumn} will get extended with "column-spec" modules
    # (similar to how {JdbcAdapter} gets spec modules in) if the adapter spec
    # module provided a `column_selector` (matcher) method for it's database
    # specific type.
    # @see JdbcAdapter#jdbc_column_class
    class JdbcColumn < Column

      # Similar to `ActiveRecord`'s `extract_value_from_default(default)`.
      # @return default value for a column (possibly extracted from driver value)
      def default_value(value); value; end

      # Returns the available column types
      # @return [Hash] of (matcher, block) pairs
      def self.column_types
        types = {}
        for mod in ::ArJdbc.modules
          if mod.respond_to?(:column_selector)
            sel = mod.column_selector # [ matcher, block ]
            types[ sel[0] ] = sel[1]
          end
        end
        types
      end

      class << self
        include Jdbc::TypeCast
      end
    end
  end
end
