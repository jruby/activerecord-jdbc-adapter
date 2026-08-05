# frozen_string_literal: true

# Minimal subset of the libpq constants that ActiveRecord's native PostgreSQL
# code paths reference as ::PG::* (e.g. #retryable_query_error? checks
# transaction_status against PQTRANS_INERROR, and the Rails test-suite helper
# +remote_disconnect+ uses CONNECTION_BAD / PQTRANS_INTRANS).
#
# The matching #status / #transaction_status / #async_exec methods are defined
# on the JDBC connection (PostgreSQLRubyJdbcConnection) in the Java extension.
#
# Only defined when the real pg gem is absent (i.e. under JRuby).
unless defined?(PG)
  module PG
    # PQtransactionStatus
    PQTRANS_IDLE    = 0 # connection idle, no transaction open
    PQTRANS_ACTIVE  = 1 # command in progress
    PQTRANS_INTRANS = 2 # idle, within a transaction block
    PQTRANS_INERROR = 3 # idle, within a failed transaction block
    PQTRANS_UNKNOWN = 4 # connection is bad / state cannot be determined

    # PQstatus (subset that AR uses)
    CONNECTION_OK  = 0
    CONNECTION_BAD = 1
  end
end
