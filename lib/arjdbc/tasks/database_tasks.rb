module ArJdbc
  module Tasks

    def self.register_tasks(pattern, task)
      ActiveRecord::Tasks::DatabaseTasks.register_task(pattern, task)
    end

    # support adapter: mariadb (as if it were mysql)
    register_tasks(/mariadb/, ActiveRecord::Tasks::MySQLDatabaseTasks)

    require 'arjdbc/tasks/jdbc_database_tasks'
    require 'arjdbc/tasks/mssql_database_tasks'
    #require 'arjdbc/tasks/db2_database_tasks'
    #require 'arjdbc/tasks/derby_database_tasks'
    #require 'arjdbc/tasks/h2_database_tasks'
    #require 'arjdbc/tasks/hsqldb_database_tasks'

    # re-invent built-in (but deprecated on 4.0) tasks :
    # tasks for custom (JDBC) adapters :
    #register_tasks(/db2/, DB2DatabaseTasks)
    #register_tasks(/derby/, DerbyDatabaseTasks)
    #register_tasks(/h2/, H2DatabaseTasks)
    #register_tasks(/hsqldb/, HSQLDBDatabaseTasks)
    # (default) generic JDBC task :
    register_tasks(/^jdbc$/, JdbcDatabaseTasks)
    register_tasks(/sqlserver/, MSSQLDatabaseTasks)

    # NOTE: no need to register "built-in" adapters such as MySQL

  end
end
