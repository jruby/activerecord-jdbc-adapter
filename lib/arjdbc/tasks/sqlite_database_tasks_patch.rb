# patch SQLiteDatabaseTasks for JRuby
# The problem is that JRuby does not yet support the "out:" option for
# Kernel.system(). Uses plain output redirection as a workaround.

require 'active_record/tasks/sqlite_database_tasks'
require 'shellwords'

module ActiveRecord
  module Tasks
    class SQLiteDatabaseTasks
      private
        def run_cmd(cmd, args, out)
          `#{cmd} #{Shellwords.join(args)} > "#{out}"`
        end
    end
  end
end
