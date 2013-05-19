namespace :db do

  ActiveRecord::Tasks::DatabaseTasks.class_eval do # generic

    alias_method :previous_create, :create unless method_defined?(:previous_create)
    alias_method :previous_drop,   :drop   unless method_defined?(:previous_drop)

    def create(*args)
      config = args.first; args = args.dup
      args[0] = config.merge('adapter' => config['adapter'].sub(/^jdbc/, ''))
      previous_create *args
    end

    def drop(*args)
      config = args.first; args = args.dup
      args[0] = config.merge('adapter' => config['adapter'].sub(/^jdbc/, ''))
      previous_drop *args
    end

  end
  
  tasks = ActiveRecord::Tasks::DatabaseTasks.instance_variable_get :@tasks
  # NOTE: we mostly care about the holy 3 :
  # register_task(/mysql/, ActiveRecord::Tasks::MySQLDatabaseTasks)
  # register_task(/postgresql/, ActiveRecord::Tasks::PostgreSQLDatabaseTasks)
  # register_task(/sqlite/, ActiveRecord::Tasks::SQLiteDatabaseTasks)
  tasks.each do |name_pattern, task_class|
    task_class.class_eval do # e.g. ActiveRecord::Tasks::MySQLDatabaseTasks

      alias_method :previous_create, :create unless method_defined?(:previous_create)
      alias_method :previous_drop,   :drop   unless method_defined?(:previous_drop)

      def create(*args)
        config = @configuration
        @configuration = config.merge('adapter' => config['adapter'].sub(/^jdbc/, ''))
        previous_create *args
      end

      def drop(*args)
        config = @configuration
        @configuration = config.merge('adapter' => config['adapter'].sub(/^jdbc/, ''))
        previous_drop *args
      end
      alias :purge :drop if name_pattern.source =~ /sqlite/i

      def error_class
        ActiveRecord::JDBCError
      end if name_pattern.source =~ /mysql/i
      
    end
  end

  def create_database(config)
    begin
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection
    rescue
      begin
        if url = config['url'] and url =~ /^(.*(?<!\/)\/)(?=\w)/
          url = $1
        end

        ActiveRecord::Base.establish_connection(config.merge({'database' => nil, 'url' => url}))
        ActiveRecord::Base.connection.create_database(config['database'], config)
        ActiveRecord::Base.establish_connection(config)
      rescue => e
        raise e if config['adapter'] && config['adapter'] !~ /mysql|postgresql|sqlite/
        ActiveRecord::Tasks::DatabaseTasks.create_current
      end
    end
  end

  def drop_database(config = nil)
    ActiveRecord::Tasks::DatabaseTasks.drop_current
  end

end
