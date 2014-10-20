module ActiveRecord

  if defined? ConnectionAdapters::ConnectionSpecification::Resolver # 4.0
    ConnectionAdapters::ConnectionSpecification::Resolver
  elsif defined? Base::ConnectionSpecification::Resolver # 3.2
    Base::ConnectionSpecification::Resolver
  else class << Base; self; end # 2.3, 3.0, 3.1 :
    # def self.establish_connection ... on ActiveRecord::Base
  end.class_eval do

    # @private
    def require(path)
      # NOTE: we're inspecting resolver.spec connection resolution which does :
      # `require "active_record/connection_adapters/#{spec[:adapter]}_adapter"`
      # ...
      # this {#require} method is only re-defined on a Resolver object and thus
      # will not hurt performance - it will only be called for a few times (most
      # likely once), this should still be fine for AR < 3.2 where this patch
      # ends up on `class << ActiveRecord::Base` since models usually rely on
      # Rails's auto-loading of (missing) constants and rarely use `require`.
      #
      # other alternative (to make sure we do not need to eager load AR built-in
      #  adapters) would be to mingle with the $LOAD_PATH which seems worse ...
      case path
      when 'active_record/connection_adapters/mysql_adapter'
        $LOADED_FEATURES << 'active_record/connection_adapters/mysql_adapter.rb'
        super('arjdbc/mysql')
      when 'active_record/connection_adapters/mysql2_adapter'
        $LOADED_FEATURES << 'active_record/connection_adapters/mysql2_adapter.rb'
        super('arjdbc/mysql')
      when 'active_record/connection_adapters/postgresql_adapter'
        $LOADED_FEATURES << 'active_record/connection_adapters/postgresql_adapter.rb'
        super('arjdbc/postgresql')
      when 'active_record/connection_adapters/sqlite_adapter'
        $LOADED_FEATURES << 'active_record/connection_adapters/sqlite_adapter.rb'
        super('arjdbc/sqlite3')
      when 'active_record/connection_adapters/sqlite3_adapter'
        $LOADED_FEATURES << 'active_record/connection_adapters/sqlite3_adapter.rb'
        super('arjdbc/sqlite3')
      else super
      end
    end

  end

end