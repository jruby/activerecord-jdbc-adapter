# ActiveRecord JDBC Adapter

Activerecord-jdbc-adapter is a database adapter for Rails' *ActiveRecord*
component that can be used with [JRuby][0]. It allows use of virtually any 
JDBC-compliant database with your JRuby on Rails application.

## Databases

Activerecord-jdbc-adapter provides full or nearly full support for:
**MySQL**, **PostgreSQL**, **SQLite3**, **Oracle**, **Microsoft SQL Server**, 
**DB2**, **FireBird**, **Derby**, **HSQLDB**, **H2**, and **Informix**.

Other databases will require testing and likely a custom configuration module.
Please join the JRuby [mailing list][1] to help us discover support for more databases.

## Using ActiveRecord JDBC

### Inside Rails

To use `activerecord-jdbc-adapter` with JRuby on Rails :

1. Choose the adapter you wish to gem install. The following pre-packaged
adapters are available :

  - Base JDBC (`activerecord-jdbc-adapter`) - supports all available databases via
    JDBC, but requires you to download and manually setup the database vendor's
    JDBC driver .jar file.
  - MySQL (`activerecord-jdbcmysql-adapter`)
  - PostgreSQL (`activerecord-jdbcpostgresql-adapter`)
  - SQLite3 (`activerecord-jdbcsqlite3-adapter`)
  - Derby (`activerecord-jdbcderby-adapter`)
  - HSQLDB (`activerecord-jdbchsqldb-adapter`)
  - H2 (`activerecord-jdbch2-adapter`)
  - MSSQL (`activerecord-jdbcmssql-adapter`) - does not support SQL Azure by default,
    see the [README][2] for more information.

2a. For Rails 3, if you're generating a new application, use the
following command to generate your application:

    jruby -S rails new sweetapp

2b. Otherwise, you might need to perform some extra configuration steps
to prepare your Rails application for JDBC.
  
If you're using Rails 3, you'll need to modify your *Gemfile* to use the
*activerecord-jdbc-adapter* gem under JRuby. Change your *Gemfile* to look
like the following (using sqlite3 as an example) :

```ruby
gem 'sqlite3', :platform => :ruby

platforms :jruby do
  gem 'jruby-openssl'
  gem 'activerecord-jdbcsqlite3-adapter'
end
```

If you're using Rails 2:

    jruby script/generate jdbc

3. Configure your *database.yml* in the normal Rails style.
  
Legacy configuration: If you use one of the convenience
*activerecord-jdbcXXX-adapter* adapters, you can still put a 'jdbc'
prefix in front of the database adapter name e.g. :

```yml
development:
  adapter: jdbcmysql
  username: blog
  password:
  host: localhost
  database: weblog_development
```

For plain JDBC database configurations, you'll need to know the database driver 
class and URL (do not forget to put the driver jar on the class-path) e.g. :

```yml
development:
  adapter: jdbc
  username: blog
  password:
  driver: com.mysql.jdbc.Driver
  url: jdbc:mysql://localhost:3306/weblog_development
```

For JNDI data sources, you may simply specify the JNDI location as follows (the 
correct adapter type will be automatically detected) :

```yml
production:
  adapter: jdbc
  jndi: jdbc/mysqldb
```

If you're really old school you might want to use AR-JDBC with a DB2 on z/OS :

```yml
development:
  adapter: jdbc
  encoding: unicode
  url: jdbc:db2j:net://mightyzoshost:446/RAILS_DBT1
  driver: com.ibm.db2.jcc.DB2Driver
  schema: DB2XB12
  database: RAILS_DB1
  tablespace: TSDE911
  lob_tablespaces:
    first_table: TSDE912
  username: scott
  password: lion
```

### Standalone (with ActiveRecord)

1. Install the gem with JRuby:

    jruby -S gem install activerecord-jdbc-adapter

If you wish to use the adapter for a specific database, you can install it 
directly and the driver gem (dependency) will be installed as well :

    jruby -S gem install activerecord-jdbcderby-adapter

2. After this you can establish a JDBC connection like this :

