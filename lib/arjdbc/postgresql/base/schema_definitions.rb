module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class ColumnDefinition < ActiveRecord::ConnectionAdapters::ColumnDefinition
        attr_accessor :array
        def array?; !!@array; end
      end

      module ColumnMethods
        def xml(*args)
          options = args.extract_options!
          column(args[0], 'xml', options)
        end

        def tsvector(*args)
          options = args.extract_options!
          column(args[0], 'tsvector', options)
        end

        def int4range(name, options = {})
          column(name, 'int4range', options)
        end

        def int8range(name, options = {})
          column(name, 'int8range', options)
        end

        def tsrange(name, options = {})
          column(name, 'tsrange', options)
        end

        def tstzrange(name, options = {})
          column(name, 'tstzrange', options)
        end

        def numrange(name, options = {})
          column(name, 'numrange', options)
        end

        def daterange(name, options = {})
          column(name, 'daterange', options)
        end

        def hstore(name, options = {})
          column(name, 'hstore', options)
        end

        def ltree(name, options = {})
          column(name, 'ltree', options)
        end

        def inet(name, options = {})
          column(name, 'inet', options)
        end

        def cidr(name, options = {})
          column(name, 'cidr', options)
        end

        def macaddr(name, options = {})
          column(name, 'macaddr', options)
        end

        def uuid(name, options = {})
          column(name, 'uuid', options)
        end

        def json(name, options = {})
          column(name, 'json', options)
        end

        def jsonb(name, options = {})
          column(name, :jsonb, options)
        end

        def bit(name, options)
          column(name, 'bit', options)
        end

        def bit_varying(name, options)
          column(name, 'bit varying', options)
        end
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods

        def primary_key(name, type = :primary_key, options = {})
          return super unless type == :uuid
          options[:default] = options.fetch(:default, 'uuid_generate_v4()')
          options[:primary_key] = true
          column name, type, options
        end if ::ActiveRecord::VERSION::MAJOR > 3 # 3.2 super expects (name)

        def column(name, type = nil, options = {})
          super
          column = self[name]
          # NOTE: <= 3.1 no #new_column_definition hard-coded ColumnDef.new :
          # column = self[name] || ColumnDefinition.new(@base, name, type)
          # thus we simply do not support array column definitions on <= 3.1
          column.array = options[:array] if column.is_a?(ColumnDefinition)
          self
        end

        private

        if ::ActiveRecord::VERSION::MAJOR > 3

          def create_column_definition(name, type)
            ColumnDefinition.new name, type
          end

        else # no #create_column_definition on 3.2

          def new_column_definition(base, name, type)
            definition = ColumnDefinition.new base, name, type
            @columns << definition
            @columns_hash[name] = definition
            definition
          end

        end

      end

      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods
      end
    end
  end
end
