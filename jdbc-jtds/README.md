# jdbc-jtds

jTDS JDBC - SQL Server and Sybase JDBC driver gem for JRuby

jTDS is an open source (type 4) JDBC 3.0 driver for Microsoft SQL Server (6.5,
7, 2000, 2005, 2008 and 2012) and Sybase Adaptive Server (10, 11, 12 and 15).

For more information see http://jtds.sourceforge.net/

## Usage

To make the driver accessible to JDBC with JRuby :

    require 'jdbc/jtds'
    Jdbc::JTDS.load_driver

For backwards compatibility with older (**1.2.5**) versions of the gem use :

    require 'jdbc/jtds'
    Jdbc::JTDS.load_driver(:require) if Jdbc::JTDS.respond_to?(:load_driver)

**NOTE:** jTDS **1.3.x** requires Java 7, if you're on Java 6 use **1.2.x**.

## Copyright

Copyright (c) 2012-2014 [The JRuby Team](https://github.com/jruby).

jTDS is made available under the terms of the GNU Lesser General Public License,
see *LICENSE.txt* and http://jtds.sourceforge.net/license.html for more details.
