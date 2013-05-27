module ArJdbc
  module Tasks
    # Sharing task related code between AR 3.x and 4.x
    # 
    # @note this class needs to conform to the API available since AR 4.0
    # mostly to be usable with ActiveRecord::Tasks::DatabaseTasks module
    class JdbcDatabaseTasks
      
      attr_reader :configuration
      alias_method :config, :configuration
      
      def initialize(configuration)
        @configuration = configuration
      end
      
      delegate :connection, :establish_connection, :to => ActiveRecord::Base

      def create
        begin
          establish_connection(config)
          ActiveRecord::Base.connection
          if defined? ActiveRecord::Tasks::DatabaseAlreadyExists
            raise ActiveRecord::Tasks::DatabaseAlreadyExists # AR-4.x
          end # silence on AR < 4.0
        rescue #=> error # database does not exists :
          url = config['url']
          url = $1 if url && url =~ /^(.*(?<!\/)\/)(?=\w)/
          
          establish_connection(config.merge('database' => nil, 'url' => url))
          
          unless connection.respond_to?(:create_database)
            raise "AR-JDBC adapter '#{adapter_with_spec}' does not support create_database"
          end
          connection.create_database(config['database'], config)
          
          establish_connection(config)
        end
      end

      def drop
        establish_connection(config)
        unless ActiveRecord::Base.connection.respond_to?(:drop_database)
          raise "AR-JDBC adapter '#{adapter_with_spec}' does not support drop_database"
        end
        connection.drop_database config['database']
      end

      def purge
        establish_connection(config) # :test
        unless ActiveRecord::Base.connection.respond_to?(:recreate_database)
          raise "AR-JDBC adapter '#{adapter_with_spec}' does not support recreate_database (purge)"
        end
        db_name = ActiveRecord::Base.connection.database_name
        ActiveRecord::Base.connection.recreate_database(db_name, config)
      end

      def charset
        establish_connection(config)
        if connection.respond_to?(:charset)
          puts connection.charset
        elsif connection.respond_to?(:encoding)
          puts connection.encoding
        else
          raise "AR-JDBC adapter '#{adapter_with_spec}' does not support charset/encoding"
        end
      end

      def collation
        establish_connection(config)
        if connection.respond_to?(:collation)
          puts connection.collation
        else
          raise "AR-JDBC adapter '#{adapter_with_spec}' does not support collation"
        end
      end
      
      def structure_dump(filename)
        establish_connection(config)
        if connection.respond_to?(:structure_dump)
          File.open(filename, "w:utf-8") { |f| f << connection.structure_dump }
        else
          raise "AR-JDBC adapter '#{adaper_with_spec}' does not support structure_dump"
        end
      end

      def structure_load(filename)
        establish_connection(config)
        if connection.respond_to?(:structure_load)
          connection.structure_load IO.read(filename)
        else
          #IO.read(filename).split(/;\n*/m).each do |ddl|
          #  connection.execute(ddl)
          #end
          raise "AR-JDBC adapter '#{adaper_with_spec}' does not support structure_load"
        end
      end
      
      private
      
      def adapter_with_spec
        adapter, spec = config['adapter'], config['adapter_spec']
        spec ? "#{adapter} (#{spec})" : adapter
      end
      
      protected
      
      def expand_path(path)
        require 'pathname'
        path = Pathname.new path
        return path.to_s if path.absolute?
        rails_root ? File.join(rails_root, path) : File.expand_path(path)
      end
      
      private
      
      def rails_root
        defined?(Rails.root) ? Rails.root : ( RAILS_ROOT )
      end
    
    end
  end
end