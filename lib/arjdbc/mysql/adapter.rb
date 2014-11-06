ArJdbc.load_java_part :MySQL

require 'bigdecimal'
require 'active_record/connection_adapters/abstract/schema_definitions'
require 'arjdbc/mysql/column'
require 'arjdbc/mysql/bulk_change_table'
require 'arjdbc/mysql/explain_support'
require 'arjdbc/mysql/schema_creation' # AR 4.x

module ArJdbc
  module MySQL
    include BulkChangeTable if const_defined? :BulkChangeTable

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_connection_class
    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::MySQLJdbcConnection
    end

    # @private
    def init_connection(jdbc_connection)
      meta = jdbc_connection.meta_data
      if meta.driver_major_version == 1 # TODO check in driver code
        # assumes MariaDB 1.x currently
      elsif meta.driver_major_version < 5
        raise ::ActiveRecord::ConnectionNotEstablished,
          "MySQL adapter requires driver >= 5.0 got: '#{meta.driver_version}'"
      elsif meta.driver_major_version == 5 && meta.driver_minor_version < 1
        config[:connection_alive_sql] ||= 'SELECT 1' # need 5.1 for JDBC 4.0
      else
        # NOTE: since the loaded Java driver class can't change :
        MySQL.send(:remove_method, :init_connection) rescue nil
      end
    end

    def configure_connection
      variables = config[:variables] || {}
      # By default, MySQL 'where id is null' selects the last inserted id. Turn this off.
      variables[:sql_auto_is_null] = 0 # execute "SET SQL_AUTO_IS_NULL=0"

      # Increase timeout so the server doesn't disconnect us.
      wait_timeout = config[:wait_timeout]
      wait_timeout = self.class.type_cast_config_to_integer(wait_timeout)
      variables[:wait_timeout] = wait_timeout.is_a?(Fixnum) ? wait_timeout : 2147483

      # Make MySQL reject illegal values rather than truncating or blanking them, see
      # http://dev.mysql.com/doc/refman/5.0/en/server-sql-mode.html#sqlmode_strict_all_tables
      # If the user has provided another value for sql_mode, don't replace it.
      if strict_mode? && ! variables.has_key?(:sql_mode)
        variables[:sql_mode] = 'STRICT_ALL_TABLES' # SET SQL_MODE='STRICT_ALL_TABLES'
      end

      # NAMES does not have an equals sign, see
      # http://dev.mysql.com/doc/refman/5.0/en/set-statement.html#id944430
      # (trailing comma because variable_assignments will always have content)
      encoding = "NAMES #{config[:encoding]}, " if config[:encoding]

      # Gather up all of the SET variables...
      variable_assignments = variables.map do |k, v|
        if v == ':default' || v == :default
          "@@SESSION.#{k.to_s} = DEFAULT" # Sets the value to the global or compile default
        elsif ! v.nil?
          "@@SESSION.#{k.to_s} = #{quote(v)}"
        end
        # or else nil; compact to clear nils out
      end.compact.join(', ')

      # ...and send them all in one query
      execute("SET #{encoding} #{variable_assignments}", :skip_logging)
    end

    def strict_mode? # strict_mode is default since AR 4.0
      config.key?(:strict) ?
        self.class.type_cast_config_to_boolean(config[:strict]) :
          ::ActiveRecord::VERSION::MAJOR > 3
    end

    # @private
    @@emulate_booleans = true

    # Boolean emulation can be disabled using (or using the adapter method) :
    #
    #   ArJdbc::MySQL.emulate_booleans = false
    #
    # @see ActiveRecord::ConnectionAdapters::MysqlAdapter#emulate_booleans
    def self.emulate_booleans?; @@emulate_booleans; end
    # @deprecated Use {#emulate_booleans?} instead.
    def self.emulate_booleans; @@emulate_booleans; end
    # @see #emulate_booleans?
    def self.emulate_booleans=(emulate); @@emulate_booleans = emulate; end

    NATIVE_DATABASE_TYPES = {
      :primary_key => "int(11) DEFAULT NULL auto_increment PRIMARY KEY",
      :string => { :name => "varchar", :limit => 255 },
      :text => { :name => "text" },
      :integer => { :name => "int", :limit => 4 },
      :float => { :name => "float" },
      # :double => { :name=>"double", :limit=>17 }
      # :real => { :name=>"real", :limit=>17 }
      :numeric => { :name => "numeric" }, # :limit => 65
      :decimal => { :name => "decimal" }, # :limit => 65
      :datetime => { :name => "datetime" },
      # TIMESTAMP has varying properties depending on MySQL version (SQL mode)
      :timestamp => { :name => "datetime" },
      :time => { :name => "time" },
      :date => { :name => "date" },
      :binary => { :name => "blob" },
      :boolean => { :name => "tinyint", :limit => 1 },
      # AR-JDBC added :
      :bit => { :name => "bit" }, # :limit => 1
      :enum => { :name => "enum" },
      :set => { :name => "set" }, # :limit => 64
      :char => { :name => "char" }, # :limit => 255
    }

    # @override
    def native_database_types
      NATIVE_DATABASE_TYPES
    end

    ADAPTER_NAME = 'MySQL'.freeze

    # @override
    def adapter_name
      ADAPTER_NAME
    end

    def self.arel_visitor_type(config = nil)
      ::Arel::Visitors::MySQL
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#bind_substitution
    # @private
    class BindSubstitution < Arel::Visitors::MySQL
      include Arel::Visitors::BindVisitor
    end if defined? Arel::Visitors::BindVisitor

    def case_sensitive_equality_operator
      "= BINARY"
    end

    def case_sensitive_modifier(node)
      Arel::Nodes::Bin.new(node)
    end

    def case_sensitive_modifier(node, table_attribute)
      node = Arel::Nodes.build_quoted node, table_attribute
      Arel::Nodes::Bin.new(node)
    end if ActiveRecord::VERSION::STRING > '4.2'

    def limited_update_conditions(where_sql, quoted_table_name, quoted_primary_key)
      where_sql
    end

    # QUOTING ==================================================

    # @override
    def quote(value, column = nil)
      return value.quoted_id if value.respond_to?(:quoted_id)
      return value if sql_literal?(value)
      return value.to_s if column && column.type == :primary_key

      if value.kind_of?(String) && column && column.type == :binary
        "x'#{value.unpack("H*")[0]}'"
      elsif value.kind_of?(BigDecimal)
        value.to_s("F")
      else
        super
      end
    end

    # @override
    def quote_column_name(name)
      "`#{name.to_s.gsub('`', '``')}`"
    end

    # @override
    def quote_table_name(name)
      quote_column_name(name).gsub('.', '`.`')
    end

    # @override
    def supports_migrations?
      true
    end

    # @override
    def supports_primary_key?
      true
    end

    # @override
    def supports_index_sort_order?
      # Technically MySQL allows to create indexes with the sort order syntax
      # but at the moment (5.5) it doesn't yet implement them.
      true
    end

    # @override
    def supports_transaction_isolation?
      # MySQL 4 technically support transaction isolation, but it is affected by
      # a bug where the transaction level gets persisted for the whole session:
      # http://bugs.mysql.com/bug.php?id=39170
      version[0] && version[0] >= 5
    end

    # @override
    def supports_views?
      version[0] && version[0] >= 5
    end

    # @override
    def supports_transaction_isolation?(level = nil)
      version[0] >= 5 # MySQL 5+
    end

    # NOTE: handled by JdbcAdapter we override only to have save-point in logs :

    # @override
    def supports_savepoints?
      true
    end

    # @override
    def create_savepoint(name = current_savepoint_name(true))
      log("SAVEPOINT #{name}", 'Savepoint') { super }
    end

    # @override
    def rollback_to_savepoint(name = current_savepoint_name)
      log("ROLLBACK TO SAVEPOINT #{name}", 'Savepoint') { super }
    end

    # @override
    def release_savepoint(name = current_savepoint_name)
      log("RELEASE SAVEPOINT #{name}", 'Savepoint') { super }
    end

    def disable_referential_integrity
      fk_checks = select_value("SELECT @@FOREIGN_KEY_CHECKS")
      begin
        update("SET FOREIGN_KEY_CHECKS = 0")
        yield
      ensure
        update("SET FOREIGN_KEY_CHECKS = #{fk_checks}")
      end
    end

    # @override make it public just like native MySQL adapter does
    def update_sql(sql, name = nil)
      super
    end

    # SCHEMA STATEMENTS ========================================

    # @deprecated no longer used - handled with (AR built-in) Rake tasks
    def structure_dump
      # NOTE: due AR (2.3-3.2) compatibility views are not included
      if supports_views?
        sql = "SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'"
      else
        sql = "SHOW TABLES"
      end

      @connection.execute_query_raw(sql).map do |table|
        # e.g. { "Tables_in_arjdbc_test"=>"big_fields", "Table_type"=>"BASE TABLE" }
        table.delete('Table_type')
        table_name = table.to_a.first.last

        create_table = select_one("SHOW CREATE TABLE #{quote_table_name(table_name)}")

        "#{create_table['Create Table']};\n\n"
      end.join
    end

    # Returns just a table's primary key.
    # @override
    def primary_key(table)
      #pk_and_sequence = pk_and_sequence_for(table)
      #pk_and_sequence && pk_and_sequence.first
      @connection.primary_keys(table).first
    end

    # Returns a table's primary key and belonging sequence.
    # @note Not used, only here for potential compatibility with native adapter.
    # @override
    def pk_and_sequence_for(table)
      result = execute("SHOW CREATE TABLE #{quote_table_name(table)}", 'SCHEMA').first
      if result['Create Table'].to_s =~ /PRIMARY KEY\s+(?:USING\s+\w+\s+)?\((.+)\)/
        keys = $1.split(","); keys.map! { |key| key.gsub(/[`"]/, "") }
        return keys.length == 1 ? [ keys.first, nil ] : nil
      else
        return nil
      end
    end

    # @private
    IndexDefinition = ::ActiveRecord::ConnectionAdapters::IndexDefinition

    if ::ActiveRecord::VERSION::MAJOR > 3

    INDEX_TYPES = [ :fulltext, :spatial ]
    INDEX_USINGS = [ :btree, :hash ]

    end

    # Returns an array of indexes for the given table.
    # @override
    def indexes(table_name, name = nil)
      indexes = []
      current_index = nil
      result = execute("SHOW KEYS FROM #{quote_table_name(table_name)}", name || 'SCHEMA')
      result.each do |row|
        key_name = row['Key_name']
        if current_index != key_name
          next if key_name == 'PRIMARY' # skip the primary key
          current_index = key_name
          indexes <<
            if self.class.const_defined?(:INDEX_TYPES) # AR 4.0
              mysql_index_type = row['Index_type'].downcase.to_sym
              index_type = INDEX_TYPES.include?(mysql_index_type) ? mysql_index_type : nil
              index_using = INDEX_USINGS.include?(mysql_index_type) ? mysql_index_type : nil
              IndexDefinition.new(row['Table'], key_name, row['Non_unique'].to_i == 0, [], [], nil, nil, index_type, index_using)
            else
              IndexDefinition.new(row['Table'], key_name, row['Non_unique'].to_i == 0, [], [])
            end
        end

        indexes.last.columns << row["Column_name"]
        indexes.last.lengths << row["Sub_part"]
      end
      indexes
    end

    # Returns an array of `Column` objects for the table specified.
    # @override
    def columns(table_name, name = nil)
      sql = "SHOW FULL COLUMNS FROM #{quote_table_name(table_name)}"
      columns = execute(sql, name || 'SCHEMA')
      strict = strict_mode?
      column = ::ActiveRecord::ConnectionAdapters::MysqlAdapter::Column
      pass_cast_type = respond_to?(:lookup_cast_type)
      columns.map! do |field|
        sql_type = field['Type']
        null = field['Null'] == "YES"
        if pass_cast_type
          cast_type = lookup_cast_type(sql_type)
          column.new(field['Field'], field['Default'], cast_type, sql_type, null, field['Collation'], strict, field['Extra'])
        else
          column.new(field['Field'], field['Default'], sql_type, null, field['Collation'], strict, field['Extra'])
        end
      end
      columns
    end

    # @private
    def recreate_database(name, options = {})
      drop_database(name)
      create_database(name, options)
      reconnect!
    end

    # @override
    def create_database(name, options = {})
      if options[:collation]
        execute "CREATE DATABASE `#{name}` DEFAULT CHARACTER SET `#{options[:charset] || 'utf8'}` COLLATE `#{options[:collation]}`"
      else
        execute "CREATE DATABASE `#{name}` DEFAULT CHARACTER SET `#{options[:charset] || 'utf8'}`"
      end
    end

    # @override
    def drop_database(name)
      execute "DROP DATABASE IF EXISTS `#{name}`"
    end

    def current_database
      select_one("SELECT DATABASE() as db")["db"]
    end

    # @override
    def create_table(name, options = {})
      super(name, {:options => "ENGINE=InnoDB DEFAULT CHARSET=utf8"}.merge(options))
    end

    # @override
    def rename_table(table_name, new_name)
      execute "RENAME TABLE #{quote_table_name(table_name)} TO #{quote_table_name(new_name)}"
      rename_table_indexes(table_name, new_name) if respond_to?(:rename_table_indexes) # AR-4.0 SchemaStatements
    end

    # @override
    def remove_index!(table_name, index_name)
      # missing table_name quoting in AR-2.3
      execute "DROP INDEX #{quote_column_name(index_name)} ON #{quote_table_name(table_name)}"
    end

    # @override
    def add_column(table_name, column_name, type, options = {})
      add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ADD #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
      add_column_options!(add_column_sql, options)
      add_column_position!(add_column_sql, options)
      execute(add_column_sql)
    end unless const_defined? :SchemaCreation

    def change_column_default(table_name, column_name, default)
      column = column_for(table_name, column_name)
      change_column table_name, column_name, column.sql_type, :default => default
    end # unless const_defined? :SchemaCreation

    def change_column_null(table_name, column_name, null, default = nil)
      column = column_for(table_name, column_name)

      unless null || default.nil?
        execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
      end

      change_column table_name, column_name, column.sql_type, :null => null
    end # unless const_defined? :SchemaCreation

    # @override
    def change_column(table_name, column_name, type, options = {})
      column = column_for(table_name, column_name)

      unless options_include_default?(options)
        # NOTE: no defaults for BLOB/TEXT columns with MySQL
        options[:default] = column.default if type != :text && type != :binary
      end

      unless options.has_key?(:null)
        options[:null] = column.null
      end

      change_column_sql = "ALTER TABLE #{quote_table_name(table_name)} CHANGE #{quote_column_name(column_name)} #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
      add_column_options!(change_column_sql, options)
      add_column_position!(change_column_sql, options)
      execute(change_column_sql)
    end

    # @override
    def rename_column(table_name, column_name, new_column_name)
      options = {}

      if column = columns(table_name).find { |c| c.name == column_name.to_s }
        type = column.type
        options[:default] = column.default if type != :text && type != :binary
        options[:null] = column.null
      else
        raise ActiveRecord::ActiveRecordError, "No such column: #{table_name}.#{column_name}"
      end

      current_type = select_one("SHOW COLUMNS FROM #{quote_table_name(table_name)} LIKE '#{column_name}'")["Type"]

      rename_column_sql = "ALTER TABLE #{quote_table_name(table_name)} CHANGE #{quote_column_name(column_name)} #{quote_column_name(new_column_name)} #{current_type}"
      add_column_options!(rename_column_sql, options)
      execute(rename_column_sql)
      rename_column_indexes(table_name, column_name, new_column_name) if respond_to?(:rename_column_indexes) # AR-4.0 SchemaStatements
    end

    def add_column_position!(sql, options)
      if options[:first]
        sql << " FIRST"
      elsif options[:after]
        sql << " AFTER #{quote_column_name(options[:after])}"
      end
    end unless const_defined? :SchemaCreation

    # @note Only used with (non-AREL) ActiveRecord **2.3**.
    # @see Arel::Visitors::MySQL
    def add_limit_offset!(sql, options)
      limit, offset = options[:limit], options[:offset]
      if limit && offset
        sql << " LIMIT #{offset.to_i}, #{sanitize_limit(limit)}"
      elsif limit
        sql << " LIMIT #{sanitize_limit(limit)}"
      elsif offset
        sql << " OFFSET #{offset.to_i}"
      end
      sql
    end if ::ActiveRecord::VERSION::MAJOR < 3

    # In the simple case, MySQL allows us to place JOINs directly into the UPDATE
    # query. However, this does not allow for LIMIT, OFFSET and ORDER. To support
    # these, we must use a subquery. However, MySQL is too stupid to create a
    # temporary table for this automatically, so we have to give it some prompting
    # in the form of a subsubquery. Ugh!
    # @private based on mysql_adapter.rb from 3.1-stable
    def join_to_update(update, select)
      if select.limit || select.offset || select.orders.any?
        subsubselect = select.clone
        subsubselect.projections = [update.key]

        subselect = Arel::SelectManager.new(select.engine)
        subselect.project Arel.sql(update.key.name)
        subselect.from subsubselect.as('__active_record_temp')

        update.where update.key.in(subselect)
      else
        update.table select.source
        update.wheres = select.constraints
      end
    end

    def show_variable(var)
      res = execute("show variables like '#{var}'")
      result_row = res.detect {|row| row["Variable_name"] == var }
      result_row && result_row["Value"]
    end

    def charset
      show_variable("character_set_database")
    end

    def collation
      show_variable("collation_database")
    end

    def type_to_sql(type, limit = nil, precision = nil, scale = nil)
      case type.to_s
      when 'binary'
        case limit
        when 0..0xfff; "varbinary(#{limit})"
        when nil; "blob"
        when 0x1000..0xffffffff; "blob(#{limit})"
        else raise(ActiveRecordError, "No binary type has character length #{limit}")
        end
      when 'integer'
        case limit
        when 1; 'tinyint'
        when 2; 'smallint'
        when 3; 'mediumint'
        when nil, 4, 11; 'int(11)' # compatibility with MySQL default
        when 5..8; 'bigint'
        else raise(ActiveRecordError, "No integer type has byte size #{limit}")
        end
      when 'text'
        case limit
        when 0..0xff; 'tinytext'
        when nil, 0x100..0xffff; 'text'
        when 0x10000..0xffffff; 'mediumtext'
        when 0x1000000..0xffffffff; 'longtext'
        else raise(ActiveRecordError, "No text type has character length #{limit}")
        end
      else
        super
      end
    end

    # @override
    def empty_insert_statement_value
      "VALUES ()"
    end

    protected
    def quoted_columns_for_index(column_names, options = {})
      length = options[:length] if options.is_a?(Hash)

      case length
      when Hash
        column_names.map { |name| length[name] ? "#{quote_column_name(name)}(#{length[name]})" : quote_column_name(name) }
      when Fixnum
        column_names.map { |name| "#{quote_column_name(name)}(#{length})" }
      else
        column_names.map { |name| quote_column_name(name) }
      end
    end

    # @override
    def translate_exception(exception, message)
      return super unless exception.respond_to?(:errno)

      case exception.errno
      when 1062
        ::ActiveRecord::RecordNotUnique.new(message, exception)
      when 1452
        ::ActiveRecord::InvalidForeignKey.new(message, exception)
      else
        super
      end
    end

    private

    def column_for(table_name, column_name)
      unless column = columns(table_name).find { |c| c.name == column_name.to_s }
        raise "No such column: #{table_name}.#{column_name}"
      end
      column
    end

    def version
      return @version ||= begin
        version = []
        java_connection = jdbc_connection(true)
        if java_connection.java_class.name == 'com.mysql.jdbc.ConnectionImpl'
          version << jdbc_connection.serverMajorVersion
          version << jdbc_connection.serverMinorVersion
          version << jdbc_connection.serverSubMinorVersion
        else
          result = execute 'SELECT VERSION()', 'SCHEMA'
          result = result.first.values.first # [{"VERSION()"=>"5.5.37-0ubuntu..."}]
          if match = result.match(/^(\d)\.(\d+)\.(\d+)/)
            version << match[1].to_i
            version << match[2].to_i
            version << match[3].to_i
          end
        end
        version.freeze
      end
    end

  end
end

module ActiveRecord
  module ConnectionAdapters
    # Remove any vestiges of core/Ruby MySQL adapter
    remove_const(:MysqlAdapter) if const_defined?(:MysqlAdapter)

    class MysqlAdapter < JdbcAdapter
      include ::ArJdbc::MySQL
      include ::ArJdbc::MySQL::ExplainSupport

      # By default, the MysqlAdapter will consider all columns of type
      # __tinyint(1)__ as boolean. If you wish to disable this :
      # ```
      #   ActiveRecord::ConnectionAdapters::Mysql[2]Adapter.emulate_booleans = false
      # ```
      def self.emulate_booleans?; ::ArJdbc::MySQL.emulate_booleans?; end
      def self.emulate_booleans;  ::ArJdbc::MySQL.emulate_booleans?; end # native adapter
      def self.emulate_booleans=(emulate); ::ArJdbc::MySQL.emulate_booleans = emulate; end

      class Column < JdbcColumn
        include ::ArJdbc::MySQL::Column

        def initialize(name, default, sql_type = nil, null = true, collation = nil, strict = false, extra = '')
          if Hash === name
            super # first arg: config
          else
            @strict = strict; @collation = collation; @extra = extra
            super(name, default, sql_type, null)
            # base 4.1: (name, default, sql_type = nil, null = true)
          end
        end

        def initialize(name, default, cast_type, sql_type = nil, null = true, collation = nil, strict = false, extra = '')
          if Hash === name
            super # first arg: config
          else
            @strict = strict; @collation = collation; @extra = extra
            super(name, default, cast_type, sql_type, null)
            # base 4.2: (name, default, cast_type, sql_type = nil, null = true)
          end
        end if ActiveRecord::VERSION::STRING >= '4.2'

        # @note {#ArJdbc::MySQL::Column} uses this to check for boolean emulation
        def adapter
          MysqlAdapter
        end

      end

      def initialize(*args)
        super # configure_connection happens in super
      end

      def jdbc_connection_class(spec)
        ::ArJdbc::MySQL.jdbc_connection_class
      end

      def jdbc_column_class
        Column
      end

    end

    if ActiveRecord::VERSION::MAJOR < 3 ||
        ( ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR <= 1 )
      remove_const(:MysqlColumn) if const_defined?(:MysqlColumn)
      MysqlColumn = MysqlAdapter::Column
    end

    if ActiveRecord::VERSION::MAJOR > 3 ||
        ( ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR >= 1 )
      remove_const(:Mysql2Adapter) if const_defined?(:Mysql2Adapter)
      Mysql2Adapter = MysqlAdapter
      if ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR == 1
        remove_const(:Mysql2Column) if const_defined?(:Mysql2Column)
        Mysql2Column = MysqlAdapter::Column
      end
    end

  end
end
