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
    new_task.comment = old_comment if old_comment
    new_task.actions.concat(old_actions) if old_actions
    new_task.prerequisites.concat(old_prereqs) if old_prereqs
    new_task
  end

end

namespace :db do

  def rails_env
    defined?(Rails.env) ? Rails.env : ( RAILS_ENV || 'development' )
  end

  if defined? adapt_jdbc_config
    ArJdbc.warn "double loading #{__FILE__} please delete lib/tasks/jdbc.rake if present!"
  end

  def adapt_jdbc_config(config)
    return config unless config['adapter']
    config.merge 'adapter' => config['adapter'].sub(/^jdbc/, '')
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
        @current_config ||= ENV['DATABASE_URL'] ?
          database_url_config : ActiveRecord::Base.configurations[options[:env]]
      end
    end

    def database_url_config(url = ENV['DATABASE_URL'])
      # NOTE: ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver
      # since AR 4.0 that is handled by DatabaseTasks - only care about 2.3/3.x :
      unless defined? ActiveRecord::Base::ConnectionSpecification::Resolver
        raise "DATABASE_URL not supported on ActiveRecord #{ActiveRecord::VERSION::STRING}"
      end
      resolver = ActiveRecord::Base::ConnectionSpecification::Resolver.new(url, {})
      resolver.spec.config.stringify_keys
    end

  end

end

require 'arjdbc/tasks/database_tasks'

if defined? ActiveRecord::Tasks::DatabaseTasks # 4.0
  load File.expand_path('databases4.rake', File.dirname(__FILE__))
else # 3.x / 2.3
  load File.expand_path('databases3.rake', File.dirname(__FILE__))
end
