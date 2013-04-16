module Mysql # :nodoc:
  remove_const(:Error) if const_defined?(:Error)
  class Error < ::ActiveRecord::JDBCError; end

  def self.client_version
    50400 # faked out for AR tests
  end
end