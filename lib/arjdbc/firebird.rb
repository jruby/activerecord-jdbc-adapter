require 'arjdbc'
require 'arjdbc/firebird/adapter'
require 'arjdbc/firebird/connection_methods'
ArJdbc.warn_unsupported_adapter 'firebird', [4, 2] # warns on AR >= 4.2