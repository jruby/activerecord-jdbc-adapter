# jdbc-as400

IBM i formerly AS/400 is a IBM proprietary operating system. It has a built-in support of DB2 with some particularities.

Some key advantages include:
 * Robust and efficient
 * Java compatibility
 * OS/400 database compatibility


For more information see http://www-03.ibm.com/systems/power/software/i/db2/index.html

## Usage

To make the driver accessible to JDBC and ActiveRecord code running in JRuby :

    require 'jdbc/as400'
    Jdbc::AS400.load_driver

## Compatibility

The shipped driver is the JDBC 4.0 with native optimizations version.
It's only compatible with IBM i V5R1 or later.
Java 1.6 or later is required.

## Copyright

Copyright (c) 2012 [The JRuby Team](https://github.com/jruby).

Apache Derby is available under the Apache License, Version 2.0
see *LICENSE.txt* and http://db.apache.org/derby/license.html for more details.
