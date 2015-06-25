# jdbc-firebird

FireBird is a (open-source) relational database offering many ANSI SQL standard
features that runs on Linux, Windows, and a variety of Unix platforms.
Firebird offers excellent concurrency, high performance, and powerful language
support for stored procedures and triggers.
It has been used in production systems, under a variety of names, since 1981.

For more information see http://www.firebirdsql.org/

## Usage

To make the JayBird driver accessible to JDBC and ActiveRecord in JRuby use :

    require 'jdbc/firebird'
    Jdbc::Firebird.load_driver

## Copyright

Copyright (c) 2014-2015 [The JRuby Team](https://github.com/jruby).

Jaybird JDBC driver is distributed under the GNU Lesser General Public License (LGPL)
see *LICENSE.txt* and  http://www.gnu.org/copyleft/lesser.html for more details.
