# jdbc-h2

 H2 is a Java SQL database. The main features of H2 are:

 * Very fast, open source, JDBC API
 * Embedded and server modes; in-memory databases
 * Browser based Console application
 * Small footprint: around 1 MB jar file size 

For more information see http://www.h2database.com/

## Usage

To make the driver accessible to JDBC and ActiveRecord code running in JRuby :

    require 'jdbc/h2'
    Jdbc::H2.load_driver

For backwards compatibility with older (<= **1.3.154**) versions of the gem use :

    require 'jdbc/h2'
    Jdbc::H2.load_driver(:require) if Jdbc::H2.respond_to?(:load_driver)

## Copyright

Copyright (c) 2012 [The JRuby Team](https://github.com/jruby).

H2 is dual licensed and available under a modified version of the MPL 1.1 
(Mozilla Public License) or under the (unmodified) EPL 1.0 (Eclipse Public License).
see *LICENSE.txt* and http://www.h2database.com/html/license.html for more details.
