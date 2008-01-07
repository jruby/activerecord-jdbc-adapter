if defined?(namespace) && RUBY_PLATFORM =~ /java/ && ENV["SKIP_AR_JDBC_RAKE_REDEFINES"].nil?
  def redefine_task(*args, &block)
    task_name = Hash === args.first ? args.first.keys[0] : args.first
    existing_task = Rake::Task[task_name]
    class << existing_task; public :instance_variable_set; end
    existing_task.instance_variable_set "@prerequisites", FileList[]
    existing_task.instance_variable_set "@actions", []
    task(*args, &block)
  end

  namespace :db do
    redefine_task :drop => :environment do
      begin
        config = ActiveRecord::Base.configurations[environment_name]
        ActiveRecord::Base.establish_connection(config)
        db = ActiveRecord::Base.connection.database_name
        ActiveRecord::Base.connection.recreate_database(db)
      rescue
      end
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
