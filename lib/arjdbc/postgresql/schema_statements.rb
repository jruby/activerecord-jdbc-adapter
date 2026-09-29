# frozen_string_literal: true

module ArJdbc
  module PostgreSQL
    module SchemaStatements
      ForeignKeyDefinition = ActiveRecord::ConnectionAdapters::ForeignKeyDefinition
      Utils = ActiveRecord::ConnectionAdapters::PostgreSQL::Utils

      def foreign_keys(table_name)
        scope = quoted_scope(table_name)
        fk_info = internal_exec_query(<<~SQL, "SCHEMA", allow_retry: true, materialize_transactions: false)
          SELECT t2.oid::regclass::text AS to_table, a1.attname AS column, a2.attname AS primary_key, c.conname AS name, c.confupdtype AS on_update, c.confdeltype AS on_delete, c.convalidated AS valid, c.condeferrable AS deferrable, c.condeferred AS deferred, c.conkey, c.confkey, c.conrelid, c.confrelid
          FROM pg_constraint c
          JOIN pg_class t1 ON c.conrelid = t1.oid
          JOIN pg_class t2 ON c.confrelid = t2.oid
          JOIN pg_attribute a1 ON a1.attnum = c.conkey[1] AND a1.attrelid = t1.oid
          JOIN pg_attribute a2 ON a2.attnum = c.confkey[1] AND a2.attrelid = t2.oid
          JOIN pg_namespace t3 ON c.connamespace = t3.oid
          WHERE c.contype = 'f'
            AND t1.relname = #{scope[:name]}
            AND t3.nspname = #{scope[:schema]}
          ORDER BY c.conname
        SQL

        fk_info.map do |row|
          to_table = Utils.unquote_identifier(row["to_table"])
          # conkey = row["conkey"].scan(/\d+/).map(&:to_i)
          # confkey = row["confkey"].scan(/\d+/).map(&:to_i)
          conkey = row["conkey"]
          confkey = row["confkey"]

          if conkey.size > 1
            column = column_names_from_column_numbers(row["conrelid"], conkey)
            primary_key = column_names_from_column_numbers(row["confrelid"], confkey)
          else
            column = Utils.unquote_identifier(row["column"])
            primary_key = row["primary_key"]
          end

          options = {
            column: column,
            name: row["name"],
            primary_key: primary_key
          }

          options[:on_delete] = extract_foreign_key_action(row["on_delete"])
          options[:on_update] = extract_foreign_key_action(row["on_update"])
          options[:deferrable] = extract_constraint_deferrable(row["deferrable"], row["deferred"])

          options[:validate] = row["valid"]

          ForeignKeyDefinition.new(table_name, to_table, options)
        end
      end
    end
  end
end
