require 'active_record/connection_adapters/postgresql/oid'
module ActiveRecord::ConnectionAdapters::PostgreSQL::OID
  class PGconn
    def self.unescape_bytea(escaped)
      String.from_java_bytes Java::OrgPostgresqlUtil::PGbytea.toBytes escaped.to_java_bytes
    end
  end
end