```ruby
ActiveRecord::Base.establish_connection(
  :adapter => 'jdbcderby',
  :database => "db/my-database"
)
```

or like (but requires that you manually put the driver jar on the classpath) :

```ruby
ActiveRecord::Base.establish_connection(
  :adapter => 'jdbc',
  :driver => 'org.apache.derby.jdbc.EmbeddedDriver',
  :url => 'jdbc:derby:test_ar;create=true'
)
```

## Source

The source for activerecord-jdbc-adapter is available using git :

    git clone git://github.com/jruby/activerecord-jdbc-adapter.git

Please note that the project manages multiple gems from a single repository,
if you're using *Bundler* 1.2 it should be able to locate all gemspecs from
the git repository. Sample *Gemfile* for running with (MySQL) master :

```ruby
gem 'activerecord-jdbc-adapter', :github => 'jruby/activerecord-jdbc-adapter'
gem 'activerecord-jdbcmysql-adapter', :github => 'jruby/activerecord-jdbc-adapter'
gem 'jdbc-mysql', :github => 'jruby/activerecord-jdbc-adapter'
```

## Feedback

Please report bugs at our [issue tracker][3]. If you're not sure if 
something's a bug, feel free to pre-report it on the [mailing lists][1] or
ask on the #JRuby IRC channel on http://freenode.net/.

## Running AR-JDBC Tests

[![Build Status][9]](http://travis-ci.org/#!/jruby/activerecord-jdbc-adapter)

Drivers for 6 open-source databases are included. Provided you have
MySQL installed, you can simply type `jruby -S rake` to run the tests.
A database named *weblog_development* is needed beforehand with a
connection user of "blog" and an empty password. You alse need to grant
"blog" create privileges on 'test_rake_db_create.*'.

If you also have PostgreSQL available, those tests will be run if the
`psql` executable can be found. Also ensure you have a database named
*weblog_development* and a user named "blog" with an empty password.
You can control the host and port the tests will attempt to by setting
the environment variables `PGHOST` and `PGPORT`.

If you want Rails logging enabled during these test runs you can edit 
*test/jdbc_common.rb* and add the line `require 'db/logger'`.

To execute a single test case, you can run:

    rake appraisal:{version} test_{db} TEST=test/{tests_file}

Substitute the *version* of ActiveRecord for version, which can be one of :
  *rails23*, *rails30*, *rails31*, or *rails32*.

The db can be one of these : *sqlite3*, *mysql*, *postgres*, 
  *mssql*, *sybase*, *oracle*, *db2*, *derby*, *h2* or *hssql*.

Finally, the *tests_file* will be whichever test case you want to run.

### Running AR Tests

To run the current AR-JDBC sources with `ActiveRecord`, just use the included 
`rails:test` task. Be sure to specify a driver and a path to the AR's sources :

    jruby -S rake rails:test DRIVER=mysql RAILS=/path/activerecord_source_dir

## Extending AR-JDBC

You can create your own extension to AR-JDBC for a JDBC-based database
that core AR-JDBC does not support. We've created an example project
for the Intersystems Cache database that you can examine as a template. 
See the [cachedb-adapter project][4] for more information.

## Authors

This project was written by Nick Sieger <nick@nicksieger.com> and Ola Bini
<olabini@gmail.com> with lots of help from the JRuby community.

## License

activerecord-jdbc-adapter is released under a BSD license. 
See the LICENSE.txt file included with the distribution for details.

Open-source driver gems for activerecord-jdbc-adapter are licensed under the
same license the database's drivers are licensed. See each driver gem's
LICENSE.txt file for details.

[0]: http://www.jruby.org/
[1]: http://jruby.org/community
[2]: http://github.com/jruby/activerecord-jdbc-adapter/blob/master/activerecord-jdbcmssql-adapter
[3]: https://github.com/jruby/activerecord-jdbc-adapter/issues
[4]: http://github.com/nicksieger/activerecord-cachedb-adapter
[9]: https://secure.travis-ci.org/jruby/activerecord-jdbc-adapter.png