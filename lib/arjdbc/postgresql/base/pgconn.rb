class PGconn
  def self.unescape_bytea(escaped)
    String.from_java_bytes Java::OrgPostgresqlUtil::PGbytea.toBytes escaped.to_java_bytes
  end
end
