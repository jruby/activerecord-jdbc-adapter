# frozen_string_literal: true

require "active_model/type/helpers/time_value"

# The caller only handles ArgumentError as a failure,
# but JRuby raises TypeError for invalid formats in Time.new() (non-standard),
# which isn't handled by the caller.
# We just return nil here as it will result in fallback parsing, same as raising.
module ActiveModel
  module Type
    module Helpers
      module TimeValue
        module JRubyCompat
          private
            def fast_string_to_time(string)
              super
            rescue TypeError
              nil
            end
        end
        prepend JRubyCompat
      end
    end
  end
end
