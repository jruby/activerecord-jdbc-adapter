
# Task redefine code from public domain
module Rake
  module TaskManager
    def redefine_task(task_class, args, &block)
      task_name, deps = resolve_args(args)
      task_name = task_class.scope_name(@scope, task_name)
      deps = [deps] unless deps.respond_to?(:to_ary)
      deps = deps.collect {|d| d.to_s }
      task = @tasks[task_name.to_s] = task_class.new(task_name, self)
      task.application = self
      task.add_comment(@last_comment)
      @last_comment = nil
      task.enhance(deps, &block)
      task
    end
  end
  class Task
    class << self
      def redefine_task(args, &block)
        Rake.application.redefine_task(self, args, &block)
      end
    end
  end
end

def redefine_task(args, &block)
  Rake::Task.redefine_task(args, &block)
end

if RUBY_PLATFORM =~ /java/
  namespace :db do
    namespace :structure do
      redefine_task :dump => :environment do
        abcs = ActiveRecord::Base.configurations
        ActiveRecord::Base.establish_connection(abcs[RAILS_ENV])
        File.open("db/#{RAILS_ENV}_structure.sql", "w+") { |f| f << ActiveRecord::Base.connection.structure_dump }
        if ActiveRecord::Base.connection.supports_migrations?
          File.open("db/#{RAILS_ENV}_structure.sql", "a") { |f| f << ActiveRecord::Base.connection.dump_schema_information }
        end
      end
    end
    namespace :test do
      redefine_task :clone_structure => [ "db:structure:dump", "db:test:purge" ] do
        abcs = ActiveRecord::Base.configurations
        ActiveRecord::Base.establish_connection(:test)
        ActiveRecord::Base.connection.execute('SET foreign_key_checks = 0') if abcs["test"]["adapter"] =~ /mysql/i
        IO.readlines("db/#{RAILS_ENV}_structure.sql").join.split(";\n\n").each do |ddl|
          ActiveRecord::Base.connection.execute(ddl)
        end
      end

      redefine_task :purge => :environment do
        abcs = ActiveRecord::Base.configurations
        ActiveRecord::Base.establish_connection(:test)
        db = ActiveRecord::Base.connection.database_name
        ActiveRecord::Base.connection.recreate_database(db)
      end
    end  
  end
end

