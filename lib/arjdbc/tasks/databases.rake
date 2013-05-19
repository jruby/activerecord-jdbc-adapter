raise "ArJdbc needs rake 0.9.x or newer" unless Rake.const_defined?(:VERSION)

Rake::DSL.module_eval do
  
  def redefine_task(*args, &block)
    if Hash === args.first
      task_name = args.first.keys[0]
      old_prereqs = false # leave as specified
    else
      task_name = args.first; old_prereqs = []
      # args[0] = { task_name => old_prereqs }
    end
    
    full_name = Rake::Task.scope_name(Rake.application.current_scope, task_name)
    
    if old_task = Rake.application.lookup(task_name)
      old_comment = old_task.full_comment
      old_prereqs = old_task.prerequisites.dup if old_prereqs
      old_actions = old_task.actions.dup
      old_actions.shift # remove the main 'action' block - we're redefining it
      # old_task.clear_prerequisites if old_prereqs
      # old_task.clear_actions
      # remove the (old) task instance from the application :
      Rake.application.send(:instance_variable_get, :@tasks)[full_name.to_s] = nil
    else
      # raise "could not find rake task with (full) name '#{full_name}'"
    end
    
    new_task = task(*args, &block)
    new_task.comment = old_comment # if old_comment
    new_task.actions.concat(old_actions) if old_actions
    new_task.prerequisites.concat(old_prereqs) if old_prereqs
    new_task
  end
  
end

namespace :db do

  def rails_env
    defined?(Rails.env) ? Rails.env : ( RAILS_ENV || 'development' )
  end
  
  if defined? ActiveRecord::Tasks::DatabaseTasks # 4.0
    
    def current_config(options = {})
      ActiveRecord::Tasks::DatabaseTasks.current_config(options)
    end
    
  else # 3.x / 2.3
        
    def current_config(options = {}) # not on 2.3
      options = { :env => rails_env }.merge! options
      if options[:config]
        @current_config = options[:config]
      else
        @current_config ||= 
          if ENV['DATABASE_URL']
            database_url_config
          else
            ActiveRecord::Base.configurations[options[:env]]
          end
      end
    end

    def database_url_config(url = ENV['DATABASE_URL'])
      unless defined? ActiveRecord::Base::ConnectionSpecification::Resolver
        raise "ENV['DATABASE_URL'] not support on AR #{ActiveRecord::VERSION::STRING}"
      end
      @database_url_config ||=
        ActiveRecord::Base::ConnectionSpecification::Resolver.new(url, {}).spec.config.stringify_keys
    end
    
  end

  namespace :test do

    # desc "Empty the test database"
    redefine_task(:purge) do # |rails_task|
      config = ActiveRecord::Base.configurations['test']
      case config['adapter']
      when /mysql/
        ActiveRecord::Base.establish_connection(:test)
        options = mysql_creation_options(config) rescue config
        ActiveRecord::Base.connection.recreate_database(config['database'], options)
        
      when /postgresql/
        ActiveRecord::Base.clear_active_connections!
        # drop_database(config) :
        ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres', 'schema_search_path' => 'public'))
        ActiveRecord::Base.connection.drop_database config['database']
        # create_database(config) :
        encoding = config[:encoding] || ENV['CHARSET'] || 'utf8'
        ActiveRecord::Base.connection.create_database(config['database'], config.merge('encoding' => encoding))
      when /sqlite/
        dbfile = config['database']
        File.delete(dbfile) if File.exist?(dbfile)
      when /mssql|sqlserver/
        test = ActiveRecord::Base.configurations.deep_dup['test']
        test_database = test['database']
        test['database'] = 'master'
        ActiveRecord::Base.establish_connection(test)
        ActiveRecord::Base.connection.recreate_database!(test_database)
      when /oracle/
        ActiveRecord::Base.establish_connection(:test)
        ActiveRecord::Base.connection.structure_drop.split(";\n\n").each do |ddl|
          ActiveRecord::Base.connection.execute(ddl)
        end
      else
        ActiveRecord::Base.establish_connection(:test)
        db_name = ActiveRecord::Base.connection.database_name
        ActiveRecord::Base.connection.recreate_database(db_name, config)
      end
    end
    
  end
  
end

if defined? ActiveRecord::Tasks::DatabaseTasks # 4.0
  load File.expand_path('databases4.rake', File.dirname(__FILE__))
else # 3.x / 2.3
  load File.expand_path('databases3.rake', File.dirname(__FILE__))
end
