require 'arjdbc/postgresql'
Jdbc::Postgres.load_driver(:require) if Jdbc::Postgres.respond_to?(:load_driver)