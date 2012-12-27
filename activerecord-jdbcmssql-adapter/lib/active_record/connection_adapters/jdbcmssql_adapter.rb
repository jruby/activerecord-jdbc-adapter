require 'jdbc/jtds'
# NOTE: the adapter has only support for working with the
# open-source jTDS driver (won't work with MS's driver) !
Jdbc::JTDS.load_driver(:require) if Jdbc::JTDS.respond_to?(:load_driver)