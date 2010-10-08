module Arel
  module SqlCompiler
    class MsSQLCompiler < GenericCompiler
      def select_sql
        query = super
        
        offset = relation.skipped
        limit = relation.taken
        @engine.connection.add_limit_offset!(query, :limit => limit, :offset => offset) if offset || limit
    
        query
      end
      
      def build_clauses
        joins   = relation.joins(self)
        wheres  = relation.where_clauses
        groups  = relation.group_clauses
        havings = relation.having_clauses
        orders  = relation.order_clauses

        clauses = [ "",
          joins,
          ("WHERE     #{wheres.join(' AND ')}" unless wheres.empty?),
          ("GROUP BY  #{groups.join(', ')}" unless groups.empty?),
          ("HAVING    #{havings.join(' AND ')}" unless havings.empty?),
          ("ORDER BY  #{orders.join(', ')}" unless orders.empty?)
        ].compact.join ' '

        clauses << " #{locked}" unless locked.blank?
        clauses unless clauses.blank?
      end
    end
  end
end
