module ArJdbc
  module Tasks

    if defined? ActiveRecord::Tasks::DatabaseTasks # AR-4.x

      def self.register_tasks(pattern, task)
        ActiveRecord::Tasks::DatabaseTasks.register_task(pattern, task)
      end

      register_tasks(/mariadb/, ActiveRecord::Tasks::MySQLDatabaseTasks)

      # patch-in lazy (auto) loading with AR registered tasks :
      module ActiveRecord::Tasks::DatabaseTasks
        def class_for_adapter(adapter)
          unless key = @tasks.keys.detect { |pattern| adapter[pattern] }
            raise DatabaseNotSupported, "Rake tasks not supported by '#{adapter}' adapter"
          end
          tasks = @tasks[key] || JdbcDatabaseTasks
          tasks = ArJdbc::Tasks.const_get(tasks) unless tasks.is_a?(Module)
          tasks
        end
      end

    else

      @@tasks = {}

      def self.register_tasks(pattern, task)
        @@tasks[pattern] = task
      end

      def self.tasks_instance(config); adapter = config['adapter']
        key = @@tasks.keys.detect { |pattern| adapter[pattern] }
        tasks = @@tasks[key] || JdbcDatabaseTasks
        tasks = const_get(tasks) unless tasks.is_a?(Module)
        tasks.new(config)
      end

    end

    autoload :JdbcDatabaseTasks, 'arjdbc/tasks/jdbc_database_tasks'
    autoload :DB2DatabaseTasks, 'arjdbc/tasks/db2_database_tasks'
    autoload :DerbyDatabaseTasks, 'arjdbc/tasks/derby_database_tasks'
    autoload :H2DatabaseTasks, 'arjdbc/tasks/h2_database_tasks'
    autoload :HSQLDBDatabaseTasks, 'arjdbc/tasks/hsqldb_database_tasks'
    autoload :MSSQLDatabaseTasks, 'arjdbc/tasks/mssql_database_tasks'
    autoload :OracleDatabaseTasks, 'arjdbc/tasks/oracle_database_tasks'

    # re-invent built-in (but deprecated on 4.0) tasks :
    register_tasks(/sqlserver/, :MSSQLDatabaseTasks)
    register_tasks(/(oci|oracle)/, :OracleDatabaseTasks)
    register_tasks(/mssql/, :MSSQLDatabaseTasks) # (built-in) alias
    # tasks for custom (JDBC) adapters :
    register_tasks(/db2/, :DB2DatabaseTasks)
    register_tasks(/derby/, :DerbyDatabaseTasks)
    register_tasks(/h2/, :H2DatabaseTasks)
    register_tasks(/hsqldb/, :HSQLDBDatabaseTasks)
    # (default) generic JDBC task :
    register_tasks(/^jdbc$/, :JdbcDatabaseTasks)

    # NOTE: no need to register "built-in" adapters such as MySQL
    # - on 4.0 these are registered and will be instantiated
    # - while on 2.3/3.x we keep the AR built-in task behavior

  end
end