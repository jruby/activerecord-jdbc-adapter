# This implements a basic encoder to work around ActiveRecord's dependence on the pg gem
module PG
  module TextEncoder
    class Array

      def initialize(name:, delimiter:)
        @type = if name == 'string[]'.freeze
                  'text'
                else
                  base_type = name.chomp('[]'.freeze).to_sym
                  ActiveRecord::Base.connection.native_database_types[base_type][:name]
                end
      end

      def encode(values)
        ActiveRecord::Base.connection.jdbc_connection.create_array_of(@type, values.to_java).to_s
      end

    end
  end
end
