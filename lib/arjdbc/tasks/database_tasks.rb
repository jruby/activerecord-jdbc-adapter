module ArJdbc
  module Tasks

    def self.register_tasks(pattern, task)
      ActiveRecord::Tasks::DatabaseTasks.register_task(pattern, task)
    end

    # support adapter: mariadb (as if it were mysql)
    register_tasks(/mariadb/, ActiveRecord::Tasks::MySQLDatabaseTasks)

    require 'arjdbc/tasks/jdbc_database_tasks'
    require 'arjdbc/tasks/sqlite_database_tasks_patch'
    register_tasks(/^jdbc$/, JdbcDatabaseTasks)

    # NOTE: no need to register "built-in" adapters such as MySQL

  end
end
