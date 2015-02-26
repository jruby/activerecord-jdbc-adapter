require 'arjdbc/util/serialized_attributes'

module ArJdbc
  module Informix

    @@_lob_callback_added = nil

    def self.extended(base)
      unless @@_lob_callback_added
        ActiveRecord::Base.class_eval do
          def after_save_with_informix_lob
            lob_columns = self.class.columns.select { |c| [:text, :binary].include?(c.type) }
            lob_columns.each do |column|
              value = ::ArJdbc::SerializedAttributesHelper.dump_column_value(self, column)
              next if value.nil? || (value == '')

              connection.write_large_object(
                column.type == :binary, column.name,
                self.class.table_name, self.class.primary_key,
                quote_value(id), value
              )
            end
          end
        end

        ActiveRecord::Base.after_save :after_save_with_informix_lob
        @@_lob_callback_added = true
      end
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcColumn#column_types
    def self.column_selector
      [ /informix/i, lambda { |cfg, column| column.extend(ColumnMethods) } ]
    end

    JdbcConnection = ::ActiveRecord::ConnectionAdapters::InformixJdbcConnection

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_connection_class
    def self.jdbc_connection_class
      ::ActiveRecord::ConnectionAdapters::InformixJdbcConnection
    end

    # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#jdbc_column_class
    def jdbc_column_class
      ::ActiveRecord::ConnectionAdapters::InformixColumn
    end

    module ColumnMethods

      private
      # TODO: Test all Informix column types.
      def simplified_type(field_type)
        if field_type =~ /serial/i
          :primary_key
        else
          super
        end
      end

    end

    def modify_types(types)
      super(types)
      types[:primary_key] = "SERIAL PRIMARY KEY"
      types[:string]      = { :name => "VARCHAR", :limit => 255 }
      types[:integer]     = { :name => "INTEGER" }
      types[:float]       = { :name => "FLOAT" }
      types[:decimal]     = { :name => "DECIMAL" }
      types[:datetime]    = { :name => "DATETIME YEAR TO FRACTION(5)" }
      types[:timestamp]   = { :name => "DATETIME YEAR TO FRACTION(5)" }
      types[:time]        = { :name => "DATETIME HOUR TO FRACTION(5)" }
      types[:date]        = { :name => "DATE" }
      types[:binary]      = { :name => "BYTE" }
      types[:boolean]     = { :name => "BOOLEAN" }
      types
    end

    def prefetch_primary_key?(table_name = nil)
      true
    end

    def supports_migrations?
      true
    end

    def default_sequence_name(table, column)
      "#{table}_seq"
    end

    def add_limit_offset!(sql, options)
      if options[:limit]
        limit = "FIRST #{options[:limit]}" # SKIP available only in IDS >= 10 :
        offset = (db_major_version >= 10 && options[:offset] ? "SKIP #{options[:offset]}" : "")
        sql.sub!(/^\s*?select /i, "SELECT #{offset} #{limit} ")
      end
      sql
    end

    def next_sequence_value(sequence_name)
      select_one("SELECT #{sequence_name}.nextval id FROM systables WHERE tabid=1")['id']
    end

    # TODO: Add some smart quoting for newlines in string and text fields.
    def quote_string(string)
      string.gsub(/\'/, "''")
    end

    def quote(value, column = nil)
      column_type = column && column.type
      if column_type == :binary || column_type == :text
        # LOBs are updated separately by an after_save trigger.
        "NULL"
      elsif column_type == :date
        "'#{value.mon}/#{value.day}/#{value.year}'"
      else
        super
      end
    end

    def create_table(name, options = {})
      super(name, options)
      execute("CREATE SEQUENCE #{name}_seq")
    end

    def rename_table(name, new_name)
      execute("RENAME TABLE #{name} TO #{new_name}")
      execute("RENAME SEQUENCE #{name}_seq TO #{new_name}_seq")
    end

    def drop_table(name)
      super(name)
      execute("DROP SEQUENCE #{name}_seq")
    end

    def remove_index(table_name, options = {})
      @connection.execute_update("DROP INDEX #{index_name(table_name, options)}")
    end

    def select(sql, *rest)
      # Informix does not like "= NULL", "!= NULL", or "<> NULL".
      super(sql.gsub(/(!=|<>)\s*null/i, "IS NOT NULL").gsub(/=\s*null/i, "IS NULL"), *rest)
    end

    private

    def db_major_version
      @@db_major_version ||=
        select_one("SELECT dbinfo('version', 'major') version FROM systables WHERE tabid = 1")['version'].to_i
    end

  end # module Informix
end # module ::ArJdbc

module ActiveRecord::ConnectionAdapters
  class InformixColumn < JdbcColumn
    include ::ArJdbc::Informix::ColumnMethods
  end

  class InformixAdapter < JdbcAdapter
    include ::ArJdbc::Informix
  end
end
