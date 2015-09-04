module ArJdbc
  module Util
    # Caches table and column name (quoted) outcomes.
    # Uses {ThreadSafe::Cache} as a concurrent lock free (on JRuby) cache backend.
    # The thread_safe gem is a dependency since ActiveSupport 4.0, when using
    # ActiveRecord <= 3.2 one should add `gem 'thread_safe'` into the *Gemfile*
    # as it is not forced (currently) as an explicit gem dependency.
    #
    # Caching can also be disabled by setting the *arjdbc.quoted_cache.disabled*
    # system property = 'true'.
    module QuotedCache

      # @private
      DISABLED = Java::JavaLang::Boolean.getBoolean('arjdbc.quoted_cache.disabled')

      def self.included(base)
        # the thread_safe gem is an ActiveSupport dependency (since 4.0) :
        begin; require 'thread_safe'; rescue LoadError; end unless DISABLED
        if ! DISABLED && defined? ThreadSafe::Cache
          base.const_set :QUOTED_TABLE_NAMES, ThreadSafe::Cache.new
          base.const_set :QUOTED_COLUMN_NAMES, ThreadSafe::Cache.new
        else
          base.const_set :QUOTED_TABLE_NAMES, nil
          base.const_set :QUOTED_COLUMN_NAMES, nil
        end
      end

      # Caches quoted table names, the cache is stored in the class'
      # `QUOTED_TABLE_NAMES` constant.
      # @return [String]
      def quote_table_name(name, *args)
        if cache = self.class::QUOTED_TABLE_NAMES
          unless quoted = cache[name]
            quoted = super
            cache.put_if_absent name, quoted.freeze
          end
          quoted
        else
          super
        end
      end

      # Caches quoted table names, the cache is stored in the class'
      # `QUOTED_COLUMN_NAMES` constant.
      # @return [String]
      def quote_column_name(name, *args)
        if cache = self.class::QUOTED_COLUMN_NAMES
          unless quoted = cache[name]
            quoted = super
            cache.put_if_absent name, quoted.freeze
          end
          quoted
        else
          super
        end
      end

    end
  end
end