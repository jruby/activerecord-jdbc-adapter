# Needed because Rails is broken wrt to quoting of some values.
# Most databases are nice about it, but not Derby.
# The real issue is that you can't compare a CHAR value to a NUMBER column.
ActiveRecord::Associations::ClassMethods.module_eval do
  private
  def select_limited_ids_list(options, join_dependency)
    return super unless connection.is_a?(ArJdbc::Derby)
    connection.select_all(
      construct_finder_sql_for_association_limiting(options, join_dependency),
      "#{name} Load IDs For Limited Eager Loading"
    ).collect { |row| connection.quote(row[primary_key], columns_hash[primary_key]) }.join(", ")
  end
end