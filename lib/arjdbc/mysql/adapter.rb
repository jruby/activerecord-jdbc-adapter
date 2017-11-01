ArJdbc.load_java_part :MySQL

require 'bigdecimal'
require 'active_record/connection_adapters/abstract_mysql_adapter'
require 'active_record/connection_adapters/abstract/schema_definitions'
require 'arjdbc/abstract/core'
require 'arjdbc/abstract/connection_management'
require 'arjdbc/abstract/database_statements'
require 'arjdbc/abstract/statement_cache'
require 'arjdbc/abstract/transaction_support'

module ArJdbc
  module MySQL

#    require 'arjdbc/mysql/column'
    require 'arjdbc/mysql/bulk_change_table'
    require 'arjdbc/mysql/explain_support'

    include BulkChangeTable if const_defined? :BulkChangeTable

    # @private
    ActiveRecordError = ::ActiveRecord::ActiveRecordError

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_connection_class
    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::MySQLJdbcConnection
    end

    def jdbc_column_class
      ::ActiveRecord::ConnectionAdapters::MysqlAdapter::Column
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

    def strict_mode?
      config.key?(:strict) ?
        self.class.type_cast_config_to_boolean(config[:strict]) :
          AR40 # strict_mode is default since AR 4.0
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
      :primary_key => "int(11) auto_increment PRIMARY KEY",
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

    def case_sensitive_equality_operator
      "= BINARY"
    end

    def case_sensitive_comparison(table, attribute, column, value)
      if column.case_sensitive?
        table[attribute].eq(value)
      else
        super
      end
    end

    def case_insensitive_comparison(table, attribute, column, value)
      if column.case_sensitive?
        super
      else
        table[attribute].eq(value)
      end
    end

    def limited_update_conditions(where_sql, quoted_table_name, quoted_primary_key)
      where_sql
    end

    def initialize_schema_migrations_table
      if @config[:encoding] == 'utf8mb4'
        ActiveRecord::SchemaMigration.create_table(191)
      else
        ActiveRecord::SchemaMigration.create_table
      end
    end

    # HELPER METHODS ===========================================

    # @private Only for Rails core compatibility.
    def new_column(field, default, cast_type, sql_type = nil, null = true, collation = "", extra = "")
      jdbc_column_class.new(field, default, cast_type, sql_type, null, collation, strict_mode?, extra)
    end

    # @private Only for Rails core compatibility.
    def error_number(exception)
      exception.error_code if exception.respond_to?(:error_code)
    end

    # QUOTING ==================================================

    # @private since AR 4.2
    def _quote(value)
      if value.is_a?(Type::Binary::Data)
        "x'#{value.hex}'"
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
    def supports_indexes_in_create?
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

    def views
      select_values("SELECT table_name FROM information_schema.TABLES WHERE table_type = 'VIEW'")
    end

    def supports_rename_index?
      return false if mariadb? || ! version[0]
      (version[0] == 5 && version[1] >= 7) || version[0] >= 6
    end

    def index_algorithms
      { :default => 'ALGORITHM = DEFAULT', :copy => 'ALGORITHM = COPY', :inplace => 'ALGORITHM = INPLACE' }
    end

    # @override
    def supports_transaction_isolation?(level = nil)
      version[0] && version[0] >= 5 # MySQL 5+
    end

    # NOTE: handled by JdbcAdapter only to have statements in logs :

    # @override
    def supports_savepoints?
      true
    end

    # @override
    def create_savepoint(name = current_savepoint_name(true))
      log("SAVEPOINT #{name}", 'Savepoint') { super }
    end

    # @override
    def rollback_to_savepoint(name = current_savepoint_name(true))
      log("ROLLBACK TO SAVEPOINT #{name}", 'Savepoint') { super }
    end

    # @override
    def release_savepoint(name = current_savepoint_name(false))
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

    INDEX_TYPES = [ :fulltext, :spatial ] if AR40
    INDEX_USINGS = [ :btree, :hash ] if AR40

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



    if defined? ::ActiveRecord::ConnectionAdapters::AbstractAdapter::SchemaCreation

    class SchemaCreation < ::ActiveRecord::ConnectionAdapters::AbstractAdapter::SchemaCreation

      # @private
      def visit_AddColumn(o)
        add_column_position!(super, column_options(o))
      end

      # @private re-defined since AR 4.1
      def visit_ChangeColumnDefinition(o)
        column = o.column
        options = o.options
        sql_type = type_to_sql(o.type, options[:limit], options[:precision], options[:scale])
        change_column_sql = "CHANGE #{quote_column_name(column.name)} #{quote_column_name(options[:name])} #{sql_type}"
        add_column_options!(change_column_sql, options.merge(:column => column))
        add_column_position!(change_column_sql, options)
      end

      # @private since AR 4.2
      def visit_DropForeignKey(name)
        "DROP FOREIGN KEY #{name}"
      end

      # @private since AR 4.2
      def visit_TableDefinition(o)
        name = o.name
        create_sql = "CREATE#{' TEMPORARY' if o.temporary} TABLE #{quote_table_name(name)} "

        statements = o.columns.map { |c| accept c }
        statements.concat(o.indexes.map { |column_name, options| index_in_create(name, column_name, options) })

        create_sql << "(#{statements.join(', ')}) " if statements.present?
        create_sql << "#{o.options}"
        create_sql << " AS #{@conn.to_sql(o.as)}" if o.as
        create_sql
      end

      private

      def add_column_position!(sql, options)
        if options[:first]
          sql << " FIRST"
        elsif options[:after]
          sql << " AFTER #{quote_column_name(options[:after])}"
        end
        sql
      end

      def column_options(o)
        column_options = {}
        column_options[:null] = o.null unless o.null.nil?
        column_options[:default] = o.default unless o.default.nil?
        column_options[:column] = o
        column_options[:first] = o.first
        column_options[:after] = o.after
        column_options
      end

      def index_in_create(table_name, column_name, options)
        index_name, index_type, index_columns, index_options, index_algorithm, index_using = @conn.add_index_options(table_name, column_name, options)
        "#{index_type} INDEX #{quote_column_name(index_name)} #{index_using} (#{index_columns})#{index_options} #{index_algorithm}"
      end

    end

    def schema_creation; SchemaCreation.new self end

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
      select_one("SELECT DATABASE() as db")['db']
    end

    def truncate(table_name, name = nil)
      execute "TRUNCATE TABLE #{quote_table_name(table_name)}", name
    end

    # @override
    def create_table(name, options = {})
      super(name, { :options => "ENGINE=InnoDB" }.merge(options))
    end

    def drop_table(table_name, options = {})
      execute "DROP#{' TEMPORARY' if options[:temporary]} TABLE #{quote_table_name(table_name)}"
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
    def rename_index(table_name, old_name, new_name)
      if supports_rename_index?
        validate_index_length!(table_name, new_name) if respond_to?(:validate_index_length!)
        execute "ALTER TABLE #{quote_table_name(table_name)} RENAME INDEX #{quote_table_name(old_name)} TO #{quote_table_name(new_name)}"
      else
        super
      end
    end

    # @private
    ForeignKeyDefinition = ::ActiveRecord::ConnectionAdapters::ForeignKeyDefinition if ::ActiveRecord::ConnectionAdapters.const_defined? :ForeignKeyDefinition

    # @override
    def supports_foreign_keys?; true end

    def foreign_keys(table_name)
      fk_info = select_all "" <<
        "SELECT fk.referenced_table_name as 'to_table' " <<
              ",fk.referenced_column_name as 'primary_key' " <<
              ",fk.column_name as 'column' " <<
              ",fk.constraint_name as 'name' " <<
        "FROM information_schema.key_column_usage fk " <<
        "WHERE fk.referenced_column_name is not null " <<
          "AND fk.table_schema = '#{current_database}' " <<
          "AND fk.table_name = '#{table_name}'"

      create_table_info = select_one("SHOW CREATE TABLE #{quote_table_name(table_name)}")["Create Table"]

      fk_info.map! do |row|
        options = {
          :column => row['column'], :name => row['name'], :primary_key => row['primary_key']
        }
        options[:on_update] = extract_foreign_key_action(create_table_info, row['name'], "UPDATE")
        options[:on_delete] = extract_foreign_key_action(create_table_info, row['name'], "DELETE")

        ForeignKeyDefinition.new(table_name, row['to_table'], options)
      end
    end

    def extract_foreign_key_action(structure, name, action)
      if structure =~ /CONSTRAINT #{quote_column_name(name)} FOREIGN KEY .* REFERENCES .* ON #{action} (CASCADE|SET NULL|RESTRICT)/
        case $1
        when 'CASCADE'; :cascade
        when 'SET NULL'; :nullify
        end
      end
    end
    private :extract_foreign_key_action

    def change_column_default(table_name, column_name, default)
      column = column_for(table_name, column_name)
      change_column table_name, column_name, column.sql_type, :default => default
    end

    def change_column_null(table_name, column_name, null, default = nil)
      column = column_for(table_name, column_name)

      unless null || default.nil?
        execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
      end

      change_column table_name, column_name, column.sql_type, :null => null
    end

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

    # @private
    def change_column(table_name, column_name, type, options = {})
      execute("ALTER TABLE #{quote_table_name(table_name)} #{change_column_sql(table_name, column_name, type, options)}")
    end

    # @override
    def rename_column(table_name, column_name, new_column_name)
      options = {}

      if column = columns(table_name).find { |c| c.name == column_name.to_s }
        type = column.type
        options[:default] = column.default if type != :text && type != :binary
        options[:null] = column.null
      else
        raise ActiveRecordError, "No such column: #{table_name}.#{column_name}"
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
    end

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

    # Maps logical Rails types to MySQL-specific data types.
    def type_to_sql(type, limit = nil, precision = nil, scale = nil)
      case type.to_s
      when 'binary'
        case limit
        when 0..0xfff;           "varbinary(#{limit})"
        when nil;                "blob"
        when 0x1000..0xffffffff; "blob(#{limit})"
        else raise(ActiveRecordError, "No binary type has character length #{limit}")
        end
      when 'integer'
        case limit
        when 1; 'tinyint'
        when 2; 'smallint'
        when 3; 'mediumint'
        when nil, 4, 11; 'int(11)'  # compatibility with MySQL default
        when 5..8; 'bigint'
        else raise(ActiveRecordError, "No integer type has byte size #{limit}")
        end
      when 'text'
        case limit
        when 0..0xff;               'tinytext'
        when nil, 0x100..0xffff;    'text'
        when 0x10000..0xffffff;     'mediumtext'
        when 0x1000000..0xffffffff; 'longtext'
        else raise(ActiveRecordError, "No text type has character length #{limit}")
        end
      when 'datetime'
        return super unless precision

        case precision
          when 0..6; "datetime(#{precision})"
          else raise(ActiveRecordError, "No datetime type has precision of #{precision}. The allowed range of precision is from 0 to 6.")
        end
      else
        super
      end
    end

    # @override
    def empty_insert_statement_value
      "VALUES ()"
    end

    # @note since AR 4.2
    def valid_type?(type)
      ! native_database_types[type].nil?
    end

    def clear_cache!
      super
      reload_type_map
    end

    # @private since AR 4.2
    def prepare_column_options(column, types)
      spec = super
      spec.delete(:limit) if column.type == :boolean
      spec
    end

    # @private
    Type = ActiveRecord::Type

    protected

    # @private
    def initialize_type_map(m)
      super

      register_class_with_limit m, %r(char)i, MysqlString

      m.register_type %r(tinytext)i,   Type::Text.new(:limit => 2**8 - 1)
      m.register_type %r(tinyblob)i,   Type::Binary.new(:limit => 2**8 - 1)
      m.register_type %r(text)i,       Type::Text.new(:limit => 2**16 - 1)
      m.register_type %r(blob)i,       Type::Binary.new(:limit => 2**16 - 1)
      m.register_type %r(mediumtext)i, Type::Text.new(:limit => 2**24 - 1)
      m.register_type %r(mediumblob)i, Type::Binary.new(:limit => 2**24 - 1)
      m.register_type %r(longtext)i,   Type::Text.new(:limit => 2**32 - 1)
      m.register_type %r(longblob)i,   Type::Binary.new(:limit => 2**32 - 1)
      m.register_type %r(^float)i,     Type::Float.new(:limit => 24)
      m.register_type %r(^double)i,    Type::Float.new(:limit => 53)

      register_integer_type m, %r(^bigint)i,    :limit => 8
      register_integer_type m, %r(^int)i,       :limit => 4
      register_integer_type m, %r(^mediumint)i, :limit => 3
      register_integer_type m, %r(^smallint)i,  :limit => 2
      register_integer_type m, %r(^tinyint)i,   :limit => 1

      m.alias_type %r(tinyint\(1\))i,  'boolean' if emulate_booleans
      m.alias_type %r(set)i,           'varchar'
      m.alias_type %r(year)i,          'integer'
      m.alias_type %r(bit)i,           'binary'

      m.register_type(%r(datetime)i) do |sql_type|
        precision = extract_precision(sql_type)
        MysqlDateTime.new(:precision => precision)
      end

      m.register_type(%r(enum)i) do |sql_type|
        limit = sql_type[/^enum\((.+)\)/i, 1].split(',').
            map{|enum| enum.strip.length - 2}.max
        MysqlString.new(:limit => limit)
      end
    end

    # @private
    def register_integer_type(mapping, key, options)
      mapping.register_type(key) do |sql_type|
        if /unsigned/i =~ sql_type
          Type::UnsignedInteger.new(options)
        else
          Type::Integer.new(options)
        end
      end
    end

    # MySQL is too stupid to create a temporary table for use subquery, so we have
    # to give it some prompting in the form of a subsubquery. Ugh!
    # @note since AR 4.2
    def subquery_for(key, select)
      subsubselect = select.clone
      subsubselect.projections = [key]

      subselect = Arel::SelectManager.new(select.engine)
      subselect.project Arel.sql(key.name)
      subselect.from subsubselect.as('__active_record_temp')
    end

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

    def mariadb?; !! ( full_version =~ /mariadb/i ) end

    def version
      return @version ||= begin
        version = []
        java_connection = jdbc_connection(true)
        if java_connection.java_class.name == 'com.mysql.jdbc.ConnectionImpl'
          version << jdbc_connection.serverMajorVersion
          version << jdbc_connection.serverMinorVersion
          version << jdbc_connection.serverSubMinorVersion
        else
          if match = full_version.match(/^(\d+)\.(\d+)\.(\d+)/)
            version << match[1].to_i
            version << match[2].to_i
            version << match[3].to_i
          end
        end
        version.freeze
      end
    end

    # @private
    def emulate_booleans; ::ArJdbc::MySQL.emulate_booleans?; end # due AR 4.2
    public :emulate_booleans

    # @private
    class MysqlDateTime < Type::DateTime
      private

      def has_precision?
        precision || 0
      end
    end

    # @private
    class MysqlString < Type::String
      def type_cast_for_database(value)
        case value
        when true then "1"
        when false then "0"
        else super
        end
      end

      private

      def cast_value(value)
        case value
        when true then "1"
        when false then "0"
        else super
        end
      end
    end

  end
