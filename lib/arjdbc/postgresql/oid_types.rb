require 'arjdbc/postgresql/base/oid' # 'active_record/connection_adapters/postgresql/oid'
require 'thread'

module ArJdbc
  module PostgreSQL
    # @private
    module OIDTypes

      OID = ActiveRecord::ConnectionAdapters::PostgreSQL::OID
      Type = ActiveRecord::Type if ActiveRecord::VERSION.to_s >= '4.2'

      def get_oid_type(oid, fmod, column_name)
        type_map.fetch(oid, fmod) {
          warn "unknown OID #{oid}: failed to recognize type of '#{column_name}'. It will be treated as String."
          type_map[oid] = OID::Identity.new
        }
      end

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

      private

      @@type_map_cache = {}
      @@type_map_cache_lock = Mutex.new

      # @private
      class OID::TypeMap
        def dup
          dup = super # make sure @mapping is not shared
          dup.instance_variable_set(:@mapping, @mapping.dup)
          dup
        end
      end

      def type_map
        # NOTE: our type_map is lazy since it's only used for `adapter.accessor`
        @type_map ||= begin
          if type_map = @@type_map_cache[ type_cache_key ]
            type_map.dup
          else
            type_map = OID::TypeMap.new
            initialize_type_map(type_map)
            cache_type_map(type_map)
            type_map
          end
        end
      end

      def reload_type_map
        if ( @type_map ||= nil )
          @type_map.clear
          initialize_type_map(@type_map)
        end
      end

      def cache_type_map(type_map)
        @@type_map_cache_lock.synchronize do
          @@type_map_cache[ type_cache_key ] = type_map
        end
      end

      def type_cache_key
        config.hash + ( 7 * extensions.hash )
      end

      def add_oid(row, records_by_oid, type_map)
        return type_map if type_map.key? row['type_elem'].to_i

        if OID.registered_type? typname = row['typname']
          # this composite type is explicitly registered
          vector = OID::NAMES[ typname ]
        else
          # use the default for composite types
          unless type_map.key? typelem = row['typelem'].to_i
            add_oid records_by_oid[ row['typelem'] ], records_by_oid, type_map
          end

          vector = OID::Vector.new row['typdelim'], type_map[typelem]
        end

        type_map[ row['oid'].to_i ] = vector
        type_map
      end

      def initialize_type_map(type_map)
        result = execute('SELECT oid, typname, typelem, typdelim, typinput FROM pg_type', 'SCHEMA')
        leaves, nodes = result.partition { |row| row['typelem'].to_s == '0' }
        # populate the leaf nodes
        leaves.find_all { |row| OID.registered_type? row['typname'] }.each do |row|
          type_map[ row['oid'].to_i ] = OID::NAMES[ row['typname'] ]
        end

        records_by_oid = result.group_by { |row| row['oid'] }

        arrays, nodes = nodes.partition { |row| row['typinput'] == 'array_in' }

        # populate composite types
        nodes.each { |row| add_oid row, records_by_oid, type_map }

        # populate array types
        arrays.find_all { |row| type_map.key? row['typelem'].to_i }.each do |row|
          array = OID::Array.new  type_map[ row['typelem'].to_i ]
          type_map[ row['oid'].to_i ] = array
        end
      end

      def initialize_type_map(m)
        register_class_with_limit m, 'int2', OID::Integer
        m.alias_type 'int4', 'int2'
        m.alias_type 'int8', 'int2'
        m.alias_type 'oid', 'int2'
        m.register_type 'float4', OID::Float.new
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
        m.register_type 'time', OID::Time.new

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
        m.register_type 'tsvector', OID::SpecializedString.new(:tsvector)
        m.register_type 'macaddr', OID::SpecializedString.new(:macaddr)
        m.register_type 'citext', OID::SpecializedString.new(:citext)
        m.register_type 'ltree', OID::SpecializedString.new(:ltree)

        # FIXME: why are we keeping these types as strings?
        m.alias_type 'interval', 'varchar'
        m.alias_type 'path', 'varchar'
        m.alias_type 'line', 'varchar'
        m.alias_type 'polygon', 'varchar'
        m.alias_type 'circle', 'varchar'
        m.alias_type 'lseg', 'varchar'
        m.alias_type 'box', 'varchar'

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
      end if ActiveRecord::VERSION.to_s >= '4.2'

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

        if oids
          query += "WHERE t.oid::integer IN (%s)" % oids.join(", ")
        end

        initializer = OID::TypeMapInitializer.new(type_map)
        records = execute(query, 'SCHEMA')
        initializer.run(records)
      end if ActiveRecord::VERSION.to_s >= '4.2'
    end
  end
end