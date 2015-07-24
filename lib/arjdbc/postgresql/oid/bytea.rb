class ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Bytea
  remove_method :type_cast_from_database
end
