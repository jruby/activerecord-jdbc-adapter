require 'db/derby'
require 'simple'
require 'row_locking'
require 'schema_dump'

DbTypeMigration.big_decimal_precision = 31 # DECIMAL precision between 1 and 31
