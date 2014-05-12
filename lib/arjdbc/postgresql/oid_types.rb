require 'active_record/connection_adapters/postgresql/oid'

module ArJdbc
  module PostgreSQL
    module OIDTypes

      OID = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::OID

      private

      def type_map
        # NOTE: our type_map is lazy since it's only used for `adapter.accessor`
        @type_map ||= begin
          type_map = OID::TypeMap.new
          initialize_type_map(type_map)
          type_map
        end
      end

      def reload_type_map
        if ( @type_map ||= nil )
          @type_map.clear
          initialize_type_map(@type_map)
        end
      end

      def get_oid_type(oid, fmod, column_name)
        type_map.fetch(oid, fmod) {
          warn "unknown OID #{oid}: failed to recognize type of '#{column_name}'. It will be treated as String."
          type_map[oid] = OID::Identity.new
        }
      end

      def add_oid(row, records_by_oid, type_map)
        return type_map if type_map.key? row['type_elem'].to_i

        if OID.registered_type? row['typname']
          # this composite type is explicitly registered
          vector = OID::NAMES[row['typname']]
        else
          # use the default for composite types
          unless type_map.key? row['typelem'].to_i
            add_oid records_by_oid[row['typelem']], records_by_oid, type_map
          end

          vector = OID::Vector.new row['typdelim'], type_map[row['typelem'].to_i]
        end

        type_map[row['oid'].to_i] = vector
        type_map
      end

      def initialize_type_map(type_map)
        result = execute('SELECT oid, typname, typelem, typdelim, typinput FROM pg_type', 'SCHEMA')
        leaves, nodes = result.partition { |row| row['typelem'] == '0' }

        # populate the leaf nodes
        leaves.find_all { |row| OID.registered_type? row['typname'] }.each do |row|
          type_map[row['oid'].to_i] = OID::NAMES[row['typname']]
        end

        records_by_oid = result.group_by { |row| row['oid'] }

        arrays, nodes = nodes.partition { |row| row['typinput'] == 'array_in' }

        # populate composite types
        nodes.each do |row|
          add_oid row, records_by_oid, type_map
        end

        # populate array types
        arrays.find_all { |row| type_map.key? row['typelem'].to_i }.each do |row|
          array = OID::Array.new  type_map[row['typelem'].to_i]
          type_map[row['oid'].to_i] = array
        end
      end

    end
  end
end