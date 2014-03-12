require 'arjdbc/tasks/jdbc_database_tasks'

module ArJdbc
  module Tasks
    class MSSQLDatabaseTasks < JdbcDatabaseTasks

      def purge
        test = deep_dup(configuration)
        test_database = resolve_database(test)
        test['database'] = 'master'
        establish_connection(test)
        connection.recreate_database!(test_database)
      end

      def structure_dump(filename)
        config = config_from_url_if_needed
        `smoscript -s #{config['host']} -d #{config['database']} -u #{config['username']} -p #{config['password']} -f #{filename} -A -U`
      end

      def structure_load(filename)
        config = config_from_url_if_needed
        `sqlcmd -S #{config['host']} -d #{config['database']} -U #{config['username']} -P #{config['password']} -i #{filename}`
      end

      private

      def config_from_url_if_needed
        config = self.config
        if config['url'] && ! config.key?('database')
          config = config_from_url(config['url'])
        end
        config
      end

      def deep_dup(hash)
        dup = hash.dup
        dup.each_pair do |k,v|
          tv = dup[k]
          dup[k] = tv.is_a?(Hash) && v.is_a?(Hash) ? deep_dup(tv) : v
        end
        dup
      end

    end
  end
end