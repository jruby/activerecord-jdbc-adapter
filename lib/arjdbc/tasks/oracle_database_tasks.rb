require 'arjdbc/tasks/jdbc_database_tasks'

module ArJdbc
  module Tasks
    class OracleDatabaseTasks < JdbcDatabaseTasks

      def create
        print "Please provide the SYSTEM password for your oracle installation\n>"
        system_password = $stdin.gets.strip
        establish_connection(config.merge('username' => 'SYSTEM', 'password' => system_password))
        unless ( config = self.config ).key?('username')
          config = config_from_url(config['url']) if config['url']
        end
        begin
          connection.execute "CREATE USER #{config['username']} IDENTIFIED BY #{config['password']}"
        rescue => e
          if e.message =~ /ORA-01920/ # user name conflicts with another user or role name
            connection.execute "ALTER USER #{config['username']} IDENTIFIED BY #{config['password']}"
          else
            raise e
          end
        end
        connection.execute "GRANT unlimited tablespace TO #{config['username']}"
        connection.execute "GRANT create session TO #{config['username']}"
        connection.execute "GRANT create table TO #{config['username']}"
        connection.execute "GRANT create sequence TO #{config['username']}"
      end

      def drop
        self.class.load_enhanced_structure_dump
        establish_connection(config)
        connection.execute_structure_dump(connection.full_drop)
      end

      def purge
        self.class.load_enhanced_structure_dump
        establish_connection(:test)
        connection.execute_structure_dump(connection.full_drop)
        connection.execute("PURGE RECYCLEBIN") rescue nil
      end

      def structure_dump(filename)
        self.class.load_enhanced_structure_dump
        establish_connection(config)
        File.open(filename, "w:utf-8") { |f| f << connection.structure_dump }
      end

      def structure_load(filename)
        self.class.load_enhanced_structure_dump
        establish_connection(config)
        connection.execute_structure_dump(File.read(filename))
      end

      def self.load_enhanced_structure_dump
        unless defined? ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter
          ActiveRecord::ConnectionAdapters.module_eval do
            const_set :OracleEnhancedAdapter, ActiveRecord::ConnectionAdapters::OracleAdapter
          end
        end
        require 'arjdbc/tasks/oracle/enhanced_structure_dump'
      end

    end
  end
end