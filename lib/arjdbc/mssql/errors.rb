module ActiveRecord
  # Error raised when adapter determines the database could not acquire
  # a necessary lock before timing out
  class LockTimeout < StatementInvalid
  end
end
