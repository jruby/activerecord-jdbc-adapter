module ArJdbc
  module Tasks
    class MSSQLDatabaseTasks < JdbcDatabaseTasks

      def purge
        test = configuration.deep_dup
        test_database = test['database']
        test['database'] = 'master'
        establish_connection(test)
        connection.recreate_database!(test_database)
      end

      def structure_dump(filename)
        `smoscript -s #{config['host']} -d #{config['database']} -u #{config['username']} -p #{config['password']} -f #{filename} -A -U`
      end

      def structure_load(filename)
        `sqlcmd -S #{config['host']} -d #{config['database']} -U #{config['username']} -P #{config['password']} -i #{filename}`
      end
      
    end
  end
end