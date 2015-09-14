module ActiveRecord
  module ConnectionAdapters
    # I want to use JDBC's DatabaseMetaData#getTypeInfo to choose the best native types to
    # use for ActiveRecord's Adapter#native_database_types in a database-independent way,
    # but apparently a database driver can return multiple types for a given
    # java.sql.Types constant.  So this type converter uses some heuristics to try to pick
    # the best (most common) type to use.  It's not great, it would be better to just
    # delegate to each database's existing AR adapter's native_database_types method, but I
    # wanted to try to do this in a way that didn't pull in all the other adapters as
    # dependencies. Improvements appreciated.
    class JdbcTypeConverter

      # @private
      TEXT_TYPES = [ Jdbc::Types::LONGVARCHAR, Jdbc::Types::CLOB ]
      private_constant :TEXT_TYPES if respond_to? :private_constant

      # @private
      FLOAT_TYPES = [ Jdbc::Types::FLOAT, Jdbc::Types::DOUBLE, Jdbc::Types::REAL ]
      private_constant :FLOAT_TYPES if respond_to? :private_constant

      # @private
      BINARY_TYPES = [ Jdbc::Types::LONGVARBINARY,Jdbc::Types::BINARY,Jdbc::Types::BLOB ]
      private_constant :BINARY_TYPES if respond_to? :private_constant

      # The basic ActiveRecord types, mapped to an array of procs that are used to #select
      # the best type.  The procs are used as selectors in order until there is only one
      # type left.  If all the selectors are applied and there is still more than one
      # type, an exception will be raised.
      AR_TO_JDBC_TYPES = {
        :string      => [ lambda {|r| Jdbc::Types::VARCHAR == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^varchar/i},
                          lambda {|r| r['type_name'] =~ /^varchar$/i},
                          lambda {|r| r['type_name'] =~ /varying/i}],
        :text        => [ lambda {|r| TEXT_TYPES.include?(r['data_type'].to_i)},
                          lambda {|r| r['type_name'] =~ /^text$/i},     # For Informix
                          lambda {|r| r['type_name'] =~ /sub_type 1$/i}, # For FireBird
                          lambda {|r| r['type_name'] =~ /^(text|clob)$/i},
                          lambda {|r| r['type_name'] =~ /^character large object$/i},
                          lambda {|r| r['sql_data_type'] == 2005}],
        :integer     => [ lambda {|r| Jdbc::Types::INTEGER == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^integer$/i},
                          lambda {|r| r['type_name'] =~ /^int4$/i},
                          lambda {|r| r['type_name'] =~ /^int$/i}],
        :decimal     => [ lambda {|r| Jdbc::Types::DECIMAL == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^decimal$/i},
                          lambda {|r| r['type_name'] =~ /^numeric$/i},
                          lambda {|r| r['type_name'] =~ /^number$/i},
                          lambda {|r| r['type_name'] =~ /^real$/i},
                          lambda {|r| r['precision'] == '38'},
                          lambda {|r| r['data_type'].to_i == Jdbc::Types::DECIMAL}],
        :float       => [ lambda {|r| FLOAT_TYPES.include?(r['data_type'].to_i)},
                          lambda {|r| r['data_type'].to_i == Jdbc::Types::REAL}, #Prefer REAL to DOUBLE for Postgresql
                          lambda {|r| r['type_name'] =~ /^float/i},
                          lambda {|r| r['type_name'] =~ /^double$/i},
                          lambda {|r| r['type_name'] =~ /^real$/i},
                          lambda {|r| r['precision'] == '15'}],
        :datetime    => [ lambda {|r| Jdbc::Types::TIMESTAMP == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^datetime$/i},
                          lambda {|r| r['type_name'] =~ /^timestamp$/i},
                          lambda {|r| r['type_name'] =~ /^datetime.+/i},
                          lambda {|r| r['type_name'] =~ /^date/i},
                          lambda {|r| r['type_name'] =~ /^integer/i}],  #Num of milliseconds for SQLite3 JDBC Driver
        :timestamp   => [ lambda {|r| Jdbc::Types::TIMESTAMP == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^timestamp$/i},
                          lambda {|r| r['type_name'] =~ /^datetime$/i},
                          lambda {|r| r['type_name'] =~ /^datetime.+/i},
                          lambda {|r| r['type_name'] =~ /^date/i},
                          lambda {|r| r['type_name'] =~ /^integer/i}],  #Num of milliseconds for SQLite3 JDBC Driver
        :time        => [ lambda {|r| Jdbc::Types::TIME == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^time$/i},
                          lambda {|r| r['type_name'] =~ /^datetime$/i},
                          lambda {|r| r['type_name'] =~ /^datetime.+/i},  # For Informix
                          lambda {|r| r['type_name'] =~ /^date/i},
                          lambda {|r| r['type_name'] =~ /^integer/i}],  #Num of milliseconds for SQLite3 JDBC Driver
        :date        => [ lambda {|r| Jdbc::Types::DATE == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^date$/i},
                          lambda {|r| r['type_name'] =~ /^date/i},
                          lambda {|r| r['type_name'] =~ /^integer/i}],  #Num of milliseconds for SQLite3 JDBC Driver3
        :binary      => [ lambda {|r| BINARY_TYPES.include?(r['data_type'].to_i)},
                          lambda {|r| r['type_name'] =~ /^blob/i},
                          lambda {|r| r['type_name'] =~ /sub_type 0$/i}, # For FireBird
                          lambda {|r| r['type_name'] =~ /^varbinary$/i}, # We want this sucker for Mimer
                          lambda {|r| r['type_name'] =~ /^binary$/i}, ],
        :boolean     => [ lambda {|r| Jdbc::Types::BIT == r['data_type'].to_i && r['precision'].to_i == 1},
                          lambda {|r| Jdbc::Types::TINYINT == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^bool/i},
                          lambda {|r| r['data_type'].to_i == Jdbc::Types::BIT},
                          lambda {|r| r['type_name'] =~ /^tinyint$/i},
                          lambda {|r| r['type_name'] =~ /^decimal$/i},
                          lambda {|r| r['type_name'] =~ /^integer$/i}]
      }

      def initialize(types)
        @types = types
        @types.each {|t| t['type_name'] ||= t['local_type_name']} # Sybase driver seems to want 'local_type_name'
      end

      def choose_best_types
        type_map = {}
        @types.each do |row|
          name = row['type_name'].downcase
          k = name.to_sym
          type_map[k] = { :name => name }
          set_limit_to_nonzero_precision(type_map[k], row)
        end

        AR_TO_JDBC_TYPES.keys.each do |ar_type|
          typerow = choose_type(ar_type)
          type_map[ar_type] = { :name => typerow['type_name'].downcase }
          case ar_type
          when :integer, :string, :decimal
            set_limit_to_nonzero_precision(type_map[ar_type], typerow)
          when :boolean
            type_map[ar_type][:limit] = 1
          end
        end
        type_map
      end

      def choose_type(ar_type)
        types = @types
        AR_TO_JDBC_TYPES[ar_type].each do |proc|
          new_types = types.reject {|r| r["data_type"].to_i == Jdbc::Types::OTHER}
          new_types = new_types.select(&proc)
          new_types = new_types.inject([]) do |typs,t|
            typs << t unless typs.detect {|el| el['type_name'] == t['type_name']}
            typs
          end
          return new_types.first if new_types.length == 1
          types = new_types if new_types.length > 0
        end
        raise "unable to choose type for #{ar_type} from:\n#{types.collect{|t| t['type_name']}.inspect}"
      end

      def set_limit_to_nonzero_precision(map, row)
        if row['precision'] && row['precision'].to_i > 0
          map[:limit] = row['precision'].to_i
        end
      end
    end
  end
end
