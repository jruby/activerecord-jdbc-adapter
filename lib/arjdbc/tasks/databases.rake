require 'arjdbc/tasks/database_tasks'

module ActiveRecord::Tasks

  DatabaseTasks.module_eval do

    # @override patched to adapt jdbc configuration
    def each_current_configuration(environment)
      environments = [environment]
      environments << 'test' if environment == 'development'

      configurations = ActiveRecord::Base.configurations.values_at(*environments)
      configurations.compact.each do |config|
        yield adapt_jdbc_config(config) unless config['database'].blank?
      end
    end

    # @override patched to adapt jdbc configuration
    def each_local_configuration
      ActiveRecord::Base.configurations.each_value do |config|
        next unless config['database']

        if local_database?(config)
          yield adapt_jdbc_config(config)
        else
          $stderr.puts "This task only modifies local databases. #{config['database']} is on a remote host."
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