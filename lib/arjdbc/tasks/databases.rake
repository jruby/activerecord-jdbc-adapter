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
    Rails.env.to_s
  end

  if defined? adapt_jdbc_config
    ArJdbc.warn "double loading #{__FILE__} please delete lib/tasks/jdbc.rake if present!"
  end

  def adapt_jdbc_config(config)
    return config unless config['adapter']
    config.merge 'adapter' => config['adapter'].sub(/^jdbc/, '')
  end

  def current_config(options = {})
    ActiveRecord::Tasks::DatabaseTasks.current_config(options)
  end

end


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

  end

  MySQLDatabaseTasks.class_eval do

    def error_class
      ActiveRecord::JDBCError
    end

  end if const_defined?(:MySQLDatabaseTasks)

end