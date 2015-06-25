# jdbc-postgres

PostgreSQL JDBC driver allows Java programs to connect to a PostgreSQL database
using standard, database independent Java code - it's a pure Java (Type 4) impl.

For more information see http://jdbc.postgresql.org/

## Usage

To make the driver accessible to JDBC and ActiveRecord code running in JRuby :

    require 'jdbc/postgres'
    Jdbc::Postgres.load_driver

For backwards compatibility with older (<= **9.1.903**) versions of the gem use :

    require 'jdbc/postgres'
    Jdbc::Postgres.load_driver(:require) if Jdbc::Postgres.respond_to?(:load_driver)

## Copyright

Copyright (c) 2012-2015 [The JRuby Team](https://github.com/jruby).

The PostgreSQL JDBC driver is distributed under the BSD license,
see *LICENSE.txt* and http://jdbc.postgresql.org/license.html for details.
