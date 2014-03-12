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
        db_files = [ "#{db_base}.h2.db", "#{db_base}.lock.db", "#{db_base}.trace.db" ]
        db_files.each { |file| File.delete(file) if File.exist?(file) }
      end

    end
  end
end