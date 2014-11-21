require 'arjdbc/db2/adapter'

module ArJdbc
  module AS400
    include DB2

    # @private
    def self.extended(adapter); DB2.extended(adapter); end

    # @private
    def self.initialize!; DB2.initialize!; end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_connection_class
    def self.jdbc_connection_class; DB2.jdbc_connection_class; end

    # @see ActiveRecord::ConnectionAdapters::Jdbc::ArelSupport
    def self.arel_visitor_type(config = nil); DB2.arel_visitor_type(config); end

    def self.column_selector
      [ /as400/i, lambda { |config, column| column.extend(Column) } ]
    end

    # Boolean emulation can be disabled using :
    #
    #   ArJdbc::AS400.emulate_booleans = false
    #
    def self.emulate_booleans; DB2.emulate_booleans; end
    def self.emulate_booleans=(emulate); DB2.emulate_booleans = emulate; end

    ADAPTER_NAME = 'AS400'.freeze

    def adapter_name
      ADAPTER_NAME
    end

    # @override
    def prefetch_primary_key?(table_name = nil)
      # TRUE if the table has no identity column
      names = table_name.upcase.split(".")
      sql = "SELECT 1 FROM SYSIBM.SQLPRIMARYKEYS WHERE "
      sql << "TABLE_SCHEM = '#{names.first}' AND " if names.size == 2
      sql << "TABLE_NAME = '#{names.last}'"
      select_one(sql).nil?
    end

    # @override
    def rename_column(table_name, column_name, new_column_name)
      raise NotImplementedError, "rename_column is not supported on IBM iSeries"
    end

    # @override
    def execute_table_change(sql, table_name, name = nil)
      execute_and_auto_confirm(sql, name)
    end

    # holy moly batman! all this to tell AS400 "yes i am sure"
    def execute_and_auto_confirm(sql, name = nil)

      begin
        @connection.execute_update "call qsys.qcmdexc('QSYS/CHGJOB INQMSGRPY(*SYSRPYL)',0000000031.00000)"
        @connection.execute_update "call qsys.qcmdexc('ADDRPYLE SEQNBR(9876) MSGID(CPA32B2) RPY(''I'')',0000000045.00000)"
      rescue Exception => e
        raise "Could not call CHGJOB INQMSGRPY(*SYSRPYL) and ADDRPYLE SEQNBR(9876) MSGID(CPA32B2) RPY('I').\n" +
              "Do you have authority to do this?\n\n#{e.inspect}"
      end

      begin
        result = execute(sql, name)
      rescue Exception
        raise
      else
        # Return if all work fine
        result
      ensure

        # Ensure default configuration restoration
        begin
          @connection.execute_update "call qsys.qcmdexc('QSYS/CHGJOB INQMSGRPY(*DFT)',0000000027.00000)"
          @connection.execute_update "call qsys.qcmdexc('RMVRPYLE SEQNBR(9876)',0000000021.00000)"
        rescue Exception => e
          raise "Could not call CHGJOB INQMSGRPY(*DFT) and RMVRPYLE SEQNBR(9876).\n" +
                    "Do you have authority to do this?\n\n#{e.inspect}"
        end

      end
    end
    private :execute_and_auto_confirm

    # disable all schemas browsing when default schema is specified
    def table_exists?(name)
      return false unless name
      schema ? @connection.table_exists?(name, schema) : @connection.table_exists?(name)
    end

    DRIVER_NAME = 'com.ibm.as400.access.AS400JDBCDriver'.freeze

    # @private
    # @deprecated no longer used
    def as400?
      true
    end

    private

    # @override
    def db2_schema
      @db2_schema = false unless defined? @db2_schema
      return @db2_schema if @db2_schema != false
      @db2_schema =
        if config[:schema].present?
          config[:schema]
        elsif config[:jndi].present?
          # Only found method to set db2_schema from jndi
          result = select_one("SELECT CURRENT_SCHEMA FROM SYSIBM.SYSDUMMY1")
          schema = result['00001']
          # If the connection uses the library list schema name will be nil
          if schema == '*LIBL'
            schema = nil
          end
          schema
        else
          # AS400 implementation takes schema from library name (last part of URL)
          # jdbc:as400://localhost/schema;naming=system;libraries=lib1,lib2
          schema = nil
          split = config[:url].split('/')
          # Return nil if schema isn't defined
          schema = split.last.split(';').first.strip if split.size == 4
          schema
        end
    end

  end
end
