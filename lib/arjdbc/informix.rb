require 'arjdbc'
ArJdbc.load_java_part :Informix
require 'arjdbc/informix/adapter'
require 'arjdbc/informix/connection_methods'
ArJdbc.warn_unsupported_adapter 'informix', [4, 2] # warns on AR >= 4.2