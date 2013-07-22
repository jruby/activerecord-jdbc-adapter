module ArJdbc
  module Util
    module TableCopier

      # taken from SQLite adapter, code loosely based on http://git.io/P7tFQA

      # Performs changes for table by first copying (and preserving contents)
      # into another (temporary) table, than alters and copies all data back.
      def alter_table(table_name, options = {})
        table_name = table_name.to_s.downcase
        altered_table_name = "a#{table_name}"
        caller = lambda { |definition| yield definition if block_given? }

        transaction do
          # A temporary table might improve performance here, but
          # it doesn't seem to maintain indices across the whole move.
          move_table(table_name, altered_table_name, options)
          move_table(altered_table_name, table_name, &caller)
        end
      end

      # Move a table into another while preserving all content.
      # @see #copy_table
      def move_table(from, to, options = {}, &block)
        copy_table(from, to, options, &block)
        drop_table(from)
      end

      # @see #copy_table_contents
      # @see #copy_table_indexes
      def copy_table(from, to, options = {})
        from_primary_key = primary_key(from)
        create_table(to, options.merge(:id => false)) do |definition|
          @definition = definition
          @definition.primary_key(from_primary_key) if from_primary_key.present?
          columns(from).each do |column|
            column_name = options[:rename] ?
              (options[:rename][column.name] ||
               options[:rename][column.name.to_sym] ||
               column.name) : column.name

            next if column_name == from_primary_key

            @definition.column(column_name, column.type,
              :limit => column.limit, :default => column.default,
              :precision => column.precision, :scale => column.scale,
              :null => column.null)
          end
          yield @definition if block_given?
        end

        copy_table_indexes(from, to, options[:rename] || {})
        copy_table_contents(from, to,
          @definition.columns.map {|column| column.name},
          options[:rename] || {})
      end

      # Copies indexes for a given table.
      def copy_table_indexes(from, to, rename = {})
        indexes(from).each do |index|
          name = index.name.downcase
          if to == "a#{from}"
            name = "t#{name}"
          elsif from == "a#{to}"
            name = name[1..-1]
          end

          to_column_names = columns(to).map(&:name)
          columns = index.columns.map { |column| rename[column] || column }
          columns = columns.select { |column| to_column_names.include?(column) }

          unless columns.empty?
            # index name can't be the same
            opts = { :name => name.gsub(/(^|_)(#{from})_/, "\\1#{to}_"), :internal => true }
            opts[:unique] = true if index.unique
            add_index(to, columns, opts)
          end
        end
      end

      # Copies the content of a table into another.
      def copy_table_contents(from, to, columns, rename = {})
        column_mappings = Hash[ columns.map { |name| [name, name] } ]
        rename.each { |a| column_mappings[a.last] = a.first }
        from_columns = columns(from).collect {|col| col.name}
        columns = columns.find_all{ |col| from_columns.include?(column_mappings[col]) }
        quoted_columns = columns.map { |col| quote_column_name(col) } * ','

        quoted_to = quote_table_name(to)

        raw_column_mappings = Hash[ columns(from).map { |c| [c.name, c] } ]

        execute("SELECT * FROM #{quote_table_name(from)}", 'Copy Table').each do |row|
          sql = "INSERT INTO #{quoted_to} (#{quoted_columns}) VALUES ("

          column_values = columns.map do |col|
            quote(row[column_mappings[col]], raw_column_mappings[col])
          end

          sql << column_values * ', '
          sql << ')'
          exec_insert sql, 'Copy Table', []
        end
      end

    end
  end
  # @private @deprecated backwards compatibility
  MissingFunctionalityHelper = Util::TableCopier
end