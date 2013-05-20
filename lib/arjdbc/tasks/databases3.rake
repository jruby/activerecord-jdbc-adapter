# NOTE: fake these for create_database(config)
module Mysql
  Error = ActiveRecord::JDBCError unless const_defined?(:Error)
end
module Mysql2
  Error = ActiveRecord::JDBCError unless const_defined?(:Error)
end
  
namespace :db do
  
  class << self
    alias_method :_rails_create_database, :create_database
    alias_method :_rails_drop_database,   :drop_database
  end
  
  def create_database(config)
    case config['adapter']
    when /mysql|postgresql|sqlite/
      _rails_create_database adapt_jdbc_config(config)
    else
      begin
        ActiveRecord::Base.establish_connection(config)
        ActiveRecord::Base.connection
      rescue # database does not exists :
        url = config['url']
        url = $1 if url && url =~ /^(.*(?<!\/)\/)(?=\w)/
        ActiveRecord::Base.establish_connection(config.merge('database' => nil, 'url' => url))
        ActiveRecord::Base.connection.create_database(config['database'], config)
        ActiveRecord::Base.establish_connection(config)
      end
    end
  end

  def drop_database(config)
    case config['adapter']
    when /mysql|postgresql|sqlite/
      _rails_drop_database adapt_jdbc_config(config)
    else
      ActiveRecord::Base.establish_connection(config)
      unless ActiveRecord::Base.connection.respond_to?(:drop_database)
        raise "Drop database not supported by '#{config['adapter']}'"
      end
      ActiveRecord::Base.connection.drop_database config['database']
    end
  end
  
  def adapt_jdbc_config(config)
    config.merge 'adapter' => config['adapter'].sub(/^jdbc/, '')
  end
  private :adapt_jdbc_config
  
  redefine_task :charset do # available on 2.3
    config = ActiveRecord::Base.configurations[rails_env]
    ActiveRecord::Base.establish_connection(config)
    case config['adapter']
    when /mysql/
      puts ActiveRecord::Base.connection.charset
    when /postgresql|sqlite/
      puts ActiveRecord::Base.connection.encoding
    else
      if ActiveRecord::Base.connection.respond_to?(:charset)
        puts ActiveRecord::Base.connection.charset
      elsif ActiveRecord::Base.connection.respond_to?(:encoding)
        puts ActiveRecord::Base.connection.encoding
      else
        raise "AR-JDBC adapter '#{config['adapter']}' does not support charset/encoding, feel free to submit a patch"
      end
    end
  end

  redefine_task :collation do # available on 2.3
    config = ActiveRecord::Base.configurations[rails_env]
    ActiveRecord::Base.establish_connection(config)
    if ActiveRecord::Base.connection.respond_to?(:collation)
      puts ActiveRecord::Base.connection.collation
    else
      raise "AR-JDBC adapter '#{config['adapter']}' does not support collation, feel free to submit a patch"
    end
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
        `pg_dump -i -s -x -O -f #{Shellwords.escape(filename)} #{search_path} #{Shellwords.escape(config['database'])}`
        raise 'Error dumping database' if $?.exitstatus == 1
        
        File.open(filename, 'a') { |f| f << "SET search_path TO #{ActiveRecord::Base.connection.schema_search_path};\n\n" }
      when /sqlite/
        dbfile = config['database']
        `sqlite3 #{dbfile} .schema > #{filename}`
      else
        ActiveRecord::Base.establish_connection(config)
        if ActiveRecord::Base.connection.respond_to?(:structure_dump)
          File.open(filename, "w:utf-8") { |f| f << ActiveRecord::Base.connection.structure_dump }
        elsif config['adapter'] =~ /mssq|sqlserver/
          `smoscript -s #{config['host']} -d #{config['database']} -u #{config['username']} -p #{config['password']} -f #{filename} -A -U`
        else
          raise "AR-JDBC adapter '#{config['adapter']}' does not support structure_dump, feel free to submit a patch"
        end
      end

      if ActiveRecord::Base.connection.supports_migrations?
        File.open(filename, 'a') { |f| f << ActiveRecord::Base.connection.dump_schema_information }
      end
    end

    redefine_task :load do
      config = ActiveRecord::Base.configurations[rails_env] # current_config
      filename = structure_sql
      
      ActiveRecord::Base.establish_connection(config)
      
      if ActiveRecord::Base.connection.respond_to?(:structure_load)
        ActiveRecord::Base.connection.structure_load IO.read(filename)
      else
        case config['adapter']
        when /mysql/
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
        when /mssq|sqlserver/
          `sqlcmd -S #{config['host']} -d #{config['database']} -U #{config['username']} -P #{config['password']} -i #{filename}`
        when /oracle/
          IO.read(filename).split(";\n\n").each do |ddl|
            ActiveRecord::Base.connection.execute(ddl)
          end
        else
          #IO.read(filename).split(/;\n*/m).each do |ddl|
          #  ActiveRecord::Base.connection.execute(ddl)
          #end
          raise "AR-JDBC adapter '#{config['adapter']}' does not support structure_load, feel free to submit a patch"
        end
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
        Rake::Task["structure:load"].invoke
      ensure
        current_config(:config => nil)
      end
    end
    
    # desc "Recreate the test database from a fresh structure.sql file"
    redefine_task :clone_structure => [ "db:structure:dump", "db:test:load_structure" ]
    # same as on 3.2 - but this task gets changed on 2.3 by depending on :load_structure
    
  end
  
end