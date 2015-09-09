ArJdbc.load_java_part :Firebird

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

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_connection_class
    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::FirebirdJdbcConnection
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

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_column_class
    def jdbc_column_class; ::ActiveRecord::ConnectionAdapters::FirebirdColumn end

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

    def initialize_type_map(m)
      register_class_with_limit m, %r(binary)i, ActiveRecord::Type::Binary
      register_class_with_limit m, %r(text)i,   ActiveRecord::Type::Text

      register_class_with_limit m, %r(date(?:\(.*?\))?$)i, DateType
      register_class_with_limit m, %r(time(?:\(.*?\))?$)i, ActiveRecord::Type::Time

      register_class_with_limit m, %r(float)i, ActiveRecord::Type::Float
      register_class_with_limit m, %r(int)i,   ActiveRecord::Type::Integer

      m.alias_type %r(blob)i,   'binary'
      m.alias_type %r(clob)i,   'text'
      m.alias_type %r(double)i, 'float'

      m.register_type(%r(decimal)i) do |sql_type|
        scale = extract_scale(sql_type)
        precision = extract_precision(sql_type)
        if scale == 0
          ActiveRecord::Type::Integer.new(precision: precision)
        else
          ActiveRecord::Type::Decimal.new(precision: precision, scale: scale)
        end
      end
      m.alias_type %r(numeric)i, 'decimal'

      register_class_with_limit m, %r(varchar)i, ActiveRecord::Type::String

      m.register_type(%r(^char)i) do |sql_type|
        precision = extract_precision(sql_type)
        if Firebird.emulate_booleans? && precision == 1
          ActiveRecord::Type::Boolean.new
        else
          ActiveRecord::Type::String.new(:precision => precision)
        end
      end

      register_class_with_limit m, %r(datetime)i, ActiveRecord::Type::DateTime
      register_class_with_limit m, %r(timestamp)i, TimestampType
    end if AR42

    def clear_cache!
      super
      reload_type_map
    end if AR42

    # @private
    class DateType < ActiveRecord::Type::Date
      # NOTE: quote still gets called ...
      #def type_cast_for_database(value)
      #  if value.acts_like?(:date)
      #    "'#{value.strftime("%Y-%m-%d")}'"
      #  else
      #    super
      #  end
      #end
    end if AR42

    # @private
    class TimestampType < ActiveRecord::Type::DateTime
      def type; :timestamp end
    end if AR42

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
      if limit = options[:limit]
        insert_limit_offset!(sql, limit, options[:offset])
      end
    end

    # @private
    SELECT_RE = /\A(\s*SELECT\s)/i

    def insert_limit_offset!(sql, limit, offset)
      lim_off = ''
      lim_off << "FIRST #{limit}"  if limit
      lim_off << " SKIP #{offset}" if offset
      lim_off.strip!

      sql.sub!(SELECT_RE, "\\&#{lim_off} ") unless lim_off.empty?
    end

    # Should primary key values be selected from their corresponding
    # sequence before the insert statement?
    # @see #next_sequence_value
    # @override
    def prefetch_primary_key?(table_name = nil)
      return true if table_name.nil?
      primary_keys(table_name.to_s).size == 1
      # columns(table_name).count { |column| column.primary } == 1
    end

    IDENTIFIER_LENGTH = 31 # usual DB meta-identifier: 31 chars maximum

    def table_alias_length; IDENTIFIER_LENGTH; end
    def table_name_length;  IDENTIFIER_LENGTH; end
    def index_name_length;  IDENTIFIER_LENGTH; end
    def column_name_length; IDENTIFIER_LENGTH; end

    def default_sequence_name(table_name, column = nil)
      len = IDENTIFIER_LENGTH - 4
      table_name.to_s.gsub (/(^|\.)([\w$-]{1,#{len}})([\w$-]*)$/), '\1\2_seq'
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
      execute "CREATE GENERATOR #{default_sequence_name(name)}"
    end

    def rename_table(name, new_name)
      execute "RENAME #{name} TO #{new_name}"
      name_seq, new_name_seq = default_sequence_name(name), default_sequence_name(new_name)
      execute_quietly "UPDATE RDB$GENERATORS SET RDB$GENERATOR_NAME='#{new_name_seq}' WHERE RDB$GENERATOR_NAME='#{name_seq}'"
    end

    def drop_table(name, options = {})
      super(name)
      execute_quietly "DROP GENERATOR #{default_sequence_name(name)}"
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

require 'arjdbc/util/quoted_cache'

module ActiveRecord::ConnectionAdapters

  remove_const(:FirebirdAdapter) if const_defined?(:FirebirdAdapter)

  class FirebirdAdapter < JdbcAdapter
    include ::ArJdbc::Firebird
    include ::ArJdbc::Util::QuotedCache

    # By default, the FirebirdAdapter will consider all columns of type
    # <tt>char(1)</tt> as boolean. If you wish to disable this :
    #
    #   ActiveRecord::ConnectionAdapters::FirebirdAdapter.emulate_booleans = false
    #
    def self.emulate_booleans?; ::ArJdbc::Firebird.emulate_booleans?; end
    def self.emulate_booleans;  ::ArJdbc::Firebird.emulate_booleans?; end # oracle-enhanced
    def self.emulate_booleans=(emulate); ::ArJdbc::Firebird.emulate_booleans = emulate; end

    def initialize(*args)
      ::ArJdbc::Firebird.initialize!
      super
    end

  end

  class FirebirdColumn < JdbcColumn
    include ::ArJdbc::Firebird::Column
  end

end