module ArJdbc
  module Tasks
    class << self

      # API similar to ActiveRecord::Tasks::DatabaseTasks on AR 4.0

      def create(config)
        tasks_instance(config).create
      end

      def drop(config)
        tasks_instance(config).drop
      end

      def purge(config)
        tasks_instance(config).purge
      end

      def charset(config)
        tasks_instance(config).charset
      end

      def collation(config)
        tasks_instance(config).collation
      end

      def structure_dump(config, filename)
        tasks_instance(config).structure_dump(filename)
      end

      def structure_load(config, filename)
        tasks_instance(config).structure_load(filename)
      end

    end
  end
end

namespace :db do

  class << self
    alias_method :_rails_create_database, :create_database
    alias_method :_rails_drop_database,   :drop_database
  end

  def create_database(config)
    case config['adapter']
    when /mysql2/
      unless defined? Mysql2::Error
        # NOTE: fake it for create_database(config)
        Object.const_set :Mysql2, Module.new
        Mysql2.const_set :Error, ActiveRecord::JDBCError
        ActiveRecord::JDBCError.class_eval do
          def error; self end # Mysql2::Error#error
        end
      end
      _rails_create_database adapt_jdbc_config(config)
    when /mysql/
      unless defined? Mysql::Error
        # NOTE: fake it for create_database(config)
        Object.const_set :Mysql, Module.new
        Mysql.const_set :Error, ActiveRecord::JDBCError
        ActiveRecord::JDBCError.class_eval do
          def error; self end # Mysql::Error#error
        end
      end
      _rails_create_database adapt_jdbc_config(config)
    when /postgresql|sqlite/
      _rails_create_database adapt_jdbc_config(config)
    else
      ArJdbc::Tasks.create(config)
    end
  end

  def drop_database(config)
    case config['adapter']
    when /mysql|postgresql|sqlite/
      _rails_drop_database adapt_jdbc_config(config)
    else
      ArJdbc::Tasks.drop(config)
    end
  end

  redefine_task :charset do # available on 2.3
    ArJdbc::Tasks.charset ActiveRecord::Base.configurations[rails_env]
  end

  redefine_task :collation do # available on 2.3
    ArJdbc::Tasks.collation ActiveRecord::Base.configurations[rails_env]
  end

  namespace :structure do

    redefine_task :dump do
      config = ActiveRecord::Base.configurations[rails_env] # current_config
      filename = structure_sql

      case config['adapter']
      when /mysql/
        ActiveRecord::Base.establish_connection(config)
        File.open(filename, 'w:utf-8') { |f| f << ActiveRecord::Base.connection.structure_dump }
      when /postgresql/
        ActiveRecord::Base.establish_connection(config)

        ENV['PGHOST'] = config['host'] if config['host']
        ENV['PGPORT'] = config['port'].to_s if config['port']
        ENV['PGPASSWORD'] = config['password'].to_s if config['password']
        ENV['PGUSER'] = config['username'].to_s if config['username']

        require 'shellwords'
        search_path = config['schema_search_path']
        unless search_path.blank?
          search_path = search_path.split(",").map{ |part| "--schema=#{Shellwords.escape(part.strip)}" }.join(" ")
        end
        sh "pg_dump -i -s -x -O -f #{Shellwords.escape(filename)} #{search_path} #{Shellwords.escape(config['database'])}"

        File.open(filename, 'a') { |f| f << "SET search_path TO #{ActiveRecord::Base.connection.schema_search_path};\n\n" }
      when /sqlite/
        dbfile = config['database']
        sh "sqlite3 #{dbfile} .schema > #{filename}"
      else
        ActiveRecord::Base.establish_connection(config)
        ArJdbc::Tasks.structure_dump(config, filename)
      end

      if ActiveRecord::Base.connection.supports_migrations?
        File.open(filename, 'a') { |f| f << ActiveRecord::Base.connection.dump_schema_information }
      end

    end

    redefine_task :load do
      config = current_config
      filename = structure_sql

      case config['adapter']
      when /mysql/
        ActiveRecord::Base.establish_connection(config)
        ActiveRecord::Base.connection.execute('SET foreign_key_checks = 0')
        IO.read(filename).split("\n\n").each do |table|
          ActiveRecord::Base.connection.execute(table)
        end
      when /postgresql/
        ENV['PGHOST'] = config['host'] if config['host']
        ENV['PGPORT'] = config['port'].to_s if config['port']
        ENV['PGPASSWORD'] = config['password'].to_s if config['password']
        ENV['PGUSER'] = config['username'].to_s if config['username']

        `psql -f "#{filename}" #{config['database']}`
      when /sqlite/
        dbfile = config['database']
        `sqlite3 #{dbfile} < "#{filename}"`
      else
        ArJdbc::Tasks.structure_load(config, filename)
      end
    end

    def structure_sql
      ENV['DB_STRUCTURE'] ||= begin
        root = defined?(Rails.root) ? Rails.root : ( RAILS_ROOT rescue nil )
        if ActiveRecord::VERSION::STRING > '3.2'
          root ? File.join(root, "db", "structure.sql") : File.join("db", "structure.sql")
        else
          root ? File.join(root, "db/#{rails_env}_structure.sql") : "db/#{rails_env}_structure.sql"
        end
      end
    end

  end

  namespace :test do

    # desc "Recreate the test database from an existent structure.sql file"
    redefine_task :load_structure => 'db:test:purge' do # not on 2.3
      begin
        current_config(:config => ActiveRecord::Base.configurations['test'])
        Rake::Task["db:structure:load"].invoke
      ensure
        current_config(:config => nil)
      end
    end

    # desc "Recreate the test database from a fresh structure.sql file"
    redefine_task :clone_structure => [ "db:structure:dump", "db:test:load_structure" ]
    # same as on 3.2 - but this task gets changed on 2.3 by depending on :load_structure

    # desc "Empty the test database"
    redefine_task :purge do
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
      else
        ArJdbc::Tasks.purge(config)
      end
    end
    # only does (:purge => :environment) on AR < 3.2
    task :purge => :load_config if Rake::Task.task_defined?(:load_config)

  end

end
