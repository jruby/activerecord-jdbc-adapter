require 'arjdbc/h2'
Jdbc::H2.load_driver(:require) if Jdbc::H2.respond_to?(:load_driver)