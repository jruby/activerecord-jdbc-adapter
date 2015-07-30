require 'arjdbc'
require 'arjdbc/db2/adapter'
require 'arjdbc/db2/connection_methods'
ArJdbc.warn_unsupported_adapter 'db2', [4, 2] # warns on AR >= 4.2