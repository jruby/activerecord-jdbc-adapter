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

      def limit_for(limit_or_node)
        if ArJdbc::AR42
          limit_or_node.respond_to?(:expr) ? limit_or_node.expr.value.to_i : limit_or_node
        else
          limit_or_node.respond_to?(:expr) ? limit_or_node.expr.to_i : limit_or_node
        end
      end

    end
    ToSql.send(:include, ArJdbcCompat)
  end
end
