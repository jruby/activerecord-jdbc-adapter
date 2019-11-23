require 'strscan'

module ArJdbc
  module MSSQL
    module LockMethods

      # @private
      SELECT_FROM_WHERE_RE = /\A(\s*SELECT\s.*?)(\sFROM\s)(.*?)(\sWHERE\s.*|)\Z/mi

      # Microsoft SQL Server uses its own syntax for SELECT .. FOR UPDATE:
      # SELECT .. FROM table1 WITH(ROWLOCK,UPDLOCK), table2 WITH(ROWLOCK,UPDLOCK) WHERE ..
      #
      # This does in-place modification of the passed-in string.
      def add_lock!(sql, options)
        if (lock = options[:lock]) && sql =~ /\A\s*SELECT/mi
          # Check for and extract the :limit/:offset sub-query
          if sql =~ /\A(\s*SELECT t\.\* FROM \()(.*)(\) AS t WHERE t._row_num BETWEEN \d+ AND \d+\s*)\Z/m
            prefix, subselect, suffix = [$1, $2, $3]
            add_lock!(subselect, options)
            return sql.replace(prefix + subselect + suffix)
          end
          unless sql =~ SELECT_FROM_WHERE_RE
            # If you get this error, this driver probably needs to be fixed.
            raise NotImplementedError, "Don't know how to add_lock! to SQL statement: #{sql.inspect}"
          end
          select_clause, from_word, from_tables, where_clause = $1, $2, $3, $4
          with_clause = lock.is_a?(String) ? " #{lock} " : " WITH(ROWLOCK,UPDLOCK) "

          # Split the FROM clause into its constituent tables, and add the with clause after each one.
          new_from_tables = []
          scanner = StringScanner.new(from_tables)
          until scanner.eos?
            prev_pos = scanner.pos
            if scanner.scan_until(/,|(INNER\s+JOIN|CROSS\s+JOIN|(LEFT|RIGHT|FULL)(\s+OUTER)?\s+JOIN)\s+/mi)
              join_operand = scanner.pre_match[prev_pos..-1]
              join_operator = scanner.matched
            else
              join_operand = scanner.rest
              join_operator = ""
              scanner.terminate
            end

            # At this point, we have something like:
            #   join_operand == "appointments "
            #   join_operator == "INNER JOIN "
            # or:
            #   join_operand == "appointment_details AS d1 ON appointments.[id] = d1.[appointment_id]"
            #   join_operator == ""
            if join_operand =~ /\A(.*)(\s+ON\s+.*)\Z/mi
              table_spec, on_clause = $1, $2
            else
              table_spec = join_operand
              on_clause = ""
            end

            # Add the "WITH(ROWLOCK,UPDLOCK)" option to the table specification
            table_spec << with_clause unless table_spec =~ /\A\(\s*SELECT\s+/mi # HACK - this parser isn't so great
            join_operand = table_spec + on_clause

            # So now we have something like:
            #   join_operand == "appointments  WITH(ROWLOCK,UPDLOCK) "
            #   join_operator == "INNER JOIN "
            # or:
            #   join_operand == "appointment_details AS d1 WITH(ROWLOCK,UPDLOCK)  ON appointments.[id] = d1.[appointment_id]"
            #   join_operator == ""

            new_from_tables << join_operand
            new_from_tables << join_operator
          end
          sql.replace( select_clause.to_s << from_word.to_s << new_from_tables.join << where_clause.to_s )
        end
        sql
      end

    end
  end
end
