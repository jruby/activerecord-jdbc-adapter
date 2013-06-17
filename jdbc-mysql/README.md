# jdbc-mysql

MySQL Connector/J is the official JDBC driver for MySQL.

It is a native Java driver that converts JDBC (Java Database Connectivity)
calls into the network protocol used by the MySQL database.

For more information see http://dev.mysql.com/usingmysql/java/

## Usage

To make the driver accessible to JDBC and ActiveRecord code running in JRuby :

    require 'jdbc/mysql'
    Jdbc::MySQL.load_driver

For backwards compatibility with older (<= **5.1.13**) versions of the gem use :

    require 'jdbc/mysql'
    Jdbc::MySQL.load_driver(:require) if Jdbc::MySQL.respond_to?(:load_driver)

## Copyright

Copyright (c) 2013 [The JRuby Team](https://github.com/jruby).

MySQL open source software is provided under the GPL (2.0) License,
see *LICENSE.txt* and http://www.gnu.org/licenses/old-licenses/gpl-2.0.html .
