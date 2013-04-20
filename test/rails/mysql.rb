module Mysql # :nodoc:
  # remove_const(:Error) if const_defined?(:Error)
  class Error < StandardError; end

  def self.client_version
    50400 # faked out for AR tests
  end
  
  #module GemVersion
  #  VERSION = '2.8.2'
  #end
  
end