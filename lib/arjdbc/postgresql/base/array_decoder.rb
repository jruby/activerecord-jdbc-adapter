# This implements a basic decoder to work around ActiveRecord's dependence on the pg gem
module PG
  module TextDecoder

    class Array
      # Loads pg_array_parser if available. String parsing can be
      # performed quicker by a native extension, which will not create
      # a large amount of Ruby objects that will need to be garbage
      # collected. pg_array_parser has a C and Java extension
      begin
        require 'pg_array_parser'
        include PgArrayParser
      rescue LoadError
        require_relative 'array_parser'
        include ActiveRecord::ConnectionAdapters::PostgreSQL::ArrayParser
      end

      def initialize(name:, delimiter:); end

      alias_method :decode, :parse_pg_array
    end

  end
end
