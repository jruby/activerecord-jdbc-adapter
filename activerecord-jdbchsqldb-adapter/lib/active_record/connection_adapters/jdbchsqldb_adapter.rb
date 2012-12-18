require 'arjdbc/hsqldb'
Jdbc::HSQLDB.load_driver(:require) if Jdbc::HSQLDB.respond_to?(:load_driver)