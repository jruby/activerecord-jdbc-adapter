activerecord-jdbc-adapter is a database adapter for Rails' ActiveRecord
component that can be used with JRuby[http://www.jruby.org/]. It allows use of
virtually any JDBC-compliant database with your JRuby on Rails application.

== Project Info

* Mailing Lists: http://kenai.com/projects/activerecord-jdbc/lists
* Issues: http://kenai.com/jira/browse/ACTIVERECORD_JDBC
* Source: git://kenai.com/activerecord-jdbc~main 
  	  git://github.com/nicksieger/activerecord-jdbc-adapter.git

== Databases

What's there, and what is not there:

* MySQL - Complete support
* PostgreSQL - Complete support
* Oracle - Complete support
* Microsoft SQL Server - Complete support except for change_column_default
* DB2 - Complete, except for the migrations:
  * change_column 
  * change_column_default
  * remove_column
  * rename_column
  * add_index
  * remove_index
  * rename_table
* FireBird - Complete, except for change_column_default and rename_column
* Derby - Complete, except for:
  * change_column
  * change_column_default
  * remove_column
  * rename_column
* HSQLDB - Complete
* H2 - Complete
* SQLite3 - work in progress
* Informix - Fairly complete support, all tests pass and migrations appear to work.  Comments welcome.

Other databases will require testing and likely a custom configuration module.
Please join the activerecord-jdbc
mailing-lists[http://kenai.com/projects/activerecord-jdbc/lists] to help us discover
support for more databases.

== Using ActiveRecord JDBC

=== Inside Rails

To use activerecord-jdbc-adapter with JRuby on Rails:

1. Choose the adapter you wish to gem install. The following pre-packaged
   adapters are available:

  * base jdbc (<tt>activerecord-jdbc-adapter</tt>). Supports all available databases via JDBC, but requires you to download and manually install the database vendor's JDBC driver .jar file.
  * mysql (<tt>activerecord-jdbcmysql-adapter</tt>)
  * postgresql (<tt>activerecord-jdbcpostgresql-adapter</tt>)
  * derby (<tt>activerecord-jdbcderby-adapter</tt>)
  * hsqldb (<tt>activerecord-jdbchsqldb-adapter</tt>)
  * h2 (<tt>activerecord-jdbch2-adapter</tt>)
  * sqlite3 (<tt>activerecord-jdbcsqlite3-adapter</tt>)

2. Run the "jdbc" generator to prepare your Rails application for
   JDBC.

    jruby script/generate jdbc
    
   The initializer and rake task files generated are guarded such that
   they won't be loaded if you still run your application un C Ruby.

   Legacy: If you're using Rails prior to version 2.0, you'll need to
   add one-time setup to your config/environment.rb file in your Rails
   application. Add the following lines just before the
   <code>Rails::Initializer</code>. (If you're using
   activerecord-jdbc-adapter under the old gem name used in versions
   0.5 and earlier (ActiveRecord-JDBC), replace
   'activerecord-jdbc-adapter' with 'ActiveRecord-JDBC' below.)

    if RUBY_PLATFORM =~ /java/
      require 'rubygems'
      gem 'activerecord-jdbc-adapter'
      require 'jdbc_adapter'
    end

3. Configure your database.yml in the normal Rails style. 

   Legacy configuration: If you use one of the convenience
   'activerecord-jdbcXXX-adapter' adapters, you can still put a 'jdbc'
   prefix in front of the databas adapter name as below.

    development:
      adapter: jdbcmysql
      username: blog
      password:
      hostname: localhost
      database: weblog_development

   For other databases, you'll need to know the database driver class
   and URL. Example:

    development:
      adapter: jdbc
      username: blog
      password:
      driver: com.mysql.jdbc.Driver
      url: jdbc:mysql://localhost:3306/weblog_development

=== Standalone, with ActiveRecord

1. Install the gem with JRuby:

    jruby -S gem install activerecord-jdbc-adapter

   If you wish to use the adapter for a specific database, you can install it
   directly and a driver gem will be installed as well:

    jruby -S gem install activerecord-jdbcderby-adapter

2. If using ActiveRecord 2.0 (Rails 2.0) or greater, you can skip to the next
   step. Otherwise, ensure the following code gets executed in your script:

    require 'rubygems'
    gem 'activerecord-jdbc-adapter'
    require 'jdbc_adapter'
    require 'active_record'

3. After this you can establish a JDBC connection like this:

    ActiveRecord::Base.establish_connection(
      :adapter => 'jdbcderby',
      :database => "db/my-database"
    )

   or like this (but requires that you manually put the driver jar on the classpath):

    ActiveRecord::Base.establish_connection(
      :adapter => 'jdbc',
      :driver => 'org.apache.derby.jdbc.EmbeddedDriver',
      :url => 'jdbc:derby:test_ar;create=true'
    )

== Getting the source

The source for activerecord-jdbc-adapter is available using git.

  git clone git://github.com/nicksieger/activerecord-jdbc-adapter.git

== Feedback

Please file bug reports at
http://kenai.com/jira/browse/ACTIVERECORD_JDBC. If you're not sure if
something's a bug, feel free to pre-report it on the mailing lists.

== Running AR-JDBC's Tests

Drivers for 6 open-source databases are included. Provided you have MySQL
installed, you can simply type <tt>jruby -S rake</tt> to run the tests. A
database named <tt>weblog_development</tt> is needed beforehand with a
connection user of "blog" and an empty password.

If you also have PostgreSQL available, those tests will be run if the
`psql' executable can be found. Also ensure you have a database named
<tt>weblog_development</tt> and a user named "blog" and an empty
password.

If you want rails logging enabled during these test runs you can edit 
test/jdbc_common.rb and add the following line:

require 'db/logger'

== Running AR Tests

To run the current AR-JDBC sources with ActiveRecord, just use the
included "rails:test" task. Be sure to specify a driver and a path to
the ActiveRecord sources.

  jruby -S rake rails:test DRIVER=mysql RAILS=/path/activerecord_source_dir

== Authors

This project was written by Nick Sieger <nick@nicksieger.com> and Ola Bini
<olabini@gmail.com> with lots of help from the JRuby community.

== License

activerecord-jdbc-adapter is released under a BSD license. See the LICENSE file
included with the distribution for details.

Open-source driver gems for activerecord-jdbc-adapter are licensed under the
same license the database's drivers are licensed. See each driver gem's
LICENSE.txt file for details.
