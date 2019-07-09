require 'arjdbc/tasks/database_tasks'

module ActiveRecord::Tasks

  DatabaseTasks.module_eval do

    # @override patched to adapt jdbc configuration
    def each_current_configuration(environment, spec_name = nil)
      environments = [environment]
      environments << 'test' if environment == 'development'

      environments.each do |env|
        ActiveRecord::Base.configurations.configs_for(env_name: env).each do |db_config|
          next if spec_name && spec_name != db_config.spec_name

          yield adapt_jdbc_config(db_config.config), db_config.spec_name, env unless db_config.config['database'].blank?
        end
      end
    end

    # @override patched to adapt jdbc configuration
    def each_local_configuration
      ActiveRecord::Base.configurations.configs_for.each do |db_config|
        next unless db_config.config['database']

        if local_database?(db_config.config)
          yield adapt_jdbc_config(db_config.config)
        else
          $stderr.puts "This task only modifies local databases. #{db_config.config['database']} is on a remote host."
        end
      end
    end

    private

    def adapt_jdbc_config(config)
      return config unless config['adapter']
      config.merge 'adapter' => config['adapter'].sub(/^jdbc/, '')
    end

  end

  MySQLDatabaseTasks.class_eval do

    def error_class
      ActiveRecord::JDBCError
    end

  end if const_defined?(:MySQLDatabaseTasks)

end
