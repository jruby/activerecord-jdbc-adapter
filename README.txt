ActiveRecord-JDBC is a database adapter for Rails' ActiveRecord component that can be used with JRuby[http://www.jruby.org/].  It allows use of virtually any JDBC-compliant database with your JRuby on Rails application.

ActiveRecord JDBC is a sub-project of jruby-extras at RubyForge.


== Databases -- What's there, and what is not there

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

Other databases will require testing and likely a custom configuration module.  Please join the 
jruby-extras mailing-list[http://rubyforge.org/mail/?group_id=2014] to help us discover support for more databases.

== Using ActiveRecord JDBC

=== Standalone, with ActiveRecord

Using this adapter is very simple, but requires that you manually add the
adapter. So, to use it in a script, add this to the requires':
  RAILS_CONNECTION_ADAPTERS = ['jdbc']
  require 'active_record'

After this you can establish a JDBC connection like this:

  ActiveRecord::Base.establish_connection(
    :adapter => 'jdbc',
    :driver => 'org.apache.derby.jdbc.EmbeddedDriver',
    :url => 'jdbc:derby:test_ar;create=true'
  )

Provided you have the derby libraries in your classpath, this is enough
to establish an in-memory JDBC connection. The required parameters to
establish_connection for ActiveRecord JDBC are:

* adapter
* driver
* url

If provided, password and username will be used. After the connection is established
Active Record can be used as usual.

=== Inside Rails

To use ActiveRecord-JDBC with JRuby on Rails:

1. Install the gem with JRuby:
    jruby --command gem install ActiveRecord-JDBC
2. Add one-time setup to your config/environment.rb file in your Rails application.  Add the following lines just before the <code>Rails::Initializer</code>.
    require 'rubygems'
    gem 'ActiveRecord-JDBC'
3. Configure your database.yml to use the <code>jdbc</code> adapter.  For now, you'll need to know the database driver class and URL.  Example:
    development:
      adapter: jdbc
      username: blog
      password:
      driver: com.mysql.jdbc.Driver
      url: jdbc:mysql://localhost:3306/weblog_development

== Testing

By default hsql, mysql, and derby are run.  In order to run all tests you 
must download each of the databases about put their JDBC drivers in your
classpath.  Here is an example of I use:

  CLASSPATH=~/opt/derby/lib/derby.jar:~/opt/mysql/mysql-connector-java-3.1.14-bin.jar:~/opt/hsqldb/lib/hsqldb.jar jruby ../jruby/bin/rake

== Authors

This project was written by Nick Sieger <nick@nicksieger.com> and Ola Bini <ola@ologix.com> with lots of help from the JRuby community.

== License

ActiveRecord-JDBC is released under a BSD license.  See the LICENSE file included with the distribution for details.
