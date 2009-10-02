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
  enhancements.each {|enhancement| redefined_task.actions << enhancement}
end

namespace :db do
  redefine_task :create => :environment do
    create_database(ActiveRecord::Base.configurations[RAILS_ENV])
  end
  task :create => :load_config if Rake.application.lookup(:load_config)

  redefine_task :drop => :environment do
    config = ActiveRecord::Base.configurations[RAILS_ENV]
    begin
      ActiveRecord::Base.establish_connection(config)
      db = ActiveRecord::Base.connection.database_name
      ActiveRecord::Base.connection.drop_database(db)
    rescue
      drop_database(config.merge('adapter' => config['adapter'].sub(/^jdbc/, '')))
    end
  end
  task :drop => :load_config if Rake.application.lookup(:load_config)

  namespace :create do
    task :all => :environment
  end

  namespace :drop do
    task :all => :environment
  end

  class << self
    alias_method :previous_create_database, :create_database
    alias_method :previous_drop_database, :drop_database
  end

  def create_database(config)
    begin
      ActiveRecord::Base.establish_connection(config)
      ActiveRecord::Base.connection
    rescue
      begin
        if url = config['url'] && url =~ /^(.*(?<!\/)\/)(?=\w)/
          url = $1
        end

        ActiveRecord::Base.establish_connection(config.merge({'database' => nil, 'url' => url}))
        ActiveRecord::Base.connection.create_database(config['database'])
        ActiveRecord::Base.establish_connection(config)
      rescue
        previous_create_database(config.merge('adapter' => config['adapter'].sub(/^jdbc/, '')))
      end
    end
  end

  def drop_database(config)
    previous_drop_database(config.merge('adapter' => config['adapter'].sub(/^jdbc/, '')))
  end

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
      abcs['test']['pg_params'] = '?allowEncodingChanges=true' if abcs['test']['adapter'] =~ /postgresql/i
      ActiveRecord::Base.establish_connection(abcs["test"])
      ActiveRecord::Base.connection.execute('SET foreign_key_checks = 0') if abcs["test"]["adapter"] =~ /mysql/i
      IO.readlines("db/#{RAILS_ENV}_structure.sql").join.split(";\n\n").each do |ddl|
        begin
          ActiveRecord::Base.connection.execute(ddl.chomp(';'))
        rescue Exception => ex
          puts ex.message
        end
      end
    end

    redefine_task :purge => :environment do
      abcs = ActiveRecord::Base.configurations
      config = abcs['test'].dup
      if config['adapter'] =~ /postgresql/i
        if config['url']
          db = config['url'][/\/([^\/]*)$/, 1]
          config['url'][/\/([^\/]*)$/, 1] = 'postgres' if db
        else
          db = config['database']
          config['database'] = 'postgres'
        end
        ActiveRecord::Base.establish_connection(config)
      else
        ActiveRecord::Base.establish_connection(config)
        db = ActiveRecord::Base.connection.database_name
      end
      ActiveRecord::Base.connection.recreate_database(db)
    end
  end
end
