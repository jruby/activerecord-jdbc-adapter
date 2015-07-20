require 'arel/visitors/compat'

class Arel::Visitors::PostgreSQL
  # AREL converts bind argument markers "?" to "$n" for PG, but JDBC wants "?".
  remove_method :visit_Arel_Nodes_BindParam if ArJdbc::AR42
end
