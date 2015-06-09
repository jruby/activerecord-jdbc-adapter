module ActiveRecord::ConnectionAdapters::PostgreSQL::OID
  class PGconn # emulate PGconn#unescape_bytea due #652
    # NOTE: on pg gem ... PGconn = (class) PG::Connection
    def self.unescape_bytea(escaped)
      ArJdbc::PostgreSQL.unescape_bytea(escaped)
    end
  end
end