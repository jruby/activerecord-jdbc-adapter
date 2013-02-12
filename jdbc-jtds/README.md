# jdbc-jtds

jTDS - SQL Server and Sybase JDBC driver gem for JRuby

Open source JDBC 3.0 type 4 driver for Microsoft SQL Server (6.5 up to 2012) and Sybase ASE. 
jTDS is a complete implementation of the JDBC 3.0 spec and the fastest JDBC driver for MS SQL Server. 

For more information see http://jtds.sourceforge.net/

## Usage

To make the driver (Java class) accessible to JDBC and ActiveRecord code running in JRuby :

    require 'jdbc/jtds'
    Jdbc::JTDS.load_driver

For backwards compatibility with older (**1.2.5**) versions of the gem use :

    require 'jdbc/jtds'
    Jdbc::JTDS.load_driver(:require) if Jdbc::JTDS.respond_to?(:load_driver)

NOTE: jTDS **1.3.0** requires Java 7 or newer, if you're on older Java please use **1.2.x**.

## Copyright

Copyright (c) 2012 [The JRuby Team](https://github.com/jruby).

jTDS is made available under the terms of the GNU Lesser General Public License, 
see *LICENSE.txt* and http://jtds.sourceforge.net/license.html for more details.
