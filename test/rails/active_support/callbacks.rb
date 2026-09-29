# Partial workaround for JRuby having no GIL - tests like the reaper etc spuriously fail due to multithreaded test execution
# assuming a GIL that does not actually exist for JRuby. We really do love non-deterministic multithreaded execution,
# it never, ever causes random bugs that spuriously fail without any consistent way to reproduce them!
# Multithreading. Not even once.
# Do we want to make this happen both in and out of tests? Might be worth considering.

# We want to inject *after* this is loaded, so gonna load it first. There's probably a better way to do this.
real = $LOAD_PATH
  .map { |dir| File.expand_path(File.join(dir, "active_support", "callbacks.rb")) }
  .find { |path| path != File.expand_path(__FILE__) && File.exist?(path) }
require real

require "monitor"

module ActiveSupport
  module Callbacks
    module ClassMethods
      REGISTRATION_MONITOR = Monitor.new

      module ThreadSafeRegistration
        def set_callback(*, &block)
          REGISTRATION_MONITOR.synchronize { super }
        end

        def skip_callback(*, &block)
          REGISTRATION_MONITOR.synchronize { super }
        end

        def reset_callbacks(*)
          REGISTRATION_MONITOR.synchronize { super }
        end

        def define_callbacks(*)
          REGISTRATION_MONITOR.synchronize { super }
        end

        protected
          # Publish by atomic reference swap rather than the in-place mutation the
          # original performs, so unlocked readers never see a torn hash.
          def set_callbacks(name, callbacks)
            REGISTRATION_MONITOR.synchronize do
              new_callbacks = __callbacks.dup
              new_callbacks[name.to_sym] = callbacks
              self.__callbacks = new_callbacks
            end
          end
      end

      prepend ThreadSafeRegistration
    end
  end
end
