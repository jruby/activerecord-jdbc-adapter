module ActiveRecord
  module ConnectionAdapters
    class JdbcColumn < Column
      attr_writer :limit, :precision

      def initialize(config, name, default, *args)
        call_discovered_column_callbacks(config)
        super(name,default_value(default),*args)
        init_column(name, default, *args)
      end

      def init_column(*args)
      end

      def default_value(val)
        val
      end

      protected

      def call_discovered_column_callbacks(config)
        dialect = (config[:dialect] || config[:driver]).to_s
        for matcher, block in self.class.column_types
          block.call(config, self) if matcher === dialect
        end
      end

      public

      def self.column_types
        # reset the column types if the # of constants changed since last call
        @column_types ||= begin 
          types = driver_constants.select { |c| c.respond_to? :column_selector }
          types.map! { |c| c.column_selector }
          types.inject({}) { |h, val| h[ val[0] ] = val[1]; h }
        end
      end

      def self.driver_constants
        reset_constants
        @driver_constants ||= ::ArJdbc.constants.map { |c| ::ArJdbc.const_get c }
      end

      def self.reset_constants!
        @driver_constants = nil; @column_types = nil
      end
      
      def self.reset_constants
        return unless @driver_constants
        reset_constants! if ::ArJdbc.constants.size != @driver_constants.size
      end
      
    end
  end
end
