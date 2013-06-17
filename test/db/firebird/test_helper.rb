require 'db/firebird'
require 'simple'
require 'has_many_through'
require 'row_locking'
require 'schema_dump'

DbTypeMigration.big_decimal_precision = 18 # Precision must be from 1 to 18
