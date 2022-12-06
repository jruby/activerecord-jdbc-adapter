require 'arel/visitors/compat'

module Arel
  module Visitors
    class HSQLDB < Arel::Visitors::ToSql
      def visit_Arel_Nodes_SelectStatement(o, *)
        o.limit ||= Arel::Nodes::Limit.new(0) if o.offset
        super
      end
    end
  end
end
