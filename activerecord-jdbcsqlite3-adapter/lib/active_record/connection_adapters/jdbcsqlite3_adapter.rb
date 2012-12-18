require 'arjdbc/sqlite3'
Jdbc::SQLite3.load_driver(:require) if Jdbc::SQLite3.respond_to?(:load_driver)