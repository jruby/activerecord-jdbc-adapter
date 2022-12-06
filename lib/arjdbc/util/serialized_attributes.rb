# frozen_string_literal: true

module ArJdbc
  module Util
    # Gets included into `ActiveRecord::Base` to support sending LOB values
    # in a separate update SQL statement for DB adapters that need this.
    module SerializedAttributes

      # protected

      def update_lob_columns
        klass = self.class
        return unless type = klass.lob_type # e.g. /blob/i
        connection = klass.connection
        if connection.respond_to?(:update_lob_values?)
          return false unless connection.update_lob_values?
        end
        klass.columns.each do |column|
          next if column.sql_type !~ type
          next if ( value = dump_column_value(column) ).nil?
          if connection.respond_to?(:update_lob_value?)
            next unless connection.update_lob_value?(value, column)
          end
          connection.update_lob_value(self, column, value)
        end
      end

      private

      def dump_column_value(column)
        SerializedAttributes.dump_column_value(self, column)
      end

      def self.dump_column_value(record, column)
        value = record[ column.name.to_s ]
        column.cast_type.type_cast_for_database(value)
      end

      def self.setup(lob_type = nil, after_save_alias = nil)
        ActiveRecord::Base.send :include, self # include SerializedAttributes
        ActiveRecord::Base.lob_type = lob_type unless lob_type.nil?
        if after_save_alias
          ActiveRecord::Base.class_eval do
            alias_method after_save_alias, 'update_lob_columns'
          end
          ActiveRecord::Base.after_save after_save_alias
        else
          ActiveRecord::Base.after_save 'update_lob_columns'
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods

        def lob_type
          @lob_type ||= begin
            if superclass.respond_to?(:lob_type)
              superclass.lob_type
            else
              /blob|clob/i
            end
          end
        end

        def lob_type=(type)
          @lob_type = type
        end

      end

    end
  end
  # @private only due backwards compatibility
  SerializedAttributesHelper = Util::SerializedAttributes
end
