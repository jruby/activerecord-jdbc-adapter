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
    Jdbc::FireBird.load_driver

## Copyright

Copyright (c) 2013 [The JRuby Team](https://github.com/jruby).

Firebird is licensed and available under a modified version of the MPL 
(Initial Developer's Public License ) 
see  http://www.firebirdsql.org/en/initial-developer-s-public-license-version-1-0/ for more details.
