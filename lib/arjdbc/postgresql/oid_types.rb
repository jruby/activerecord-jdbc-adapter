# frozen_string_literal: true

require 'thread'

module ArJdbc
  module PostgreSQL

    require 'active_record/connection_adapters/postgresql/oid'
    require 'arjdbc/postgresql/base/pgconn'

    # @private
    OID = ::ActiveRecord::ConnectionAdapters::PostgreSQL::OID

    # this version makes sure to register the types by name as well
    # we still need to version with OID since it's used from SchemaStatements as well
    class ArjdbcTypeMapInitializer < OID::TypeMapInitializer
      private

      def name_with_ns(row)
        if row['in_ns']
          row['typname']
        else
          %Q("#{row['nspname']}"."#{row['typname']}")
        end
      end

      def register_enum_type(row)
        super
        register name_with_ns(row), OID::Enum.new
      end

      def register_array_type(row)
        super
        register_with_subtype(name_with_ns(row), row['typelem'].to_i) do |subtype|
          OID::Array.new(subtype, row['typdelim'])
        end
      end

      def register_range_type(row)
        super
        name = name_with_ns(row)
        register_with_subtype(name, row['rngsubtype'].to_i) do |subtype|
          OID::Range.new(subtype, name.to_sym)
        end
      end

      def register_domain_type(row)
        if base_type = @store.lookup(row['typbasetype'].to_i)
          register row['oid'], base_type
          register name_with_ns(row), base_type
        else
          warn "unknown base type (OID: #{row['typbasetype']}) for domain #{row['typname']}."
        end
      end

      def register_composite_type(row)
        if subtype = @store.lookup(row['typelem'].to_i)
          register row['oid'], OID::Vector.new(row['typdelim'], subtype)
          register name_with_ns(row), OID::Vector.new(row['typdelim'], subtype)
        end
      end

      def assert_valid_registration(oid, oid_type)
        ret = super
        ret == 0 ? oid : ret
      end
    end

    # @private
    module OIDTypes

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

      def get_oid_type(oid, fmod, column_name, sql_type = '') # :nodoc:
        if !type_map.key?(oid)
          load_additional_types(type_map, oid)
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

      def initialize_type_map(m = type_map)
        register_class_with_limit m, 'int2', Type::Integer
        register_class_with_limit m, 'int4', Type::Integer
        register_class_with_limit m, 'int8', Type::Integer
        m.register_type 'oid', OID::Oid.new
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
        m.register_type 'date', OID::Date.new

        m.register_type 'money', OID::Money.new
        m.register_type 'bytea', OID::Bytea.new
        m.register_type 'point', OID::Point.new
        m.register_type 'hstore', OID::Hstore.new
        m.register_type 'json', Type::Json.new
        m.register_type 'jsonb', OID::Jsonb.new
        m.register_type 'cidr', OID::Cidr.new
        m.register_type 'inet', OID::Inet.new
        m.register_type 'uuid', OID::Uuid.new
        m.register_type 'xml', OID::Xml.new
        m.register_type 'tsvector', OID::SpecializedString.new(:tsvector)
        m.register_type 'macaddr', OID::SpecializedString.new(:macaddr)
        m.register_type 'citext', OID::SpecializedString.new(:citext)
        m.register_type 'ltree', OID::SpecializedString.new(:ltree)
        m.register_type 'line', OID::SpecializedString.new(:line)
        m.register_type 'lseg', OID::SpecializedString.new(:lseg)
        m.register_type 'box', OID::SpecializedString.new(:box)
        m.register_type 'path', OID::SpecializedString.new(:path)
        m.register_type 'polygon', OID::SpecializedString.new(:polygon)
        m.register_type 'circle', OID::SpecializedString.new(:circle)

        m.register_type 'interval' do |_, _, sql_type|
          precision = extract_precision(sql_type)
          OID::SpecializedString.new(:interval, precision: precision)
        end

        register_class_with_precision m, 'time', Type::Time
        register_class_with_precision m, 'timestamp', OID::DateTime

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

        # pgjdbc returns these if the column is auto-incrmenting
        m.alias_type 'serial', 'int4'
        m.alias_type 'bigserial', 'int8'
      end

      def load_additional_types(type_map, oid = nil) # :nodoc:
        initializer = ArjdbcTypeMapInitializer.new(type_map)

        if supports_ranges?
          query = <<-SQL
              SELECT t.oid, t.typname, t.typelem, t.typdelim, t.typinput, r.rngsubtype, t.typtype, t.typbasetype,
                ns.nspname, ns.nspname = ANY(current_schemas(true)) in_ns
              FROM pg_type as t
              LEFT JOIN pg_range as r ON oid = rngtypid
              JOIN pg_namespace AS ns ON t.typnamespace = ns.oid
          SQL
        else
          query = <<-SQL
              SELECT t.oid, t.typname, t.typelem, t.typdelim, t.typinput, t.typtype, t.typbasetype,
                ns.nspname, ns.nspname = ANY(current_schemas(true)) in_ns
              FROM pg_type as t
              JOIN pg_namespace AS ns ON t.typnamespace = ns.oid
          SQL
        end

        if oid
          if oid.is_a? Numeric || oid.match(/^\d+$/)
            # numeric OID
            query += "WHERE t.oid = %s" % oid

          elsif m = oid.match(/"?(\w+)"?\."?(\w+)"?/)
            # namespace and type name
            query += "WHERE ns.nspname = '%s' AND t.typname = '%s'" % [m[1], m[2]]

          else
            # only type name
            query += "WHERE t.typname = '%s' AND ns.nspname = ANY(current_schemas(true))" % oid
          end
        else
          query += initializer.query_conditions_for_initial_load
        end

        records = execute(query, 'SCHEMA')
        initializer.run(records)
      end

      # Support arrays/ranges for defining attributes that don't exist in the db
      ActiveRecord::Type.add_modifier({ array: true }, OID::Array, adapter: :postgresql)
      ActiveRecord::Type.add_modifier({ range: true }, OID::Range, adapter: :postgresql)
      ActiveRecord::Type.register(:bit, OID::Bit, adapter: :postgresql)
      ActiveRecord::Type.register(:bit_varying, OID::BitVarying, adapter: :postgresql)
      ActiveRecord::Type.register(:binary, OID::Bytea, adapter: :postgresql)
      ActiveRecord::Type.register(:cidr, OID::Cidr, adapter: :postgresql)
      ActiveRecord::Type.register(:date, OID::Date, adapter: :postgresql)
      ActiveRecord::Type.register(:datetime, OID::DateTime, adapter: :postgresql)
      ActiveRecord::Type.register(:decimal, OID::Decimal, adapter: :postgresql)
      ActiveRecord::Type.register(:enum, OID::Enum, adapter: :postgresql)
      ActiveRecord::Type.register(:hstore, OID::Hstore, adapter: :postgresql)
      ActiveRecord::Type.register(:inet, OID::Inet, adapter: :postgresql)
      ActiveRecord::Type.register(:json, Type::Json, adapter: :postgresql)
      ActiveRecord::Type.register(:jsonb, OID::Jsonb, adapter: :postgresql)
      ActiveRecord::Type.register(:money, OID::Money, adapter: :postgresql)
      ActiveRecord::Type.register(:point, OID::Point, adapter: :postgresql)
      ActiveRecord::Type.register(:legacy_point, OID::LegacyPoint, adapter: :postgresql)
      ActiveRecord::Type.register(:uuid, OID::Uuid, adapter: :postgresql)
      ActiveRecord::Type.register(:vector, OID::Vector, adapter: :postgresql)
      ActiveRecord::Type.register(:xml, OID::Xml, adapter: :postgresql)

    end
  end
end
