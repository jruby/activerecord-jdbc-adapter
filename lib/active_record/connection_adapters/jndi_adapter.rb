
module ActiveRecord #:nodoc:

  module ConnectionAdapters #:nodoc:
    
    # This adapter allows ActiveRecord to use JNDI to retrieve
    # a JDBC connection from a previously configured DataSource.
    # The ActiveRecord configuration looks like this:
    #
    #       ActiveRecord::Base.establish_connection(
    #         :adapter => 'jdbc',
    #         :jndi => 'java:comp/env/jdbc/test',
    #	      :driver => 'sqlserver'		
    #       )
    #
    # Right now, enough driver information needs to be supplied so that AR-JDBC
    # can genrate the right flavor of SQL. However, it's not necessary to know
    # exactly which driver is being used, just enough so the right SQL 
    # is generated.
    #
    class JndiConnection < JdbcConnection

      def initialize(config)
        @config = config
        jndi = @config[:jndi].to_s

        ctx = javax.naming.InitialContext.new
        ds = ctx.lookup(jndi)
        @connection = ds.connection
        set_native_database_types

        @stmts = {}
      rescue Exception => e
        raise "The driver encountered an error: #{e}"
      end

    end
  end
end

