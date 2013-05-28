module ArJdbc
  module Tasks
    
    if defined? ActiveRecord::Tasks::DatabaseTasks # AR-4.x
    
      def self.register_tasks(pattern, task)
        ActiveRecord::Tasks::DatabaseTasks.register_task(pattern, task)
      end
      
    else
      
      @@tasks = {}

      def self.register_tasks(pattern, task)
        @@tasks[pattern] = task
      end

      def self.tasks_instance(config)
        adapter = config['adapter']
        key = @@tasks.keys.detect { |pattern| adapter[pattern] }
        ( @@tasks[key] || JdbcDatabaseTasks ).new(config)
      end
      
    end
    
    require 'arjdbc/tasks/jdbc_database_tasks'
    require 'arjdbc/tasks/db2_database_tasks'
    require 'arjdbc/tasks/derby_database_tasks'
    require 'arjdbc/tasks/h2_database_tasks'
    require 'arjdbc/tasks/hsqldb_database_tasks'
    require 'arjdbc/tasks/mssql_database_tasks'
    require 'arjdbc/tasks/oracle_database_tasks'
    
    # re-invent built-in (but deprecated on 4.0) tasks :
    register_tasks(/(mssql|sqlserver)/i, MSSQLDatabaseTasks)
    register_tasks(/(oci|oracle)/i, OracleDatabaseTasks)
    # tasks for custom (JDBC) adapters :
    register_tasks(/db2/i, DB2DatabaseTasks)
    register_tasks(/derby/i, DerbyDatabaseTasks)
    register_tasks(/h2/i, H2DatabaseTasks)
    register_tasks(/hsqldb/i, HSQLDBDatabaseTasks)
    # (default) generic JDBC task :
    register_tasks(/^jdbc$/i, JdbcDatabaseTasks)
    
    # NOTE: no need to register "built-in" adapters such as MySQL
    # - on 4.0 these are registered and will be instantiated
    # - while on 2.3/3.x we keep the AR built-in task behavior
    
  end
end