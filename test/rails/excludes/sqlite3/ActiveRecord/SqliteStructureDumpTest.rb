# This is a horrible hack. it patches SQLite database tasks before running the test.
# normally, the patch is done while loading the ARJDBC rake tests, but for these tests,
# the tasks are never loaded, so do it here
require 'arjdbc/tasks/sqlite_database_tasks_patch'

exclude :test_structure_dump_execution_fails, 'ARJDBC not using Kernel.system'
