require 'active_support/raise_warnings'

# This module flags methods in rails tests and blows up ours
module ActiveSupport
  module RaiseWarnings # :nodoc:
    begin
      allowed = remove_const(:ALLOWED_WARNINGS)
      const_set(:ALLOWED_WARNINGS, Regex.union(allowed, /previous definition of/))
    end
  end
end