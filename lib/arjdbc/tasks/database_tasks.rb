module ArJdbc
  module Tasks
    autoload :JdbcDatabaseTasks, 'arjdbc/tasks/jdbc_database_tasks'
    autoload :DerbyDatabaseTasks, 'arjdbc/tasks/derby_database_tasks'
    autoload :HSQLDBDatabaseTasks, 'arjdbc/tasks/hsqldb_database_tasks'
    autoload :MSSQLDatabaseTasks, 'arjdbc/tasks/mssql_database_tasks'
    autoload :OracleDatabaseTasks, 'arjdbc/tasks/oracle_database_tasks'
  end
end