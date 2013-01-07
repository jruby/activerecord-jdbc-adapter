# jdbc-derby

Apache Derby, an Apache DB subproject, is an open source relational database 
implemented entirely in Java.

Some key advantages include:
 * small footprint -- about 2.6 megabytes for the base engine and embedded JDBC driver.
 * Derby is based on the Java, JDBC, and SQL standards.
 * provides an embedded JDBC driver that lets you embed Derby in any Java-based solution.
 * supports client/server mode with the Derby Network Client JDBC driver and Derby Network Server.
 * Derby is easy to install, deploy, and use.

For more information see http://db.apache.org/derby/

## Java DB

Java DB is Oracle's supported distribution of the Apache Derby open source database. 
It supports standard ANSI/ISO SQL through the JDBC and Java EE APIs. 
Java DB is included in the JDK since Java 6 (1.6).

See http://www.oracle.com/technetwork/java/javadb/overview/index.html

## Usage

To make the driver accessible to JDBC and ActiveRecord code running in JRuby :

    require 'jdbc/derby'
    Jdbc::Derby.load_driver

For backwards compatibility with older (<= **10.6.2.1**) versions of the gem use :

    require 'jdbc/derby'
    Jdbc::Derby.load_driver(:require) if Jdbc::Derby.respond_to?(:load_driver)

## Copyright

Copyright (c) 2012 [The JRuby Team](https://github.com/jruby).

Apache Derby is available under the Apache License, Version 2.0
see *LICENSE.txt* and http://db.apache.org/derby/license.html for more details.