end

module ActiveRecord
  class ConnectionAdapters::AbstractMysqlAdapter
    # FIXME: this is to work around abstract mysql having 4 arity but core wants to pass 3
    # FIXME: Missing the logic from original module.
    def initialize(connection, logger, config)
      super(connection, logger, config)
    end
  end
  module ConnectionAdapters
    # Remove any vestiges of core/Ruby MySQL adapter
    remove_const(:Mysql2Adapter) if const_defined?(:Mysql2Adapter)

    class Mysql2Adapter < AbstractMysqlAdapter
      ADAPTER_NAME = 'Mysql2'.freeze

      include ArJdbc::Abstract::Core
      include ArJdbc::Abstract::ConnectionManagement
      include ArJdbc::Abstract::DatabaseStatements
      include ArJdbc::Abstract::StatementCache
      include ArJdbc::Abstract::TransactionSupport

      def initialize(connection, logger, connection_options, config)
        super(connection, logger, config)
      end

      def supports_json?
        !mariadb? && version >= '5.7.8'
      end

      def supports_comments?
        true
      end

      def supports_comments_in_create?
        true
      end

      def supports_savepoints?
        true
      end

      # HELPER METHODS ===========================================

      def each_hash(result) # :nodoc:
        if block_given?
          # FIXME: This is C in mysql2 gem and I just made simplest Ruby
          result.each do |row|
            new_hash = {}
            row.each { |k, v| new_hash[k.to_sym] = v }
            yield new_hash
          end
        else
          to_enum(:each_hash, result)
        end
      end

      def clear_cache!
        # FIXME: local cache of statements missing
      end

      def error_number(exception)
        exception.error_number if exception.respond_to?(:error_number)
      end

      #--
      # QUOTING ==================================================
      #++

      def quote_string(string)
        string.gsub(/[\x00\n\r\\\'\"]/, '\\\\\0')
      end

      private

      def connect
        @connection = Mysql2::Client.new(@config)
        configure_connection
      end

      def configure_connection
        @connection.query_options.merge!(:as => :array)
        super
      end

      def full_version
        @full_version ||= begin
          result = execute 'SELECT VERSION()', 'SCHEMA'
          result.first.values.first # [{"VERSION()"=>"5.5.37-0ubuntu..."}]
        end
      end

      def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil)
        last_id = if without_prepared_statement?(binds)
                    log(sql, name) { @connection.execute_insert(sql) }
                  else
                    log(sql, name, binds) { @connection.execute_insert(sql, binds) }
                  end
        # FIXME: execute_insert and executeUpdate mapping key results is very varied and I am wondering
        # if AR is now much more consistent.  I worked around by manually making a result here.
        ::ActiveRecord::Result.new(nil, [[last_id]])
      end
      alias insert_sql exec_insert

      def arel_visitor # :nodoc:
        Arel::Visitors::MySQL.new(self)
      end

      # By default, the MysqlAdapter will consider all columns of type
      # __tinyint(1)__ as boolean. If you wish to disable this :
      # ```
      #   ActiveRecord::ConnectionAdapters::Mysql[2]Adapter.emulate_booleans = false
      # ```
      def self.emulate_booleans?; ::ArJdbc::MySQL.emulate_booleans?; end
      def self.emulate_booleans;  ::ArJdbc::MySQL.emulate_booleans?; end # native adapter
      def self.emulate_booleans=(emulate); ::ArJdbc::MySQL.emulate_booleans = emulate; end

      def jdbc_connection_class(spec)
        ::ArJdbc::MySQL.jdbc_connection_class
      end

      def jdbc_column_class
        ::ActiveRecord::ConnectionAdapters::MySQL::Column
      end

    end

#    remove_const(:Mysql2Column) if const_defined?(:Mysql2Column)
#    Mysql2Column = Mysql2Adapter::Column
  end

  # FIXME: Not sure how this is scoped or whether we should use it or just alias it to our
  # JDBCError.
  class ::Mysql2
    class Error < Exception
      def initialize(*)
        super("error")
      end
    end
  end
end
