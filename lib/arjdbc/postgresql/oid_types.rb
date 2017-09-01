require 'thread'

module ArJdbc
  module PostgreSQL

    require 'active_record/connection_adapters/postgresql/oid'
    require 'arjdbc/postgresql/base/pgconn'

    def self.unescape_bytea(escaped)
      String.from_java_bytes Java::OrgPostgresqlUtil::PGbytea.toBytes escaped.to_java_bytes
    end

    # @private
    OID = ::ActiveRecord::ConnectionAdapters::PostgreSQL::OID

    # @private
    module OIDTypes

      # Support arrays/ranges for defining attributes that don't exist in the db
      Type.add_modifier({ array: true }, OID::Array, adapter: :postgresql)
      Type.add_modifier({ range: true }, OID::Range, adapter: :postgresql)

      # @override
      def enable_extension(name)
        result = super(name)
        @extensions = nil
        reload_type_map
        result
      end

      # @override
      def disable_extension(name)
        result = super(name)
        @extensions = nil
        reload_type_map
        result
      end

      # @override
      def extensions
        @extensions ||= super
      end

      # @override
      def lookup_cast_type(sql_type)
        oid = execute("SELECT #{quote(sql_type)}::regtype::oid", "SCHEMA")
        super oid.first['oid'].to_i
      end

      def get_oid_type(oid, fmod, column_name, sql_type = '')
        if !type_map.key?(oid)
          load_additional_types(type_map, [oid])
        end

        type_map.fetch(oid, fmod, sql_type) {
          warn "unknown OID #{oid}: failed to recognize type of '#{column_name}'. It will be treated as String."
          Type::Value.new.tap do |cast_type|
            type_map.register_type(oid, cast_type)
          end
        }
      end

      def type_map
        @type_map
      end

      def reload_type_map
        if ( @type_map ||= nil )
          @type_map.clear
          initialize_type_map(@type_map)
        end
      end

      private

      def initialize_type_map(m)
        register_class_with_limit m, 'int2', Type::Integer
        register_class_with_limit m, 'int4', Type::Integer
        register_class_with_limit m, 'int8', Type::Integer
        m.alias_type 'oid', 'int2'
        m.register_type 'float4', Type::Float.new
        m.alias_type 'float8', 'float4'
        m.register_type 'text', Type::Text.new
        register_class_with_limit m, 'varchar', Type::String
        m.alias_type 'char', 'varchar'
        m.alias_type 'name', 'varchar'
        m.alias_type 'bpchar', 'varchar'
        m.register_type 'bool', Type::Boolean.new
        register_class_with_limit m, 'bit', OID::Bit
        register_class_with_limit m, 'varbit', OID::BitVarying
        m.alias_type 'timestamptz', 'timestamp'
        m.register_type 'date', Type::Date.new
        m.register_type 'time', Type::Time.new

        m.register_type 'money', OID::Money.new
        m.register_type 'bytea', OID::Bytea.new
        m.register_type 'point', OID::Point.new
        m.register_type 'hstore', OID::Hstore.new
        m.register_type 'json', OID::Json.new
        m.register_type 'jsonb', OID::Jsonb.new
        m.register_type 'cidr', OID::Cidr.new
        m.register_type 'inet', OID::Inet.new
        m.register_type 'uuid', OID::Uuid.new
        m.register_type 'xml', OID::Xml.new
        m.register_type 'box', OID::SpecializedString.new(:box)
        m.register_type 'circle', OID::SpecializedString.new(:circle)
        m.register_type 'citext', OID::SpecializedString.new(:citext)
        m.register_type 'line', OID::SpecializedString.new(:line)
        m.register_type 'lseg', OID::SpecializedString.new(:lseg)
        m.register_type 'ltree', OID::SpecializedString.new(:ltree)
        m.register_type 'macaddr', OID::SpecializedString.new(:macaddr)
        m.register_type 'path', OID::SpecializedString.new(:path)
        m.register_type 'polygon', OID::SpecializedString.new(:polygon)
        m.register_type 'tsvector', OID::SpecializedString.new(:tsvector)

        # This is how Rails 5.1 handles it. In 5.0 SpecializedString doesn't take a precision option
        # 5.0 actually leaves it as a regular String but we need it specialized
        # to support prepared statements
        # m.register_type 'interval' do |_, _, sql_type|
        #   precision = extract_precision(sql_type)
        #   OID::SpecializedString.new(:interval, precision: precision)
        # end
        m.register_type 'interval', OID::SpecializedString.new(:interval)

        m.register_type 'timestamp' do |_, _, sql_type|
          precision = extract_precision(sql_type)
          OID::DateTime.new(precision: precision)
        end

        m.register_type 'numeric' do |_, fmod, sql_type|
          precision = extract_precision(sql_type)
          scale = extract_scale(sql_type)

          # The type for the numeric depends on the width of the field,
          # so we'll do something special here.
          #
          # When dealing with decimal columns:
          #
          # places after decimal  = fmod - 4 & 0xffff
          # places before decimal = (fmod - 4) >> 16 & 0xffff
          if fmod && (fmod - 4 & 0xffff).zero?
            # FIXME: Remove this class, and the second argument to
            # lookups on PG
            Type::DecimalWithoutScale.new(precision: precision)
          else
            OID::Decimal.new(precision: precision, scale: scale)
          end
        end

        load_additional_types(m)
      end

      def load_additional_types(type_map, oids = nil)
        if supports_ranges?
          query = <<-SQL
            SELECT t.oid, t.typname, t.typelem, t.typdelim, t.typinput, r.rngsubtype, t.typtype, t.typbasetype
            FROM pg_type as t
            LEFT JOIN pg_range as r ON oid = rngtypid
          SQL
        else
          query = <<-SQL
            SELECT t.oid, t.typname, t.typelem, t.typdelim, t.typinput, t.typtype, t.typbasetype
            FROM pg_type as t
          SQL
        end

        initializer = OID::TypeMapInitializer.new(type_map)

        if oids
          query << ( "WHERE t.oid::integer IN (%s)" % oids.join(", ") )
        else
          # query_conditions_for_initial_load only available since AR > 4.2.1
          if initializer.respond_to?(:query_conditions_for_initial_load)
            query << initializer.query_conditions_for_initial_load(type_map)
          end
        end

        records = execute(query, 'SCHEMA')
        initializer.run(records)
      end

    end
  end
end
