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

      # Shared cache of the (expensive) pg_type catalog query results, keyed by
      # server identity. Lets new connections build their own (isolated) OID type
      # map without re-running the catalog sweep against the database — the
      # adapter-side complement to the driver's shared metadata cache.
      # See docs/lazy-connection-remediation.md (A2).
      @type_records_cache = {}
      @type_records_mutex = Mutex.new

      class << self
        # Cached catalog row-sets for +key+, or nil. Reads happen under the
        # mutex; the (expensive) catalog queries that produce the rows run
        # OUTSIDE the lock in the caller, so a slow query can't block other
        # connections or deadlock if loading re-enters.
        def get_type_records(key)
          return nil if key.nil?
          @type_records_mutex.synchronize { @type_records_cache[key] }
        end

        # Cache +records+ for +key+ (first writer wins). A brief cold-start
        # window may run the sweep more than once; it converges immediately.
        # The structure is deep-frozen so the shared copy is provably immutable:
        # any number of threads may read it concurrently and #run only ever reads
        # (it rejects/extracts into fresh arrays), so no lock is needed on reads.
        def store_type_records(key, records)
          return if key.nil?
          records.each { |set| set.each(&:freeze).freeze }.freeze
          @type_records_mutex.synchronize { @type_records_cache[key] ||= records }
        end

        # Invalidate the shared rows for +key+ (or all keys) so the next full
        # load re-queries the catalog — used when types change (extensions/enums).
        def clear_type_records_cache(key = nil)
          @type_records_mutex.synchronize do
            key ? @type_records_cache.delete(key) : @type_records_cache.clear
          end
        end
      end

      def get_oid_type(oid, fmod, column_name, sql_type = '') # :nodoc:
        # Note: type_map is storing a bunch of oid type prefixed with a namespace even
        # if they are not namespaced (e.g. ""."oidvector").  builtin types which are
        # common seem to not be prefixed (e.g. "varchar").  OID numbers are also keys
        # but JDBC never returns those.  So the current scheme is to check with
        # what we got and that covers number and plain strings and otherwise we will
        # wrap with the namespace form.
        found = type_map.key?(oid)

        if !found
          key = oid.kind_of?(String) && oid != "oid" ? "\"\".\"#{oid}\"" : oid
          found = type_map.key?(key)

          if !found
            load_additional_types([oid])
          else
            oid = key
          end
        end

        type_map.fetch(oid, fmod, sql_type) {
          warn "unknown OID #{oid}: failed to recognize type of '#{column_name}'. It will be treated as String."
          Type::Value.new.tap do |cast_type|
            type_map.register_type(oid, cast_type)
          end
        }
      end

      def reload_type_map
        @lock.synchronize do
          # Drop the shared catalog rows for this database so the next full load
          # re-queries the catalog (types may have changed: extensions/enums).
          OIDTypes.clear_type_records_cache(oid_cache_key)

          if @type_map
            type_map.clear
          else
            @type_map = Type::HashLookupTypeMap.new
          end

          initialize_type_map
        end
      end

        def initialize_type_map_inner(m)
          m.register_type "int2", Type::Integer.new(limit: 2)
          m.register_type "int4", Type::Integer.new(limit: 4)
          m.register_type "int8", Type::Integer.new(limit: 8)
          m.register_type "oid", OID::Oid.new
          m.register_type "float4", Type::Float.new(limit: 24)
          m.register_type "float8", Type::Float.new
          m.register_type "text", Type::Text.new
          register_class_with_limit m, "varchar", Type::String
          m.alias_type "char", "varchar"
          m.alias_type "name", "varchar"
          m.alias_type "bpchar", "varchar"
          m.register_type "bool", Type::Boolean.new
          register_class_with_limit m, "bit", OID::Bit
          register_class_with_limit m, "varbit", OID::BitVarying
          m.register_type "date", OID::Date.new

          m.register_type "money", OID::Money.new
          m.register_type "bytea", OID::Bytea.new
          m.register_type "point", OID::Point.new
          m.register_type "hstore", OID::Hstore.new
          m.register_type "json", Type::Json.new
          m.register_type "jsonb", OID::Jsonb.new
          m.register_type "cidr", OID::Cidr.new
          m.register_type "inet", OID::Inet.new
          m.register_type "uuid", OID::Uuid.new
          m.register_type "xml", OID::Xml.new
          m.register_type "tsvector", OID::SpecializedString.new(:tsvector)
          m.register_type "macaddr", OID::Macaddr.new
          m.register_type "citext", OID::SpecializedString.new(:citext)
          m.register_type "ltree", OID::SpecializedString.new(:ltree)
          m.register_type "line", OID::SpecializedString.new(:line)
          m.register_type "lseg", OID::SpecializedString.new(:lseg)
          m.register_type "box", OID::SpecializedString.new(:box)
          m.register_type "path", OID::SpecializedString.new(:path)
          m.register_type "polygon", OID::SpecializedString.new(:polygon)
          m.register_type "circle", OID::SpecializedString.new(:circle)
          m.register_type "regproc", OID::Enum.new
          # FIXME: adding this vector type leads to quoting not handlign Array data in quoting.
          #m.register_type "_int4", OID::Vector.new(",", m.lookup("int4"))
          register_class_with_precision m, "time", Type::Time
          register_class_with_precision m, "timestamp", OID::Timestamp
          register_class_with_precision m, "timestamptz", OID::TimestampWithTimeZone

          m.register_type "numeric" do |_, fmod, sql_type|
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

          m.register_type "interval" do |*args, sql_type|
            precision = extract_precision(sql_type)
            OID::Interval.new(precision: precision)
          end

          # pgjdbc returns these if the column is auto-incrmenting
          m.alias_type 'serial', 'int4'
          m.alias_type 'bigserial', 'int8'
        end


      # We differ from AR here because we will initialize type_map when adapter initializes
      def type_map
        @type_map
      end

      def initialize_type_map(m = type_map)
        initialize_type_map_inner(m)
        load_additional_types
      end

      private

      def register_class_with_limit(...)
        ::ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:register_class_with_limit, ...)
      end

      def register_class_with_precision(...)
        ::ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:register_class_with_precision, ...)
      end

      def load_additional_types(oids = nil) # :nodoc:
        initializer = ArjdbcTypeMapInitializer.new(type_map)

        if oids
          # Lazy single-OID lookups (an unknown type seen at query time) always
          # hit the catalog; they're rare and specific to the OID in question.
          load_types_queries(initializer, oids) do |query|
            execute_and_clear(query, "SCHEMA", []) do |records|
              initializer.run(records)
            end
          end
        else
          # Full load. Replay the shared catalog rows when available; otherwise
          # run the catalog queries once and cache the rows for other connections
          # to the same database. #run reads but never mutates the rows, so each
          # connection safely populates its own type_map from the shared copy.
          if (cached = OIDTypes.get_type_records(oid_cache_key))
            cached.each { |records| initializer.run(records) }
          else
            # The three catalog queries are built lazily: each WHERE..IN clause
            # depends on the types #run registered from the previous query, so we
            # must run() between yields (not after) — while capturing the rows.
            sets = []
            load_types_queries(initializer, nil) do |query|
              execute_and_clear(query, "SCHEMA", []) do |records|
                rows = records.to_a
                sets << rows
                initializer.run(rows)
              end
            end
            OIDTypes.store_type_records(oid_cache_key, sets)
          end
        end
      end

      # Identifies the database whose pg_type catalog a cached row-set describes.
      # pg_type lives in pg_catalog: its contents are per-database and independent
      # of search_path, so the cache is scoped by database NAME, qualified with
      # host/port to disambiguate same-named databases on different servers.
      #
      # The JDBC URL is included as a final component so url-only configs (where
      # the discrete :host/:port/:database keys may be absent) can never collide
      # two different databases onto a nil key. When :database isn't given
      # explicitly we recover it from the URL's path so the name still scopes it.
      def oid_cache_key
        database = @config[:database] || @config[:dbname] ||
                   @config[:url].to_s[%r{//[^/]*/([^?]+)}, 1]
        [@config[:host], @config[:port], database, @config[:url]]
      end

      def load_types_queries(initializer, oids)
        query = <<~SQL
            SELECT t.oid, t.typname, t.typelem, t.typdelim, t.typinput, r.rngsubtype, t.typtype, t.typbasetype
            FROM pg_type as t
            LEFT JOIN pg_range as r ON oid = rngtypid
        SQL
        if oids
          if oids.all? { |e| e.kind_of? Numeric }
            yield query + "WHERE t.oid IN (%s)" % oids.join(", ")
          else
            in_list = oids.map { |e| %Q{'#{e}'} }.join(", ")
            yield query + "WHERE t.typname IN (%s)" % in_list
          end
        else
          yield query + initializer.query_conditions_for_known_type_names
          yield query + initializer.query_conditions_for_known_type_types
          yield query + initializer.query_conditions_for_array_types
        end
      end

      def update_typemap_for_default_timezone
        if @default_timezone != ActiveRecord.default_timezone && @timestamp_decoder
          decoder_class = ActiveRecord.default_timezone == :utc ?
                            PG::TextDecoder::TimestampUtc :
                            PG::TextDecoder::TimestampWithoutTimeZone

          @timestamp_decoder = decoder_class.new(@timestamp_decoder.to_h)
          @connection.type_map_for_results.add_coder(@timestamp_decoder)

          @default_timezone = ActiveRecord.default_timezone

          # if default timezone has changed, we need to reconfigure the connection
          # (specifically, the session time zone)
          configure_connection
        end
      end

      def extract_scale(sql_type)
        case sql_type
        when /\((\d+)\)/ then 0
        when /\((\d+)(,(\d+))\)/ then $3.to_i
        end
      end

      def extract_precision(sql_type)
        $1.to_i if sql_type =~ /\((\d+)(,\d+)?\)/
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
      ActiveRecord::Type.register(:interval, OID::Interval, adapter: :postgresql)
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
