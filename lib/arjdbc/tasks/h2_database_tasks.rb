require 'arjdbc/tasks/hsqldb_database_tasks'

module ArJdbc
  module Tasks
    class H2DatabaseTasks < HSQLDBDatabaseTasks

      protected

      # @override
      def do_drop_database(config)
        # ActiveRecord::JDBCError: org.h2.jdbc.JdbcSQLException:
        # Database is already closed (to disable automatic closing at VM
        # shutdown, add ";DB_CLOSE_ON_EXIT=FALSE" to the db URL) [90121-170]:
        # SHUTDOWN COMPACT
        #
        # connection.shutdown
        connection.drop_database resolve_database(config)
      end

      # @override
      def delete_database_files(config)
        return unless db_base = database_base_name(config)
        for suffix in [ '.h2,db', '.mv.db', '.lock.db', '.trace.db' ]
          db_file = "#{db_base}#{suffix}"
          File.delete(db_file) if File.exist?(db_file)
        end
      end

    end
  end
end