module Arel
  module Visitors
    class DB2 < Arel::Visitors::ToSql
      def visit_Arel_Nodes_SelectStatement o
        add_limit_offset([o.cores.map { |x| visit_Arel_Nodes_SelectCore x }.join,
         ("ORDER BY #{o.orders.map { |x| visit x }.join(', ')}" unless o.orders.empty?),
        ].compact.join(' '), o)
      end

      def add_limit_offset(sql, o)
        @connection.replace_limit_offset! sql, o.limit, o.offset
      end
    end
  end
end
