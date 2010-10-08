module Jdbc
  module Postgres
    VERSION = "8.4.702"

    def self.require_driver_jar
      vers  = VERSION.split( '.' )
      vers << jdbc_version
      require( "postgresql-%s.%s-%s.jdbc%d.jar" % vers )
    end

    # JDBC version 4 if Java >=1.6, else 3
    def self.jdbc_version
      vers = Java::java.lang.System::get_property( "java.specification.version" )
      vers = vers.split( '.' ).map { |v| v.to_i }
      ( ( vers <=> [ 1, 6 ] ) >= 0 ) ? 4 : 3
    end

  end
end

if RUBY_PLATFORM =~ /java/
  Jdbc::Postgres::require_driver_jar
else
  warn "jdbc-postgres is only for use with JRuby"
end
