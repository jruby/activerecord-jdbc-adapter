module ActiveRecord
  module ConnectionAdapters
    class JdbcColumn < Column
      attr_writer :limit, :precision

      def initialize(config, name, *args)
        if self.class == JdbcColumn
          # NOTE: extending classes do not want this if they do they shall call
          call_discovered_column_callbacks(config) if config
          default = args.shift
        else # for extending classes allow ignoring first argument :
          if ! config.nil? && ! config.is_a?(Hash)
            # initialize(name, default, *args)
            default = name; name = config
          else
            default = args.shift
          end
        end
        # super : (name, default, sql_type = nil, null = true)
        super(name, default_value(default), *args)
        init_column(name, default, *args)
      end

      def init_column(*args); end

      # NOTE: our custom #extract_value_from_default(default)
      def default_value(value); value; end

      protected

      def call_discovered_column_callbacks(config)
        dialect = (config[:dialect] || config[:driver]).to_s
        for matcher, block in self.class.column_types
          block.call(config, self) if matcher === dialect
        end
      end

      public
      
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
      
    end
  end
end
