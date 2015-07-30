require 'arjdbc'
require 'arjdbc/oracle/adapter'
require 'arjdbc/oracle/connection_methods'
ArJdbc.warn_unsupported_adapter 'oracle', [4, 2] # warns on AR >= 4.2