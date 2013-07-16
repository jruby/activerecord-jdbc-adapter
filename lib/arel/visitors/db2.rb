require 'arel/visitors/compat'

module Arel
  module Visitors
    class DB2 < Arel::Visitors::ToSql

      def visit_Arel_Nodes_SelectStatement o
        sql = o.cores.map { |x| visit_Arel_Nodes_SelectCore x }.join
        sql << " ORDER BY #{o.orders.map { |x| visit x }.join(', ')}" unless o.orders.empty?
        add_limit_offset(sql, o)
      end

      private

      def add_limit_offset(sql, o)
        if o.offset && o.offset.value && o.limit && o.limit.value
          @connection.replace_limit_offset_for_arel! o, sql
        else
          @connection.replace_limit_offset! sql, limit_for(o.limit), o.offset && o.offset.value
        end
      end

    end
  end
end
