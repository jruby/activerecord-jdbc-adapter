require 'arjdbc/tasks/jdbc_database_tasks'

module ArJdbc
  module Tasks
    class HSQLDBDatabaseTasks < JdbcDatabaseTasks

      def create
        establish_connection(config)
        ActiveRecord::Base.connection
      end

      def drop
        error = nil
        begin
          establish_connection(config)
          do_drop_database(config)
        rescue => e
          error = e
          raise error
        ensure
          begin
            keep_db_files = ENV['KEEP_DB_FILES'] && ENV['KEEP_DB_FILES'] != 'false'
            delete_database_files(config) unless keep_db_files
          rescue => e
            raise e unless error
          end
        end
      end
      alias :purge :drop

      protected

      def do_drop_database(config)
        connection.drop_database resolve_database(config)
        connection.shutdown
      end

      def delete_database_files(config)
        return unless db_base = database_base_name(config)
        Dir.glob("#{db_base}.*").each do |file|
          # test.hsqldb.tmp (dir)
          # test.hsqldb.lck
          # test.hsqldb.lobs
          # test.hsqldb.script
          # test.hsqldb.properties
          if File.directory?(file)
            FileUtils.rm_r(file)
            FileUtils.rmdir(file)
          else
            FileUtils.rm(file)
          end
        end
        if File.exist?(db_base)
          FileUtils.rm_r(db_base)
          FileUtils.rmdir(db_base)
        end
      end

      private

      def database_base_name(config)
        db = resolve_database(config, true)
        db[0, 4] == 'mem:' ? nil : begin
          expand_path db[0, 5] == 'file:' ? db[5..-1] : db
        end
      end

    end
  end
end