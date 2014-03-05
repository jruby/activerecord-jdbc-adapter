module ArJdbc
  module Firebird

    # @private
    def self.extended(adapter); initialize!; end

    # @private
    @@_initialized = nil

    # @private
    def self.initialize!
      return if @@_initialized; @@_initialized = true

      require 'arjdbc/util/serialized_attributes'
      Util::SerializedAttributes.setup /blob/i
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn#column_types
    def self.column_selector
      [ /firebird/i, lambda { |cfg, column| column.extend(Column) } ]
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn
    module Column

      def default_value(value)
        return nil unless value
        if value =~ /^\s*DEFAULT\s+(.*)\s*$/i
          return $1 unless $1.upcase == 'NULL'
        end
      end

      private

      def simplified_type(field_type)
        case field_type
        when /timestamp/i    then :datetime
        when /^smallint/i    then :integer
        when /^bigint|int/i  then :integer
        when /^double/i      then :float # double precision
        when /^decimal/i     then
          extract_scale(field_type) == 0 ? :integer : :decimal
        when /^char\(1\)$/i  then Firebird.emulate_booleans? ? :boolean : :string
        when /^char/i        then :string
        when /^blob\ssub_type\s(\d)/i
          return :binary if $1 == '0'
          return :text   if $1 == '1'
        else
          super
        end
      end

    end

    # @see ArJdbc::ArelHelper::ClassMethods#arel_visitor_type
    def self.arel_visitor_type(config = nil)
      require 'arel/visitors/firebird'; ::Arel::Visitors::Firebird
    end

    # @deprecated no longer used
    def self.arel2_visitors(config = nil)
      { 'firebird' => arel_visitor_type, 'firebirdsql' => arel_visitor_type }
    end

    # @private
    @@emulate_booleans = true

    # Boolean emulation can be disabled using :
    #
    #   ArJdbc::Firebird.emulate_booleans = false
    #
    def self.emulate_booleans?; @@emulate_booleans; end
    # @deprecated Use {#emulate_booleans?} instead.
    def self.emulate_booleans; @@emulate_booleans; end
    # @see #emulate_booleans?
    def self.emulate_booleans=(emulate); @@emulate_booleans = emulate; end


    @@update_lob_values = true

    # Updating records with LOB values (binary/text columns) in a separate
    # statement can be disabled using :
    #
    #   ArJdbc::Firebird.update_lob_values = false
    def self.update_lob_values?; @@update_lob_values; end
    # @see #update_lob_values?
    def self.update_lob_values=(update); @@update_lob_values = update; end

    # @see #update_lob_values?
    def update_lob_values?; Firebird.update_lob_values?; end

    # @see #quote
    # @private
    BLOB_VALUE_MARKER = "''"

    ADAPTER_NAME = 'Firebird'.freeze

    def adapter_name
      ADAPTER_NAME
    end

    NATIVE_DATABASE_TYPES = {
      :primary_key => "integer not null primary key",
      :string => { :name => "varchar", :limit => 255 },
      :text => { :name => "blob sub_type text" },
      :integer => { :name => "integer" },
      :float => { :name => "float" },
      :datetime => { :name => "timestamp" },
      :timestamp => { :name => "timestamp" },
      :time => { :name => "time" },
      :date => { :name => "date" },
      :binary => { :name => "blob" },
      :boolean => { :name => 'char', :limit => 1 },
      :numeric => { :name => "numeric" },
      :decimal => { :name => "decimal" },
      :char => { :name => "char" },
    }

    def native_database_types
      NATIVE_DATABASE_TYPES
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

    # Does this adapter restrict the number of IDs you can use in a list.
    # Oracle has a limit of 1000.
    def ids_in_list_limit
      1499
    end

    def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
      execute(sql, name, binds)
      id_value
    end

    def add_limit_offset!(sql, options)
      if options[:limit]
        limit_string = "FIRST #{options[:limit]}"
        limit_string << " SKIP #{options[:offset]}" if options[:offset]
        sql.sub!(/\A(\s*SELECT\s)/i, '\&' + limit_string + ' ')
      end
    end

    # Should primary key values be selected from their corresponding
    # sequence before the insert statement?
    # @see #next_sequence_value
    # @override
    def prefetch_primary_key?(table_name = nil)
      return true if table_name.nil?
      table_name = table_name.to_s
      columns(table_name).count { |column| column.primary } == 1
    end
    # The name of a sequence name must be a usual DB meta-identifier: 31 chars maximum
    IDENTIFIER_LENGTH = 31
    def default_sequence_name(table_name, column = nil)
      "#{table_name.to_s[0, IDENTIFIER_LENGTH - 4]}_seq"
    end

    # Set the sequence to the max value of the table's column.
    def reset_sequence!(table, column, sequence = nil)
      max_id = select_value("SELECT max(#{column}) FROM #{table}")
      execute("ALTER SEQUENCE #{default_sequence_name(table, column)} RESTART WITH #{max_id}")
    end

    def next_sequence_value(sequence_name)
      select_one("SELECT GEN_ID(#{sequence_name}, 1 ) FROM RDB$DATABASE;")["gen_id"]
    end

    def create_table(name, options = {})
      super(name, options)
      execute "CREATE GENERATOR #{name}_seq"
    end

    def rename_table(name, new_name)
      execute "RENAME #{name} TO #{new_name}"
      execute "UPDATE RDB$GENERATORS SET RDB$GENERATOR_NAME='#{new_name}_seq' WHERE RDB$GENERATOR_NAME='#{name}_seq'" rescue nil
    end

    def drop_table(name, options = {})
      super(name)
      execute "DROP GENERATOR #{name}_seq" rescue nil
    end

    def change_column(table_name, column_name, type, options = {})
      execute "ALTER TABLE #{table_name} ALTER  #{column_name} TYPE #{type_to_sql(type, options[:limit])}"
    end

    def rename_column(table_name, column_name, new_column_name)
      execute "ALTER TABLE #{table_name} ALTER  #{column_name} TO #{new_column_name}"
    end

    def remove_index(table_name, options)
      execute "DROP INDEX #{index_name(table_name, options)}"
    end

    # @override
    def quote(value, column = nil)
      return value.quoted_id if value.respond_to?(:quoted_id)
      return value if sql_literal?(value)

      type = column && column.type

      # BLOBs are updated separately by an after_save trigger.
      if type == :binary || type == :text
        if update_lob_values?
          return value.nil? ? "NULL" : BLOB_VALUE_MARKER
        else
          return "'#{quote_string(value)}'"
        end
      end

      case value
      when String, ActiveSupport::Multibyte::Chars
        value = value.to_s
        if type == :integer
          value.to_i.to_s
        elsif type == :float
          value.to_f.to_s
        else
          "'#{quote_string(value)}'"
        end
      when NilClass then 'NULL'
      when TrueClass then (type == :integer ? '1' : quoted_true)
      when FalseClass then (type == :integer ? '0' : quoted_false)
      when Float, Fixnum, Bignum then value.to_s
      # BigDecimals need to be output in a non-normalized form and quoted.
      when BigDecimal then value.to_s('F')
      when Symbol then "'#{quote_string(value.to_s)}'"
      else
        if type == :time && value.acts_like?(:time)
          return "'#{get_time(value).strftime("%H:%M:%S")}'"
        end
        if type == :date && value.acts_like?(:date)
          return "'#{value.strftime("%Y-%m-%d")}'"
        end
        super
      end
    end

    # @override
    def quoted_date(value)
      if value.acts_like?(:time) && value.respond_to?(:usec)
        usec = sprintf "%04d", (value.usec / 100.0).round
        value = ::ActiveRecord::Base.default_timezone == :utc ? value.getutc : value.getlocal
        "#{value.strftime("%Y-%m-%d %H:%M:%S")}.#{usec}"
      else
        super
      end
    end if ::ActiveRecord::VERSION::MAJOR >= 3

    # @override
    def quote_string(string)
      string.gsub(/'/, "''")
    end

    # @override
    def quoted_true
      quote(1)
    end

    # @override
    def quoted_false
      quote(0)
    end

    # @override
    def quote_table_name_for_assignment(table, attr)
      quote_column_name(attr)
    end if ::ActiveRecord::VERSION::MAJOR >= 4

    # @override
    def quote_column_name(column_name)
      column_name = column_name.to_s
      %Q("#{column_name =~ /[[:upper:]]/ ? column_name : column_name.upcase}")
    end

  end
  FireBird = Firebird
end
