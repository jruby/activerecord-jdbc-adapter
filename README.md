# ActiveRecord JDBC Adapter

[![Gem Version](https://badge.fury.io/rb/activerecord-jdbc-adapter.png)][7]

ActiveRecord-JDBC-Adapter (AR-JDBC) is a database adapter for Rails'
*ActiveRecord* component that can be used with [JRuby][0]. It allows use of
virtually any JDBC-compliant database with your JRuby on Rails application.

We supports *ActiveRecord* **2.3**, **3.x** and **4.x** from a single code base.
You'll need JRuby >= **1.6.8** (we recommend using the latest and greatest of
JRubies) thus Java >= **1.6** is mandatory.

#### AR-JDBC **1.3.x** is a recommended update for all **1.2.x** users.

Our latest major version **1.3.x** represents a few months of refactoring and
updates covering (not just) new/old *ActiveRecord* features. It tries to stay
compatible with 1.2.9 as much as possible but please be aware that it's not always
possible(mostly for the best), please read our [migration guide][8] for details.

## Databases

ActiveRecord-JDBC-Adapter provides full or nearly full support for:
**MySQL**, **PostgreSQL**, **SQLite3**, **Oracle**, *MS-SQL** (SQL Server),
**DB2**, **Firebird**, **Derby**, **HSQLDB**, **H2**, and **Informix**.

Other databases will require testing and likely a custom configuration module.
Please join the JRuby [mailing list][1] to help us discover support for more
databases.

## Using ActiveRecord JDBC

### Inside Rails

To use AR-JDBC with JRuby on Rails:

1. Choose the adapter you wish to gem install. The following pre-packaged
adapters are available:

  - Base JDBC (`activerecord-jdbc-adapter`) - supports all available databases
    via JDBC, but requires you to download and manually setup a JDBC driver for
    the database you're using
  - MySQL (`activerecord-jdbcmysql-adapter`)
  - PostgreSQL (`activerecord-jdbcpostgresql-adapter`)
  - SQLite3 (`activerecord-jdbcsqlite3-adapter`)
  - Derby (`activerecord-jdbcderby-adapter`)
  - HSQLDB (`activerecord-jdbchsqldb-adapter`)
  - H2 (`activerecord-jdbch2-adapter`)
  - MSSQL (`activerecord-jdbcmssql-adapter`) - uses the OSS jTDS driver by default
    which might have issues with the latest SQLServer (but should work using the
    Microsoft JDBC Driver for SQL Server - we recommend using 4.0)

2a. If you're generating a new Rails application, use the following command:

    jruby -S rails new sweetapp

2b. Otherwise, you might need to perform some extra configuration steps
to prepare your Rails application for JDBC.

You'll need to modify your *Gemfile* to use the *activerecord-jdbc-adapter* gem
(or one of the helper gems) under JRuby. Change your *Gemfile* to look something
like the following:

```ruby
gem 'mysql2', platform: :ruby
gem 'activerecord-jdbcmysql-adapter', platform: :jruby
```

If you're (stuck) using Rails 2.3, you might need to:

    jruby script/generate jdbc

3. Configure your *database.yml* in the normal Rails style:

```yml
development:
  adapter: mysql2 # or mysql
  database: blog_development
  username: blog
  password: 1234
```

**Legacy Configuration:** If you use one of the *activerecord-jdbcxxx-adapter*
gems, you can still put a 'jdbc' prefix in front of the database adapter name,
e.g. `adapter: jdbcmysql`.

For plain JDBC database configurations, you'll need to know the database driver
class and URL (do not forget to put the driver .jar(s) on the class-path) e.g.:

```yml
development:
  adapter: jdbc
  username: blog
  password: 1234
  driver: com.mysql.jdbc.Driver
  url: jdbc:mysql://localhost:3306/blog_development
```

For JNDI data sources, you may simply specify the JNDI location as follows, it's
recommended to use the same adapter: setting as one would configure when using
"bare" (JDBC) connections e.g. :

```yml
production:
  adapter: postgresql
  jndi: jdbc/PostgreDS
```

**NOTE:** any other settings such as *database:*, *username:*, *properties:* make
no difference since everything is already configured on the JNDI DataSource end.

JDBC driver specific properties might be set if you use an URL to specify the DB
or preferably using the *properties:* syntax:

```yml
production:
  adapter: mysql
  username: blog
  password: blog
  url: "jdbc:mysql://localhost:3306/blog?profileSQL=true"
  properties: # specific to com.mysql.jdbc.Driver
    socketTimeout:  60000
    connectTimeout: 60000
```

If you're really old school you might want to use AR-JDBC with a DB2 on z/OS:

```yml
development:
  adapter: jdbc
  url: jdbc:db2j:net://mightyzoshost:446/RAILS_DBT1
  driver: com.ibm.db2.jcc.DB2Driver
  schema: DB2XB12
  database: RAILS_DB1
  tablespace: TSDE911
  lob_tablespaces:
    first_table: TSDE912
  username: business
  password: machines
  encoding: unicode
  # you can force a (DB2) dialect using:
  #dialect: as400
```

More information on (configuring) AR-JDBC might be found on our [wiki][5].

### Standalone with ActiveRecord

Once the setup is made (see below) you can establish a JDBC connection like this
(e.g. for `activerecord-jdbcderby-adapter`):

```ruby
ActiveRecord::Base.establish_connection(
  adapter: 'derby',
  database: 'db/my-database'
)
```

or using (requires that you manually put the driver jar on the class-path):

```ruby
ActiveRecord::Base.establish_connection(
  :adapter => 'jdbc',
  :driver => 'org.apache.derby.jdbc.EmbeddedDriver',
  :url => 'jdbc:derby:sample_db;create=true'
)
```

#### Using Bundler

Proceed as with Rails; specify `ActiveRecord` in your Bundle along with the
chosen JDBC adapter(s), this time sample *Gemfile* for MySQL:

```ruby
gem 'activerecord', '~> 3.2.14'
gem 'activerecord-jdbcmysql-adapter', :platform => :jruby
```

When you `require 'bundler/setup'` everything will be set up for you as expected.

You do not need to use the 'helper' *activerecord-jdbcxxx-adapter* gem we provide
but than should make sure an appropriate JDBC driver is available at runtime, in
that case simply setup your *Gemfile* as:

```ruby
gem 'activerecord', '~> 4.0.0'
gem 'activerecord-jdbc-adapter', '~> 1.3.2', platform: :jruby
```

#### Without Bundler

Install the needed gems with JRuby, for example:

    gem install activerecord -v "~> 3.2.10"
    gem install activerecord-jdbc-adapter --ignore-dependencies

If you wish to use the adapter for a specific database, you can install it
directly and the (jdbc-) driver gem (dependency) will be installed as well:

    jruby -S gem install activerecord-jdbcderby-adapter

Your program should include:

```ruby
require 'active_record'
require 'activerecord-jdbc-adapter' if defined? JRUBY_VERSION
# or in case you're using the pre-packaged adapter gem :
require 'activerecord-jdbcderby-adapter' if defined? JRUBY_VERSION
```

## Extending AR-JDBC

You can create your own extension to AR-JDBC for a JDBC-based database that core
AR-JDBC does not support. We've created an example project for the Intersystems
Cache database that you can examine as a template.
See the [cachedb-adapter project][4] for more information.

## Source

The source for activerecord-jdbc-adapter is available using git:

    git clone git://github.com/jruby/activerecord-jdbc-adapter.git

Please note that the project manages multiple gems from a single repository,
if you're using *Bundler* >= 1.2 it should be able to locate all gemspecs from
the git repository. Sample *Gemfile* for running with (MySQL) master:

```ruby
gem 'activerecord-jdbc-adapter', :github => 'jruby/activerecord-jdbc-adapter'
gem 'activerecord-jdbcmysql-adapter', :github => 'jruby/activerecord-jdbc-adapter'
```

## Getting Involved

Please read our [CONTRIBUTING](CONTRIBUTING.md) & [RUNNING_TESTS](RUNNING_TESTS.md)
guides for starters. You can always help us by maintaining AR-JDBC's [wiki][5].

## Feedback

Please report bugs at our [issue tracker][3]. If you're not sure if
something's a bug, feel free to pre-report it on the [mailing lists][1] or
ask on the #JRuby IRC channel on http://freenode.net/ (try [web-chat][6]).

## Authors

This project was originally written by [Nick Sieger](http://github.com/nicksieger)
and [Ola Bini](http://github.com/olabini) with lots of help from the JRuby community.
Polished 3.x compatibility and 4.x support (for AR-JDBC >= 1.3.0) was managed by
[Karol Bucek](http://github.com/kares) among others.

## License

ActiveRecord-JDBC-Adapter is open-source released under the BSD/MIT license.
See [LICENSE.txt](LICENSE.txt) included with the distribution for details.

Open-source driver gems within AR-JDBC's sources are licensed under the same
license the database's drivers are licensed. See each driver gem's LICENSE.txt.

[0]: http://www.jruby.org/
[1]: http://jruby.org/community
[2]: http://github.com/jruby/activerecord-jdbc-adapter/blob/master/activerecord-jdbcmssql-adapter
[3]: https://github.com/jruby/activerecord-jdbc-adapter/issues
[4]: http://github.com/nicksieger/activerecord-cachedb-adapter
[5]: https://github.com/jruby/activerecord-jdbc-adapter/wiki
[6]: https://webchat.freenode.net/?channels=#jruby
[7]: http://badge.fury.io/rb/activerecord-jdbc-adapter
[8]: https://github.com/jruby/activerecord-jdbc-adapter/wiki/Migrating-from-1.2.x-to-1.3.0