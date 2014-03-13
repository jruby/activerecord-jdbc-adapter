require 'set'
require 'active_support/deprecation'

module ArJdbc

  class << self

    def warn(message, once = nil)
      super(message) || true if warn?(message, once)
    end

    def deprecate(message, once = nil)
      ActiveSupport::Deprecation.warn(message, caller) || true if warn?(message, once)
    end

    private

    @@warns = Set.new

    def warn?(message, once)
      return nil unless message
      return true if ! once
      @@warns << message.dup unless printed = @@warns.include?(message)
      ! printed
    end

  end

  require 'arjdbc/jdbc/adapter'

  if Java::JavaLang::Boolean.getBoolean('arjdbc.extensions.discover')
    self.discover_extensions
  else
    require 'arjdbc/discover'
  end
end