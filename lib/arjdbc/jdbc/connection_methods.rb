module ArJdbc
  if ActiveRecord.const_defined? :ConnectionHandling # 4.0
    ConnectionMethods = ActiveRecord::ConnectionHandling
  else # 3.x
    ConnectionMethods = (class << ActiveRecord::Base; self; end)
  end
  ConnectionMethods.module_eval do

    def jdbc_connection(config)
      adapter_class = config[:adapter_class] || begin
        if config[:adapter] == 'jdbc' && adapter = supported_adapter(config)
          ArJdbc.deprecate("please update your **adapter: jdbc** configuration to adapter: #{adapter}", true)
        end
        ::ActiveRecord::ConnectionAdapters::JdbcAdapter
      end
      adapter_class.new(nil, logger, config)
    end

    def jndi_connection(config)
      if config[:adapter] == 'jndi'
        ArJdbc.deprecate("please change your **adapter: jndi** configuration to " <<
            "the concrete adapter you're wish to use with jndi: '#{config[:jndi]}'", true)
      end
      jdbc_connection(config)
    end

    def embedded_driver(config)
      config[:username] ||= 'sa'
      config[:password] ||= ''
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
      when /mysql/ then 'mysql' # 'com.mysql.jdbc.Driver/NonRegisteringDriver'
      when /mariadb/ then 'mariadb' # 'org.mariadb.jdbc.Driver'
      when /oracle/ then 'oracle' # 'oracle.jdbc.driver.OracleDriver'
      when /postgre/i then 'postgresql' # 'org.postgresql.Driver'
      when /sqlite/i then 'sqlite3' # 'org.sqlite.JDBC'
      else false
      end
    end

  end
end