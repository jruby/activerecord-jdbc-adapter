module JdbcSpec
  module ActiveRecordExtensions
    def self.add_method_to_remove_from_ar_base(meth)
      @methods ||= []
      @methods << meth
    end

    def self.extended(klass)
      (@methods || []).each {|m| (class << klass; self; end).instance_eval { remove_method(m) rescue nil } }
    end
  end
end

require 'arjdbc/jdbc/jdbc_mimer'
require 'arjdbc/jdbc/jdbc_hsqldb'
require 'arjdbc/jdbc/jdbc_oracle'
require 'arjdbc/jdbc/jdbc_postgresql'
require 'arjdbc/jdbc/jdbc_mysql'
require 'arjdbc/jdbc/jdbc_derby'
require 'arjdbc/jdbc/jdbc_firebird'
require 'arjdbc/jdbc/jdbc_db2'
require 'arjdbc/jdbc/jdbc_mssql'
require 'arjdbc/jdbc/jdbc_cachedb'
require 'arjdbc/jdbc/jdbc_sqlite3'
require 'arjdbc/jdbc/jdbc_sybase'
require 'arjdbc/jdbc/jdbc_informix'
