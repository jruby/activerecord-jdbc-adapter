require 'arjdbc/tasks/jdbc_database_tasks'

module ArJdbc
  module Tasks
    class HSQLDBDatabaseTasks < JdbcDatabaseTasks

      def drop
        super # connection.drop_database
        connection.shutdown
        
        keep_db_files = ENV['KEEP_DB_FILES'] && ENV['KEEP_DB_FILES'] != 'false'
        unless keep_db_files
          return unless db_base = db_base_name(config)
          Dir.glob("#{db_base}.*").each do |file|
            # test.hsqldb.tmp (dir)
            # test.hsqldb.lck
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
      end
      alias :purge :drop
      
      private
      
      def db_base_name(config)
        db = config['database']
        db[0, 4] == 'mem:' ? nil : begin
          expand_path db[0, 4] == 'file:' ? db[4..-1] : db
        end
      end
      
    end
  end
end