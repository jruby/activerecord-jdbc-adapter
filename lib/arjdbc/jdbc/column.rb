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
      attr_writer :limit, :precision

      def initialize(config, name, *args)
        if self.class == JdbcColumn
          # NOTE: extending classes do not want this if they do they shall call
          call_discovered_column_callbacks(config) if config
          default = args.shift
        else # for extending classes allow ignoring first argument :
          if ! config.nil? && ! config.is_a?(Hash)
            default = name; name = config # initialize(name, default, *args)
          else
            default = args.shift
          end
        end
        default = default_value(default)

        # FIXME(uwe): I would like to move #default_value() handling into ARJDBC
        #  subclasses of the corresponding ActiveRecord::Type subclasses
        #  "type_cast_from_database" should be called from RubyJdbcConnection
        default = args[0].type_cast_from_database(default) if ArJdbc::AR42
        # EMXIF

        # super <= 4.1: (name, default, sql_type = nil, null = true)
        # super >= 4.2: (name, default, cast_type, sql_type = nil, null = true)
        super(name, default, *args)
        init_column(name, default, *args)
      end

      # Additional column initialization for sub-classes.
      def init_column(*args); end

      # Similar to `ActiveRecord`'s `extract_value_from_default(default)`.
      # @return default value for a given column
      def default_value(value); value; end

      protected

      # @private
      def call_discovered_column_callbacks(config)
        dialect = (config[:dialect] || config[:driver]).to_s
        for matcher, block in self.class.column_types
          block.call(config, self) if matcher === dialect
        end
      end

      public

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

        include Jdbc::TypeCast if ::ActiveRecord::VERSION::STRING >= '4.2'

        if ActiveRecord::VERSION::MAJOR > 3 && ActiveRecord::VERSION::STRING < '4.2'

          # @private provides compatibility between AR 3.x/4.0 API
          def string_to_date(value); value_to_date(value) end

        end

      end

    end
  end
end
