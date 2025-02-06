# frozen_string_literal: true

module SQLite3
  # defines methods to de generate pragma statements
  module Pragmas
    class << self
      # The enumeration of valid synchronous modes.
      SYNCHRONOUS_MODES = [["full", 2], ["normal", 1], ["off", 0]].freeze

      # The enumeration of valid temp store modes.
      TEMP_STORE_MODES = [["default", 0], ["file", 1], ["memory", 2]].freeze

      # The enumeration of valid auto vacuum modes.
      AUTO_VACUUM_MODES = [["none", 0], ["full", 1], ["incremental", 2]].freeze

      # The list of valid journaling modes.
      JOURNAL_MODES = [["delete"], ["truncate"], ["persist"], ["memory"], ["wal"], ["off"]].freeze

      # The list of valid locking modes.
      LOCKING_MODES = [["normal"], ["exclusive"]].freeze

      # The list of valid encodings.
      ENCODINGS = [["utf-8"], ["utf-16"], ["utf-16le"], ["utf-16be"]].freeze

      # The list of valid WAL checkpoints.
      WAL_CHECKPOINTS = [["passive"], ["full"], ["restart"], ["truncate"]].freeze

      # Enforce foreign key constraints
      # https://www.sqlite.org/pragma.html#pragma_foreign_keys
      # https://www.sqlite.org/foreignkeys.html
      def foreign_keys(value)
        gen_boolean_pragma(:foreign_keys, value)
      end

      # Journal mode WAL allows for greater concurrency (many readers + one writer)
      # https://www.sqlite.org/pragma.html#pragma_journal_mode
      def journal_mode(value)
        gen_enum_pragma(:journal_mode, value, JOURNAL_MODES)
      end

      # Set more relaxed level of database durability
      # 2 = "FULL" (sync on every write), 1 = "NORMAL" (sync every 1000 written pages) and 0 = "NONE"
      # https://www.sqlite.org/pragma.html#pragma_synchronous
      def synchronous(value)
        gen_enum_pragma(:synchronous, value, SYNCHRONOUS_MODES)
      end

      def temp_store(value)
        gen_enum_pragma(:temp_store, value, TEMP_STORE_MODES)
      end

      # Set the global memory map so all processes can share some data
      # https://www.sqlite.org/pragma.html#pragma_mmap_size
      # https://www.sqlite.org/mmap.html
      def mmap_size(value)
        "PRAGMA mmap_size = #{value.to_i}"
      end

      # Impose a limit on the WAL file to prevent unlimited growth
      # https://www.sqlite.org/pragma.html#pragma_journal_size_limit
      def journal_size_limit(value)
        "PRAGMA journal_size_limit = #{value.to_i}"
      end

      # Set the local connection cache to 2000 pages
      # https://www.sqlite.org/pragma.html#pragma_cache_size
      def cache_size(value)
        "PRAGMA cache_size = #{value.to_i}"
      end

      private

      def gen_boolean_pragma(name, mode)
        case mode
        when String
          case mode.downcase
          when "on", "yes", "true", "y", "t" then mode = "'ON'"
          when "off", "no", "false", "n", "f" then mode = "'OFF'"
          else
            raise ActiveRecord::JDBCError, "unrecognized pragma parameter #{mode.inspect}"
          end
        when true, 1
          mode = "ON"
        when false, 0, nil
          mode = "OFF"
        else
          raise ActiveRecord::JDBCError, "unrecognized pragma parameter #{mode.inspect}"
        end

        "PRAGMA #{name} = #{mode}"
      end

      def gen_enum_pragma(name, mode, enums)
        match = enums.find { |p| p.find { |i| i.to_s.downcase == mode.to_s.downcase } }

        unless match
          # Unknown pragma value
          raise ActiveRecord::JDBCError, "unrecognized #{name} #{mode.inspect}"
        end

        "PRAGMA #{name} = '#{match.first.upcase}'"
      end
    end
  end
end
