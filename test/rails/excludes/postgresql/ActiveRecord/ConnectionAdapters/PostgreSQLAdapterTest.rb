if ActiveRecord::Base.connection.prepared_statements
  exclude :test_exec_with_binds, 'it uses $1 for parameter mapping which is not currently supported'
  exclude :test_exec_typecasts_bind_vals, 'it uses $1 for parameter mapping which is not currently supported'
end

exclude :test_only_warn_on_first_encounter_of_unrecognized_oid, 'expects warning with OID, ARJBC has name instead'
exclude :test_default_sequence_name_bad_table, "ARJDBC does more quoting (which is not wrong)"
exclude :test_doesnt_error_when_a_set_query_is_called_while_preventing_writes, 'different return value for execute() in ARJCBC'
