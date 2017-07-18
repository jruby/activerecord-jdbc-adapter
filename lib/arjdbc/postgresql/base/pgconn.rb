module PG
  class Connection # emulate PG::Connection#unescape_bytea due #652
    def self.unescape_bytea(escaped)
      ArJdbc::PostgreSQL.unescape_bytea(escaped)
    end
  end
end
