module Arel
  module Visitors
    class SQLServer < Arel::Visitors::ToSql
      def visit_Arel_Nodes_SelectStatement o
        order = "ORDER BY #{o.orders.map { |x| visit x }.join(', ')}" unless o.orders.empty?
        add_limit_offset([o.cores.map { |x| visit_Arel_Nodes_SelectCore x }.join, order].compact.join(' '), o, order)
      end
    end

    class SQLServer2000 < SQLServer
    end
  end
end
