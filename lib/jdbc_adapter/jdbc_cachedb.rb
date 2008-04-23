module ::JdbcSpec
  module ActiveRecordExtensions
    def cachedb_connection( config )
      config[:port] ||= 1972
      config[:url] ||= "jdbc:Cache://#{config[:host]}:#{config[:port]}/#{ config[:database]}"
      config[:driver] ||= "com.intersys.jdbc.CacheDriver"
      jdbc_connection( config )
    end
  end

  module CacheDB

    def self.column_selector
      [ /cache/i, lambda {  | cfg, col | col.extend( ::JdbcSpec::CacheDB::Column ) } ]
    end

    def self.adapter_selector
      [ /cache/i, lambda {  | cfg, adapt | adapt.extend( ::JdbcSpec::CacheDB ) } ]
    end

    module Column
    end

    def modify_types(tp)
      tp[:primary_key] = "int NOT NULL IDENTITY(1, 1) PRIMARY KEY"
      tp
    end

    def type_to_sql(type, limit = nil, precision = nil, scale = nil)
      return super unless type.to_s == 'integer'
      
      if limit.nil? || limit == 4
        'INT'
      elsif limit == 2
        'SMALLINT'
      elsif limit == 1
        'TINYINT'
      else
        'BIGINT'
      end
    end

    def create_table(name, options = { })
      super(name, options)
      primary_key = options[:primary_key] || "id"
      execute "ALTER TABLE #{name} ADD CONSTRAINT #{name}_PK PRIMARY KEY(#{primary_key})" unless options[:id] == false
    end
  end
end
