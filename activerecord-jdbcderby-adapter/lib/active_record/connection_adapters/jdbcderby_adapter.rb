require 'jdbc/derby'
Jdbc::Derby.load_driver(:require) if Jdbc::Derby.respond_to?(:load_driver)