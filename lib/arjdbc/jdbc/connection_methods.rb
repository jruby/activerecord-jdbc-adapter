module ArJdbc
  if ActiveRecord.const_defined? :ConnectionHandling # 4.0
    ConnectionMethods = ActiveRecord::ConnectionHandling
  else # 3.x
    ConnectionMethods = (class << ActiveRecord::Base; self; end)
  end
  ConnectionMethods.module_eval do

    def jdbc_connection(config)
      adapter_class = config[:adapter_class]
      adapter_class ||= begin
        adapter = config[:adapter]
        if ( adapter == 'jdbc' || adapter == 'jndi' ) && adapter = supported_adapter(config)
          warn "DEPRECATED: use 'adapter: #{adapter}' instead of the current 'adapter: jdbc' configuration"
        end
        ::ActiveRecord::ConnectionAdapters::JdbcAdapter
      end
      adapter_class.new(nil, logger, config)
    end

    def jndi_connection(config); jdbc_connection(config) end

    def embedded_driver(config)
      config[:username] ||= "sa"
      config[:password] ||= ""
      jdbc_connection(config)
    end

    private

    def jndi_config?(config)
      ::ActiveRecord::ConnectionAdapters::JdbcConnection.jndi_config?(config)
    end

    def supported_adapter(config)
      return unless driver = config[:driver]
      case driver
      when 'com.ibm.db2.jcc.DB2Driver' then 'db2'
      when /derby/ then 'derby' # 'org.apache.derby.jdbc.EmbeddedDriver'
      when 'org.firebirdsql.jdbc.FBDriver' then 'firebird'
      when 'org.h2.Driver' then 'h2'
      when 'org.hsqldb.jdbcDriver' then 'hsqldb'
      when 'net.sourceforge.jtds.jdbc.Driver' then 'mssql'
      when 'com.microsoft.sqlserver.jdbc.SQLServerDriver' then 'sqlserver'
      when /mysql/i then 'mysql' # 'com.mysql.jdbc.Driver'
      when /oracle/ then 'oracle' # 'oracle.jdbc.driver.OracleDriver'
      when /postgre/i then 'postgresql' # 'org.postgresql.Driver'
      when /sqlite/i then 'sqlite3' # 'org.sqlite.JDBC'
      else false
      end
    end

  end
end