require 'arjdbc/db2/adapter'

module ArJdbc
  module AS400
    include DB2
    
    def self.extended(base); DB2.extended(base); end
    
    def self.column_selector
      [ /as400/i, lambda { |cfg, column| column.extend(::ArJdbc::AS400::Column) } ]
    end

    def self.jdbc_connection_class; DB2.jdbc_connection_class; end

    def self.arel2_visitors(config)
      visitors = DB2.arel2_visitors(config).dup
      visitors['as400'] = ::Arel::Visitors::DB2
      visitors
    end

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
    def rename_column(table_name, column_name, new_column_name) # :nodoc:
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

      result = execute(sql, name)

      begin
        @connection.execute_update "call qsys.qcmdexc('QSYS/CHGJOB INQMSGRPY(*DFT)',0000000027.00000)"
        @connection.execute_update "call qsys.qcmdexc('RMVRPYLE SEQNBR(9876)',0000000021.00000)"
      rescue Exception => e
        raise "Could not call CHGJOB INQMSGRPY(*DFT) and RMVRPYLE SEQNBR(9876).\n" +
              "Do you have authority to do this?\n\n#{e.inspect}"
      end
      result
    end
    private :execute_and_auto_confirm
    
    DRIVER_NAME = 'com.ibm.as400.access.AS400JDBCDriver'.freeze
    
    # @deprecated no longer used
    def as400?
      true
    end

    private
    
    # @override
    def db2_schema
      @db2_schema = nil unless defined? @db2_schema
      return @db2_schema unless @db2_schema.nil?
      @db2_schema = 
        if config[:schema].present?
          config[:schema]
        else
          # AS400 implementation takes schema from library name (last part of URL)
          # jdbc:as400://localhost/schema;naming=system;libraries=lib1,lib2
          config[:url].split('/').last.split(';').first.strip
        end
    end
    
  end
end
