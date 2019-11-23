module ArJdbc
  module MSSQL
    module LimitHelpers

      # @private
      FIND_SELECT = /\b(SELECT(\s+DISTINCT)?)\b(.*)/mi
      # @private
      FIND_AGGREGATE_FUNCTION = /(AVG|COUNT|COUNT_BIG|MAX|MIN|SUM|STDDEV|STDEVP|VAR|VARP)\(/i

      # @private
      module SqlServerReplaceLimitOffset

        GROUP_BY = 'GROUP BY'
        ORDER_BY = 'ORDER BY'

        module_function

        def replace_limit_offset!(sql, limit, offset, order)
          offset ||= 0

          if match = FIND_SELECT.match(sql)
            select, distinct, rest_of_query = match[1], match[2], match[3]
            rest_of_query.strip!
          end
          rest_of_query[0] = '*' if rest_of_query[0...1] == '1' && rest_of_query !~ /1 AS/i
          if rest_of_query[0...1] == '*'
            from_table = Utils.get_table_name(rest_of_query, true)
            rest_of_query = "#{from_table}.#{rest_of_query}"
          end

          # Ensure correct queries if the rest_of_query contains a 'GROUP BY'. Otherwise the following error occurs:
          #   ActiveRecord::StatementInvalid: ActiveRecord::JDBCError: Column 'users.id' is invalid in the select list because it is not contained in either an aggregate function or the GROUP BY clause.
          #   SELECT t.* FROM ( SELECT ROW_NUMBER() OVER(ORDER BY users.id) AS _row_num, [users].[lft], COUNT([users].[lft]) FROM [users] GROUP BY [users].[lft] HAVING COUNT([users].[lft]) > 1 ) AS t WHERE t._row_num BETWEEN 1 AND 1
          if i = ( rest_of_query.rindex(GROUP_BY) || rest_of_query.rindex('group by') )
            # Do not catch 'GROUP BY' statements from sub-selects, indicated
            # by more closing than opening brackets after the last group by.
            rest_after_last_group_by = rest_of_query[i..-1]
            opening_brackets_count = rest_after_last_group_by.count('(')
            closing_brackets_count = rest_after_last_group_by.count(')')

            if opening_brackets_count == closing_brackets_count
              order_start = order.strip[0, 8]; order_start.upcase!
              if order_start == ORDER_BY && order.match(FIND_AGGREGATE_FUNCTION)
                # do nothing
              elsif order.count(',') == 0
                order.gsub!(/ORDER +BY +([^\s]+)(\s+ASC|\s+DESC)?/i, 'ORDER BY MIN(\1)\2')
              else
                raise("can not handle multiple order conditions (#{order.inspect}) in #{sql.inspect}")
              end
            end
          end

          if distinct # select =~ /DISTINCT/i
            order = order.gsub(/(\[[a-z0-9_]+\]|[a-z0-9_]+)\./, 't.')
            new_sql = "SELECT t.* FROM "
            new_sql << "( SELECT ROW_NUMBER() OVER(#{order}) AS _row_num, t.* FROM (#{select} #{rest_of_query}) AS t ) AS t"
            append_limit_row_num_clause(new_sql, limit, offset)
          else
            select_columns_before_from = rest_of_query.gsub(/FROM.*/, '').strip
            only_one_column            = !select_columns_before_from.include?(',')
            only_one_id_column         = only_one_column && (select_columns_before_from.ends_with?('.id') || select_columns_before_from.ends_with?('.[id]'))

            if only_one_id_column
              # If there's only one id column a subquery will be created which only contains this column
              new_sql = "#{select} t.id FROM "
            else
              # All selected columns are used
              new_sql = "#{select} t.* FROM "
            end
            new_sql << "( SELECT ROW_NUMBER() OVER(#{order}) AS _row_num, #{rest_of_query} ) AS t"
            append_limit_row_num_clause(new_sql, limit, offset)
          end

          sql.replace new_sql
        end

        def append_limit_row_num_clause(sql, limit, offset)
          if limit
            start_row = offset + 1; end_row = offset + limit.to_i
            sql << " WHERE t._row_num BETWEEN #{start_row} AND #{end_row}"
          else
            sql << " WHERE t._row_num > #{offset}"
          end
        end

      end

      # @private
      module SqlServer2000ReplaceLimitOffset

        module_function

        def replace_limit_offset!(sql, limit, offset, order)
          if limit
            offset ||= 0
            start_row = offset + 1
            end_row = offset + limit.to_i

            if match = FIND_SELECT.match(sql)
              select, distinct, rest_of_query = match[1], match[2], match[3]
            end
            #need the table name for avoiding amiguity
            table_name  = Utils.get_table_name(sql, true)
            primary_key = get_primary_key(order, table_name)

            #I am not sure this will cover all bases.  but all the tests pass
            if order[/ORDER/].nil?
              new_order = "ORDER BY #{order}, [#{table_name}].[#{primary_key}]" if order.index("#{table_name}.#{primary_key}").nil?
            else
              new_order ||= order
            end

            if (start_row == 1) && (end_row ==1)
              new_sql = "#{select} TOP 1 #{rest_of_query} #{new_order}"
              sql.replace(new_sql)
            else
              # We are in deep trouble here. SQL Server does not have any kind of OFFSET build in.
              # Only remaining solution is adding a where condition to be sure that the ID is not in SELECT TOP OFFSET FROM SAME_QUERY.
              # To do so we need to extract each part of the query to insert our additional condition in the right place.
              query_without_select = rest_of_query[/FROM/i=~ rest_of_query.. -1]
              additional_condition = "#{table_name}.#{primary_key} NOT IN (#{select} TOP #{offset} #{table_name}.#{primary_key} #{query_without_select} #{new_order})"

              # Extract the different parts of the query
              having, group_by, where, from, selection = split_sql(rest_of_query, /having/i, /group by/i, /where/i, /from/i)

              # Update the where part to add our additional condition
              if where.blank?
                where = "WHERE #{additional_condition}"
              else
                where = "#{where} AND #{additional_condition}"
              end

              # Replace the query to be our new customized query
              sql.replace("#{select} TOP #{limit} #{selection} #{from} #{where} #{group_by} #{having} #{new_order}")
            end
          end
          sql
        end

        # Split the rest_of_query into chunks based on regexs (applied from end of string to the beginning)
        # The result is an array of regexs.size+1 elements (the last one being the remaining once everything was chopped away)
        def split_sql(rest_of_query, *regexs)
          results = Array.new

          regexs.each do |regex|
            if position = (regex =~ rest_of_query)
              # Extract the matched string and chop the rest_of_query
              matched       = rest_of_query[position..-1]
              rest_of_query = rest_of_query[0...position]
            else
              matched = nil
            end

            results << matched
          end
          results << rest_of_query

          results
        end

        def get_primary_key(order, table_name) # table_name might be quoted
          if order =~ /(\w*id\w*)/i
            $1
          else
            unquoted_name = Utils.unquote_table_name(table_name)
            model = descendants.find { |m| m.table_name == table_name || m.table_name == unquoted_name }
            model ? model.primary_key : 'id'
          end
        end

        private

        if ActiveRecord::VERSION::MAJOR >= 3
          def descendants; ::ActiveRecord::Base.descendants; end
        else
          def descendants; ::ActiveRecord::Base.send(:subclasses) end
        end

      end

      private

      if ::ActiveRecord::VERSION::MAJOR < 3

        def setup_limit_offset!(version = nil)
          if version.to_s == '2000' || sqlserver_2000?
            extend SqlServer2000AddLimitOffset
          else
            extend SqlServerAddLimitOffset
          end
        end

      else

        def setup_limit_offset!(version = nil); end

      end

      # @private
      module SqlServerAddLimitOffset

        # @note Only needed with (non-AREL) ActiveRecord **2.3**.
        # @see Arel::Visitors::SQLServer
        def add_limit_offset!(sql, options)
          if options[:limit]
            order = "ORDER BY #{options[:order] || determine_order_clause(sql)}"
            sql.sub!(/ ORDER BY.*$/i, '')
            SqlServerReplaceLimitOffset.replace_limit_offset!(sql, options[:limit], options[:offset], order)
          end
        end

      end if ::ActiveRecord::VERSION::MAJOR < 3

      # @private
      module SqlServer2000AddLimitOffset

        # @note Only needed with (non-AREL) ActiveRecord **2.3**.
        # @see Arel::Visitors::SQLServer
        def add_limit_offset!(sql, options)
          if options[:limit]
            order = "ORDER BY #{options[:order] || determine_order_clause(sql)}"
            sql.sub!(/ ORDER BY.*$/i, '')
            SqlServer2000ReplaceLimitOffset.replace_limit_offset!(sql, options[:limit], options[:offset], order)
          end
        end

      end if ::ActiveRecord::VERSION::MAJOR < 3

    end
  end
end
