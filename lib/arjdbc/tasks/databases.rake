def redefine_task(*args, &block)
  task_name = Hash === args.first ? args.first.keys[0] : args.first
  existing_task = Rake.application.lookup task_name
  if existing_task
    class << existing_task
      public :instance_variable_set
      attr_reader :actions
    end
    existing_task.instance_variable_set "@prerequisites", FileList[]
    existing_task.actions.shift
    enhancements = existing_task.actions
    existing_task.instance_variable_set "@actions", []
  end
  redefined_task = task(*args, &block)
  enhancements.each {|enhancement| redefined_task.actions << enhancement} unless enhancements.nil?
end

def rails_env
  defined?(Rails.env) ? Rails.env : RAILS_ENV
end

namespace :db do

#  redefine_task :create do
#    config = ActiveRecord::Base.configurations[rails_env]
#    create_database(config)
#  end
#  task :create => :load_config if Rake.application.lookup(:load_config)
#
#  redefine_task :drop => :environment do
#    config = ActiveRecord::Base.configurations[rails_env]
#    begin
#      db = find_database_name(config)
#      ActiveRecord::Base.connection.drop_database(db)
#    rescue
#      drop_database(config)
#    end
#  end
#  task :drop => :load_config if Rake.application.lookup(:load_config)

  if defined? ActiveRecord::Tasks::DatabaseTasks # 4.0
    load 'arjdbc/tasks/databases4.rake'
  else # 3.x / 2.3
    load 'arjdbc/tasks/databases3.rake'
  end

  namespace :structure do
    redefine_task :dump => :environment do
      config = ActiveRecord::Base.configurations[rails_env]
      ActiveRecord::Base.establish_connection(config)
      filename = ENV['DB_STRUCTURE'] || "db/#{rails_env}_structure.sql"
      File.open(filename, "w+") { |f| f << ActiveRecord::Base.connection.structure_dump }
      if ActiveRecord::Base.connection.supports_migrations?
        File.open(filename, "a") { |f| f << ActiveRecord::Base.connection.dump_schema_information }
      end
    end

    redefine_task :load => :environment do
      config = ActiveRecord::Base.configurations[rails_env]
      ActiveRecord::Base.establish_connection(config)
      filename = ENV['DB_STRUCTURE'] || "db/#{rails_env}_structure.sql"
      IO.read(filename).split(/;\n*/m).each do |ddl|
        ActiveRecord::Base.connection.execute(ddl)
      end
    end
  end

  namespace :test do
    redefine_task :clone_structure => [ "db:structure:dump", "db:test:purge" ] do
      config = ActiveRecord::Base.configurations['test']
      config['pg_params'] = '?allowEncodingChanges=true' if config['adapter'] =~ /postgresql/i
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection.execute('SET foreign_key_checks = 0') if config['adapter'] =~ /mysql/i
      IO.readlines("db/#{rails_env}_structure.sql").join.split(";\n\n").each do |ddl|
        begin
          ActiveRecord::Base.connection.execute(ddl.chomp(';'))
        rescue Exception => ex
          puts ex.message
        end
      end
    end

    redefine_task :purge => :environment do
      db = find_database_name config = ActiveRecord::Base.configurations['test']
      ActiveRecord::Base.connection.recreate_database(db, config)
    end
    task :purge => :load_config if Rake.application.lookup(:load_config)
  end

  def find_database_name(config)
    db = config['database']
    if config['adapter'] =~ /postgresql/i
      config = config.dup
      if config['url']
        url = config['url'].dup
        db = url[/\/([^\/]*)$/, 1]
        if db
          url[/\/([^\/]*)$/, 1] = 'postgres'
          config['url'] = url
        end
      else
        db = config['database']
        config['database'] = 'postgres'
      end
      ActiveRecord::Base.establish_connection(config)
    else
      ActiveRecord::Base.establish_connection(config)
      db = ActiveRecord::Base.connection.database_name
    end
    db
  end

end
