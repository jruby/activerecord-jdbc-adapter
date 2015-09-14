require 'arjdbc'
require 'arjdbc/mimer/adapter'
ArJdbc.warn_unsupported_adapter 'mimer', [4, 2] # warns on AR >= 4.2