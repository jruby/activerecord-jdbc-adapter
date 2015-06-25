# jdbc-sqlite3

SQLite JDBC driver enables Java to access SQLite database files.

SQLite JDBC library requires no configuration since all native libraries for
Windows, Mac OS X, Linux and pure-java SQLite, which works in any OS enviroment,
are assembled into a single JAR (Java Archive) file.

For more information see http://code.google.com/p/sqlite-jdbc/
and/or https://bitbucket.org/xerial/sqlite-jdbc/wiki/Home

## Usage

To make the driver accessible to JDBC and ActiveRecord code running in JRuby :

    require 'jdbc/sqlite3'
    Jdbc::SQLite3.load_driver

For backwards compatibility with older (<= **3.7.2**) versions of the gem use :

    require 'jdbc/sqlite3'
    Jdbc::SQLite3.load_driver(:require) if Jdbc::SQLite3.respond_to?(:load_driver)

## Copyright

Copyright (c) 2013-2015 [The JRuby Team](https://github.com/jruby).

SQLite JDBC is distributed under the Apache License 2.0, see *LICENSE.txt*.
