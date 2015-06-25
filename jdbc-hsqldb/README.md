# jdbc-hsqldb

 HSQLDB (HyperSQL DataBase) is the leading SQL relational database engine written
 in Java. It offers a small, fast multithreaded and transactional database engine
 with in-memory and disk-based tables and supports embedded and server modes.
 It includes a powerful command line SQL tool and simple GUI query tools.

For more information see http://hsqldb.org/

## Usage

To make the driver accessible to JDBC and ActiveRecord code running in JRuby :

    require 'jdbc/hsqldb'
    Jdbc::HSQLDB.load_driver

For backwards compatibility with older (<= **1.8.1.3**) versions of the gem use :

    require 'jdbc/hsqldb'
    Jdbc::HSQLDB.load_driver(:require) if Jdbc::HSQLDB.respond_to?(:load_driver)

## Copyright

Copyright (c) 2013-2015 [The JRuby Team](https://github.com/jruby).

HSQLDB is completely free to use and distribute under a license based on the
standard BSD license and fully compatible with all major open source licenses.
see *LICENSE.txt* and http://hsqldb.org/web/hsqlLicense.html for more details.
