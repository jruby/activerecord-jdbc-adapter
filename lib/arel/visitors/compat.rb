module Arel
  module Visitors
    module ArJdbcCompat

      protected

      def do_visit(x, a); visit(x, a); end

      def do_visit_select_core(x, a)
        visit_Arel_Nodes_SelectCore(x, a)
      end

      private

      def limit_for(limit_or_node)
        limit_or_node.respond_to?(:expr) ? limit_or_node.expr.to_i : limit_or_node
      end
      module_function :limit_for

      def node_value(node)
        return nil unless node
        case expr = node.expr
          when NilClass then nil
          when Numeric then expr
          when Arel::Nodes::Unary then expr.expr
        end
      end

    end
    ToSql.send(:include, ArJdbcCompat)
  end
end
