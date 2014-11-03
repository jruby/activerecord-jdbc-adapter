require 'arjdbc/postgresql/base/oid' # 'active_record/connection_adapters/postgresql/oid'
require 'thread'

module ArJdbc
  module PostgreSQL
    # @private
    module OIDTypes

      OID = ActiveRecord::ConnectionAdapters::PostgreSQL::OID

      def get_oid_type(oid, fmod, column_name)
        type_map.fetch(oid, fmod) {
          ArJdbc.warn("unknown OID #{oid}: failed to recognize type of '#{column_name}', will be treated as String.", true)
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

    end
  end
end