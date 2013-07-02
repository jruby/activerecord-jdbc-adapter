module ArJdbc
  module FireBird

    def self.extended(adapter); initialize!; end

    @@_initialized = nil

    def self.initialize!
      return if @@_initialized; @@_initialized = true

      require 'arjdbc/jdbc/serialized_attributes_helper'
      ActiveRecord::Base.class_eval do
        def after_save_with_firebird_blob
          self.class.columns.select { |c| c.sql_type =~ /blob/i }.each do |column|
            value = ::ArJdbc::SerializedAttributesHelper.dump_column_value(self, column)
            next if value.nil?

            self.class.connection.write_large_object(
              column.type == :binary, column.name,
              self.class.table_name,
              self.class.primary_key,
              self.class.connection.quote(id), value
            )
          end
        end
      end
      ActiveRecord::Base.after_save :after_save_with_firebird_blob
    end

    def self.column_selector
      [ /firebird/i, lambda { |cfg, column| column.extend(Column) } ]
    end

    module Column

      def simplified_type(field_type)
        case field_type
        when /timestamp/i  then :datetime
        else super
        end
      end

      def default_value(value)
        return nil unless value
        if value =~ /^\s*DEFAULT\s+(.*)\s*$/i
          return $1 unless $1.upcase == 'NULL'
        end
      end

    end

    # @@emulate_booleans = true

    # Boolean emulation can be disabled using :
    #
    #   ArJdbc::FireBird.emulate_booleans = false
    #
    # def self.emulate_booleans; @@emulate_booleans; end
    # def self.emulate_booleans=(emulate); @@emulate_booleans = emulate; end

    ADAPTER_NAME = 'FireBird'.freeze

    def adapter_name
      ADAPTER_NAME
    end

    def self.arel2_visitors(config = nil)
      require 'arel/visitors/firebird'
      visitor = ::Arel::Visitors::Firebird
      { 'firebird' => visitor, 'firebirdsql' => visitor }
    end

    NATIVE_DATABASE_TYPES = {
      :primary_key => "integer not null primary key",
      :string => { :name => "varchar", :limit => 255 },
      :text => { :name => "blob sub_type text" },
      :integer => { :name => "integer" },
      :float => { :name => "float" },
      :decimal => { :name => "decimal" },
      :datetime => { :name => "timestamp" },
      :timestamp => { :name => "timestamp" },
      :time => { :name => "time" },
      :date => { :name => "date" },
      :binary => { :name => "blob" },
      :boolean => { :name => 'smallint' }
    }

    def native_database_types
      super.merge(NATIVE_DATABASE_TYPES)
    end

    def modify_types(types)
      super(types)
      NATIVE_DATABASE_TYPES.each do |key, value|
        types[key] = value.dup
      end
      types
    end

    def type_to_sql(type, limit = nil, precision = nil, scale = nil)
      case type
      when :integer
        case limit
          when nil  then 'integer'
          when 1..2 then 'smallint'
          when 3..4 then 'integer'
          when 5..8 then 'bigint'
          else raise(ActiveRecordError, "No integer type has byte size #{limit}. "<<
                                        "Use a NUMERIC with PRECISION 0 instead.")
        end
      when :float
        if limit.nil? || limit <= 4
          'float'
        else
          'double precision'
        end
      else super
      end
    end

    # Does this adapter support migrations?
    def supports_migrations?
      true
    end

    # Can this adapter determine the primary key for tables not attached
    # to an Active Record class, such as join tables?
    def supports_primary_key?
      true
    end

    # Does this adapter support using DISTINCT within COUNT?
    def supports_count_distinct?
      true
    end

    # Does this adapter support DDL rollbacks in transactions? That is, would
    # CREATE TABLE or ALTER TABLE get rolled back by a transaction? PostgreSQL,
    # SQL Server, and others support this. MySQL and others do not.
    def supports_ddl_transactions?
      false
    end

    def supports_savepoints?
      true
    end

    # Does this adapter restrict the number of ids you can use in a list.
    # Oracle has a limit of 1000.
    def ids_in_list_limit
      1499
    end

    def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = []) # :nodoc:
      execute(sql, name, binds)
      id_value
    end

    def add_limit_offset!(sql, options) # :nodoc:
      if options[:limit]
        limit_string = "FIRST #{options[:limit]}"
        limit_string << " SKIP #{options[:offset]}" if options[:offset]
        sql.sub!(/\A(\s*SELECT\s)/i, '\&' + limit_string + ' ')
      end
    end

    # Should primary key values be selected from their corresponding
    # sequence before the insert statement? If true, next_sequence_value
    # is called before each insert to set the record's primary key.
    # This is false for all adapters but Firebird.
    def prefetch_primary_key?(table_name = nil)
      true
    end

    def default_sequence_name(table_name, column=nil)
      "#{table_name}_seq"
    end

    # Set the sequence to the max value of the table's column.
    def reset_sequence!(table, column, sequence = nil)
      max_id = select_value("SELECT max(#{column}) FROM #{table}")
      execute("ALTER SEQUENCE #{default_sequence_name(table, column)} RESTART WITH #{max_id}")
    end

    def next_sequence_value(sequence_name)
      uncached do
        select_one("SELECT GEN_ID(#{sequence_name}, 1 ) FROM RDB$DATABASE;")["gen_id"]
      end
    end

    def create_table(name, options = {}) #:nodoc:
      super(name, options)
      execute "CREATE GENERATOR #{name}_seq"
    end

    def rename_table(name, new_name) #:nodoc:
      execute "RENAME #{name} TO #{new_name}"
      execute "UPDATE RDB$GENERATORS SET RDB$GENERATOR_NAME='#{new_name}_seq' WHERE RDB$GENERATOR_NAME='#{name}_seq'" rescue nil
    end

    def drop_table(name, options = {}) #:nodoc:
      super(name)
      execute "DROP GENERATOR #{name}_seq" rescue nil
    end

    def change_column(table_name, column_name, type, options = {}) #:nodoc:
      execute "ALTER TABLE #{table_name} ALTER  #{column_name} TYPE #{type_to_sql(type, options[:limit])}"
    end

    def rename_column(table_name, column_name, new_column_name)
      execute "ALTER TABLE #{table_name} ALTER  #{column_name} TO #{new_column_name}"
    end

    def remove_index(table_name, options) #:nodoc:
      execute "DROP INDEX #{index_name(table_name, options)}"
    end

    def quote(value, column = nil)
      return value.quoted_id if value.respond_to?(:quoted_id)

      type = column && column.type
      # BLOBs are updated separately by an after_save trigger.
      if type == :binary || type == :text
        return value.nil? ? "NULL" : "'#{quote_string(value[0..1])}'"
      end

      case value
      when String, ActiveSupport::Multibyte::Chars
        value = value.to_s
        if type == :integer || type == :float
          value = type == :integer ? value.to_i : value.to_f
          value.to_s
        else
          "'#{quote_string(value)}'"
        end
      when NilClass then "NULL"
      when TrueClass then (type == :integer ? '1' : quoted_true)
      when FalseClass then (type == :integer ? '0' : quoted_false)
      when Float, Fixnum, Bignum then value.to_s
      # BigDecimals need to be output in a non-normalized form and quoted.
      when BigDecimal then value.to_s('F')
      when Symbol then "'#{quote_string(value.to_s)}'"
      else
        if type == :time && value.acts_like?(:time)
          return "'#{value.strftime("%H:%M:%S")}'"
        end
        if type == :date && value.acts_like?(:date)
          return "'#{value.strftime("%Y-%m-%d")}'"
        end
        super
      end
    end

    def quote_string(string) # :nodoc:
      string.gsub(/'/, "''")
    end

    def quote_column_name(column_name) # :nodoc:
      column_name = column_name.to_s
      %Q("#{column_name =~ /[[:upper:]]/ ? column_name : column_name.upcase}")
    end

    def quoted_true # :nodoc:
      quote(1)
    end

    def quoted_false # :nodoc:
      quote(0)
    end

  end
end
