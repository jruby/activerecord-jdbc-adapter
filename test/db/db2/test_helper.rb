require 'db/db2'
require 'simple'
require 'row_locking'
require 'schema_dump'

DbTypeMigration.big_decimal_precision = 31 # DB2 maximum precision is 31 digit
