require 'jdbc/mysql'
Jdbc::MySQL.load_driver(:require) if Jdbc::MySQL.respond_to?(:load_driver)