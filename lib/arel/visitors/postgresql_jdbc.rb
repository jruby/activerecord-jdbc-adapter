require 'arel/visitors/compat'

module Arel
  module Visitors
    class PostgreSQL < Arel::Visitors::ToSql
      def visit_Arel_Nodes_BindParam(o, collector)
        collector.add_bind(o) { |_| '?' }
      end if ArJdbc::AR42
    end
  end
end
