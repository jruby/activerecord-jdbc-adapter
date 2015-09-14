module Arel
  module Visitors
    module ArJdbcCompat

      protected

      if ToSql.instance_method('visit').arity == 1
        def do_visit(x, a); visit(x); end # a = nil
      else # > AREL 4.0
        def do_visit(x, a); visit(x, a); end
      end

      if ToSql.instance_method('visit_Arel_Nodes_SelectCore').arity == 1
        def do_visit_select_core(x, a) # a = nil
          visit_Arel_Nodes_SelectCore(x)
        end
      else # > AREL 4.0
        def do_visit_select_core(x, a)
          visit_Arel_Nodes_SelectCore(x, a)
        end
      end

      private

      if ArJdbc::AR42
        if Arel::VERSION < '6.0.2'
          def limit_for(limit_or_node)
            if limit_or_node.respond_to?(:expr)
              expr = limit_or_node.expr
              # NOTE(uwe): Different behavior for Arel 6.0.0 and 6.0.2
              expr.respond_to?(:value) ? expr.value.to_i : expr.to_i
            else
              limit_or_node
            end
          end
        else
          def limit_for(limit_or_node)
            limit_or_node.respond_to?(:expr) ? limit_or_node.expr.to_i : limit_or_node
          end
        end
      else
        def limit_for(limit_or_node)
          limit_or_node.respond_to?(:expr) ? limit_or_node.expr.to_i : limit_or_node
        end
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
