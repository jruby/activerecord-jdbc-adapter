# ActiveRecord JDBC Adapter

[![Gem Version](https://badge.fury.io/rb/activerecord-jdbc-adapter.svg)][7]

ActiveRecord-JDBC-Adapter (AR-JDBC) is a database adapter for Rails'
*ActiveRecord* component that can be used with [JRuby][0]. It allows use of
virtually any JDBC-compliant database with your JRuby on Rails application.

We do support *ActiveRecord* **3.x** and **4.x** (also **2.3** is still expected
to work) from a single code base. AR-JDBC needs JRuby 1.7.x or 9K (we recommend
using the latest and greatest of versions) thus Java >= **1.6** is mandatory.


**This README and master targets AR-JDBC 1.4.0 (pre-release) please use the
[1-3-stable](https://github.com/jruby/activerecord-jdbc-adapter/tree/1-3-stable)
branch for current stable 1.3.x releases.**

The next release 1.4 aims to concentrate on internal refactoring and optimization.
We're going to be (slowly) dropping support for all of Rails < 3.2, unless there
is demand for these. In which case we kindly hope to receive PRs.

## Databases

ActiveRecord-JDBC-Adapter provides (built-in) full or nearly full support for:
**MySQL** (and **MariaDB**), **PostgreSQL**, **SQLite3**, **Oracle**, **DB2**,
*MS-SQL** (SQL Server), **Firebird**, **Derby**, **HSQLDB**, **H2**, and **Informix**.

Even if you're database product is not listed, there are 3rd party gems built on
top of AR-JDBC to handle different data-sources, [search][8] at the usual places.

## Using ActiveRecord JDBC

### Inside Rails

To use AR-JDBC with JRuby on Rails:

1. Choose the adapter (base is usually fine), the following are pre-packaged :

  - Base JDBC (`activerecord-jdbc-adapter`) - supports all available databases
    via JDBC (Java's unified DB interface), but requires you to setup a JDBC
    driver (which with most open-source drivers means adding another gem to your
    *Gemfile* e.g. `gem 'jdbc-mysql'` just like on MRI), for drivers not packed
    as gems just add the required jars to the class-path
  - MySQL (`activerecord-jdbcmysql-adapter`)
  - PostgreSQL (`activerecord-jdbcpostgresql-adapter`)
  - SQLite3 (`activerecord-jdbcsqlite3-adapter`)
  - Derby (`activerecord-jdbcderby-adapter`)
  - HSQLDB (`activerecord-jdbchsqldb-adapter`)
  - H2 (`activerecord-jdbch2-adapter`)
  - MSSQL (`activerecord-jdbcmssql-adapter`) - uses the OSS jTDS driver which
    might have issues with the latest SQLServer (but should work using the
    Microsoft JDBC Driver for SQL Server - we recommend using version 4.0)
    **NOTE:** [jTDS](http://jtds.sourceforge.net/) seems no longer maintained,
    if you're run into issues consider using the official (proprietary) driver.

2a. If you're generating a new Rails application, run the usual :

    jruby -S rails new sweetapp

2b. Otherwise, you might need to perform some extra configuration steps
to prepare your Rails application for JDBC.

You'll need to modify your *Gemfile* to use the *activerecord-jdbc-adapter* gem
(or one of the helper gems) under JRuby. Change your *Gemfile* to look something
like the following :

```ruby
gem 'mysql2', platform: :ruby
gem 'jdbc-mysql', platform: :jruby
gem 'activerecord-jdbc-adapter', platform: :jruby
```

3. Configure your *database.yml* in the normal Rails style :

```yml
development:
  adapter: mysql2 # or mysql
  database: blog_development
  username: blog
  password: 1234
```

**Legacy Configuration:** If you use one of the *activerecord-jdbcxxx-adapter*
gems, you can still put a 'jdbc' prefix in front of the database adapter name,
e.g. `adapter: jdbcmysql` but it's no longer recommended on Rails >= 3.0

For plain JDBC database configurations, you'll need to know the database driver
class and URL (do not forget to put the driver .jar(s) on the class-path) e.g. :

```yml
development:
  adapter: jdbc
  driver: org.apache.hadoop.hive.jdbc.HiveDriver
  url: jdbc:hive://localhost:10004/default
```

**NOTE:** please do not confuse the `:url` setting with the one introduced in
ActiveRecord 4.1, we've been using it for a long time with AR-JDBC and for now
should work just fine the "jdbc:xxx" way (passed to the driver directly) ...

For JNDI data sources, you may simply specify the JNDI location as follows, it's
recommended to use the same adapter: setting as one would configure when using
"bare" (JDBC) connections e.g. :

```yml
production:
  adapter: postgresql
  jndi: jdbc/PostgreDS
  # be aware that by default AR defaults to pool: 5
  # there are (unofficial) ways of avoiding AR's pooling
  # one such would be: ActiveRecord::Bogacs::FalsePool
```

**NOTE:** any other settings such as *database:*, *username:*, *properties:* make
no difference since everything is already configured on the data source end.

Most data-sources will provide you with connection pooling, but ActiveRecord uses
an internal pool (with a default size of 5) as well, thus you need to be careful
to configure both pools wisely to handle your requirements. If you'd like to
"disable" AR's built-in pool try : https://github.com/kares/activerecord-bogacs

JDBC driver specific properties might be set if you use an URL to specify the DB
or preferably using the *properties:* syntax :

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

If you're really old school you might want to use AR-JDBC with a DB2 on z/OS :

```yml
development:
  adapter: db2
  url: jdbc:db2j:net://mightyzoshost:446/RAILS_DBT1
  schema: DB2XB12
  database: RAILS_DB1
  tablespace: TSDE911
  lob_tablespaces:
    first_table: TSDE912
  username: business
  password: machines
  # default driver used is :
  #driver: com.ibm.db2.jcc.DB2Driver
  # NOTE: AS400 support is deprecated since 1.4 in favor
  # of the standalone activerecord-jdbcas400-adapter gem
```

More information on (configuring) AR-JDBC might be found on our [wiki][5].

### Standalone with ActiveRecord

Once the setup is made (see below) you can establish a JDBC connection like this
(e.g. for `activerecord-jdbcderby-adapter`):

```ruby
ActiveRecord::Base.establish_connection adapter: 'derby', database: 'db/my-db'
```

#### Using Bundler

Proceed as with Rails; specify `gem 'activerecord'` in your Bundle along with the
chosen JDBC adapter (or driver), sample *Gemfile* for MySQL :

```ruby
gem 'activerecord', '~> 3.2.18'
gem 'activerecord-jdbcmysql-adapter' # or :
# gem 'mysql2', :platform => :mri # C-driver
# gem 'activerecord-jdbc-adapter', :platform => :jruby
# gem 'jdbc-mysql', :platform => :jruby # J-driver
```

When you `require 'bundler/setup'` everything will be set up for you as expected.

You do not need to use the 'helper' *activerecord-jdbcxxx-adapter* gem we provide
but than should make sure an appropriate JDBC driver is available at runtime, in
that case simply setup your *Gemfile* as:

```ruby
gem 'activerecord', '~> 4.1.6'
gem 'activerecord-jdbc-adapter', '~> 1.3', platform: :jruby
# e.g. for PostgreSQL you'll probably add :
# gem 'pg', platform: :mri
# gem 'jdbc-postgres', platform: :jruby
```

#### Without Bundler

Install the needed gems with JRuby, for example:

    gem install activerecord -v "~> 3.2"
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

**You will need to have JDK 7+ to compile the native JRuby extension part.**

**NOTE:** Currently, one also needs to make sure to install all of the gem's
[development dependencies][10] to make sure the compilation `javac` task does
found it's dependent (Java) classes.

Please note that the project manages multiple gems from a single repository,
if you're using *Bundler* >= 1.2 it should be able to locate all gemspecs from
the git repository. Sample *Gemfile* for running with (MySQL) master:

```ruby
gem 'activerecord-jdbc-adapter', :github => 'jruby/activerecord-jdbc-adapter'
```

## Getting Involved

Please read our [CONTRIBUTING](CONTRIBUTING.md) & [RUNNING_TESTS](RUNNING_TESTS.md)
guides for starters. You can always help us by maintaining AR-JDBC's [wiki][5].

## Feedback

Please report bugs at our [issue tracker][3]. If you're not sure if something's
a bug, feel free to pre-report it on the [mailing lists][1] or ask on the #JRuby
IRC channel on http://freenode.net/ (try [web-chat][6]).

## Authors

This project was originally written by [Nick Sieger](http://github.com/nicksieger)
and [Ola Bini](http://github.com/olabini) with lots of help from the community.
Polished 3.x compatibility and 4.x support (since AR-JDBC >= 1.3.0) was managed by
[Karol Bucek](http://github.com/kares) among other fellow JRuby-ists.

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
[8]: http://rubygems.org/search?query=activerecord-jdbc
[9]: https://github.com/jruby/activerecord-jdbc-adapter/wiki/Migrating-from-1.3.x-to-1.4.0
[10]: https://github.com/jruby/activerecord-jdbc-adapter/blob/master/activerecord-jdbc-adapter.gemspec
