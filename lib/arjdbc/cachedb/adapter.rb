require 'arjdbc/mssql/tsql_helper'

module ::ArJdbc
  module CacheDB
    include TSqlMethods

    def self.column_selector
      [ /cache/i, lambda {  | cfg, col | col.extend( ::ArJdbc::CacheDB::Column ) } ]
    end

    module Column
    end

    def create_table(name, options = { })
      super(name, options)
      primary_key = options[:primary_key] || "id"
      execute "ALTER TABLE #{name} ADD CONSTRAINT #{name}_PK PRIMARY KEY(#{primary_key})" unless options[:id] == false
    end
  end
end
