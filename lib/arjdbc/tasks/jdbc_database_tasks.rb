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
          connection.create_database(resolve_database(config), config)

          establish_connection(config)
        end
      end

      def drop
        establish_connection(config)
        unless ActiveRecord::Base.connection.respond_to?(:drop_database)
          raise "AR-JDBC adapter '#{adapter_with_spec}' does not support drop_database"
        end
        connection.drop_database resolve_database(config)
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
          raise "AR-JDBC adapter '#{adapter_with_spec}' does not support structure_dump"
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
          raise "AR-JDBC adapter '#{adapter_with_spec}' does not support structure_load"
        end
      end

      protected

      def expand_path(path)
        require 'pathname'
        path = Pathname.new path
        return path.to_s if path.absolute?
        rails_root ? File.join(rails_root, path) : File.expand_path(path)
      end

      def resolve_database(config, file_paths = false)
        config['database'] || resolve_database_from_url(config['url'] || '', file_paths)
      end

      def resolve_database_from_url(url, file_paths = false)
        ( config = config_from_url(url, file_paths) ) ? config['database'] : nil
      end

      private

      def config_from_url(url, file_paths = false)
        match = url.match %r{
          ^ jdbc:
          ( [\w]+ ):         # $1 protocol
          (?: ([\w]+) : )?   # $2 (sub-protocol)
          (?://)?
          (?: ([\w\-]*) (?: [/:] ([\w\-]*) )? @ (?://)? )?  # user[:password]@ or user[/password]@ ($3 $4)
          ( [\w\.\-]+ )?   # $5 host (or database if there's nothing left)
          (?: : (\d+) )?   # $6 port if any
          (?: :? (/?[\w\-\./~]+) [\?;]? )? ([^/]*?) $
          # $7 database part (ends with '?' or ';') and $8 query string - properties
        }x

        return nil unless match

        config = {}
        config['_protocol'] = match[1]
        config['_sub_protocol'] = match[2] if match[2]
        config['username'] = match[3] if match[3]
        config['password'] = match[4] if match[4]
        host = match[5]; port = match[6]
        database = match[7]
        if database.nil? && port.nil?
          config['database'] = database = host
        else
          config['host'] = host if host
          config['port'] = port if port
          config['database'] = database
        end
        if database && ! file_paths && database[0...1] == '/'
          config['database'] = database[1..-1]
        end
        if query_string = match[8]
          properties = query_string.split('&').inject({}) do |memo, pair|
            pair = pair.split("="); memo[ pair[0] ] = pair[1]; memo
          end
          config['properties'] = properties
        end
        config
      end

      def adapter_with_spec
        adapter, spec = config['adapter'], config['adapter_spec']
        spec ? "#{adapter} (#{spec})" : adapter
      end

      def rails_root
        defined?(Rails.root) ? Rails.root : ( RAILS_ROOT )
      end

    end
  end
end