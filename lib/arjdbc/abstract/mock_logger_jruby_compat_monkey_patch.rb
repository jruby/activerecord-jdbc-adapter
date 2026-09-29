# frozen_string_literal: true

require "active_support/log_subscriber/test_helper"

# As of prism 1.9.0 (possibly earlier), a polyfill exists to handle logging warnings for ruby impls that lack `category:`.
# As a result of this injection being a public method (as opposed to CRuby's private version),
# on at least JRuby 10.0.5.0, MockLogger#method_missing never gets hit, which breaks a number of tests.
# This monkeypatch adds support to the MockLogger to properly capture these log events in spite of this difference.
module ActiveSupport
  class LogSubscriber
    module TestHelper
      class MockLogger
        module JRubyCompat
          ActiveSupport::Logger::Severity.constants.each do |severity|
            level = severity.downcase
            define_method(level) do |message = nil, &block|
              @logged[level] << (block ? block.call : message)
            end
          end
        end
        prepend JRubyCompat
      end
    end
  end
end
