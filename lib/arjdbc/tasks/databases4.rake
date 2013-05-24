require 'arjdbc/tasks/database_tasks'

module ActiveRecord::Tasks

  DatabaseTasks.module_eval do
    
    # re-invent built-in (but deprecated) tasks :
    register_task /(mssql|sqlserver)/i, ArJdbc::Tasks::MSSQLDatabaseTasks
    register_task /(oci|oracle)/i, ArJdbc::Tasks::OracleDatabaseTasks
    # tasks for custom (JDBC) adapters :
    register_task /derby/i, ArJdbc::Tasks::DerbyDatabaseTasks
    # (default) generic JDBC task :
    register_task /^jdbc$/i, ArJdbc::Tasks::JdbcDatabaseTasks
    
    # patched to adapt jdbc configuration
    def each_current_configuration(environment)
      environments = [environment]
      environments << 'test' if environment == 'development'

      configurations = ActiveRecord::Base.configurations.values_at(*environments)
      configurations.compact.each do |config|
        yield adapt_jdbc_config(config) unless config['database'].blank?
      end
    end

    # patched to adapt jdbc configuration
    def each_local_configuration
      ActiveRecord::Base.configurations.each_value do |config|
        next unless config['database']

        if local_database?(config)
          yield adapt_jdbc_config(config)
        else
          $stderr.puts "This task only modifies local databases. #{config['database']} is on a remote host."
        end
      end
    end

  end

  MySQLDatabaseTasks.class_eval do

    def error_class
      ActiveRecord::JDBCError
    end

  end
  
end