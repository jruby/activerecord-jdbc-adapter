# ActiveRecord JDBC Adapter

ActiveRecord-JDBC-Adapter (AR-JDBC) is a database adapter for Rails'
*ActiveRecord* component that can be used with [JRuby][0]. It allows use of
virtually any JDBC-compliant database with your JRuby on Rails application.

AR-JDBC **1.2.x** officially supports ActiveRecord **3.x** as well as **2.3**,
it's latest version is compatible and require JRuby **1.6.8+** (but as always we
recommend to use the latest and greatest of JRubies) thus Java **1.6** is needed.

**NOTE:** version **1.3.0** of AR-JDBC adapter is currently in the making which
strives to provide ActiveRecord 2.3, 3.x as well as 4.0 (master) compatibility.
Our master already contains a lot of fixes but since we diverged significantly
from the 1.2 line (we no longer back-port fixes) and still require to perform a
few refactorings we advise users to point their *Gemfiles* to our master or use
pre-release versions of our gem(s) e.g. **1.3.0.beta2**.

## Databases

ActiveRecord-JDBC-Adapter provides full or nearly full support for:
**MySQL**, **PostgreSQL**, **SQLite3**, **Oracle**, **Microsoft SQL Server**,
**DB2**, **FireBird**, **Derby**, **HSQLDB**, **H2**, and **Informix**.

Other databases will require testing and likely a custom configuration module.
Please join the JRuby [mailing list][1] to help us discover support for more
databases.

## Using ActiveRecord JDBC

### Inside Rails

To use `activerecord-jdbc-adapter` with JRuby on Rails:

1. Choose the adapter you wish to gem install. The following pre-packaged
adapters are available:

  - Base JDBC (`activerecord-jdbc-adapter`) — Supports all available databases via
    JDBC, but requires you to download and manually setup the database vendor's
    JDBC driver .jar file.
  - MySQL (`activerecord-jdbcmysql-adapter`)
  - PostgreSQL (`activerecord-jdbcpostgresql-adapter`)
  - SQLite3 (`activerecord-jdbcsqlite3-adapter`)
  - Derby (`activerecord-jdbcderby-adapter`)
  - HSQLDB (`activerecord-jdbchsqldb-adapter`)
  - H2 (`activerecord-jdbch2-adapter`)
  - MSSQL (`activerecord-jdbcmssql-adapter`) — Does not support SQL Azure by default,
    see the [README][2] for more information.

2a. For Rails 3, if you're generating a new application, use the
following command to generate your application:

    jruby -S rails new sweetapp

2b. Otherwise, you might need to perform some extra configuration steps
to prepare your Rails application for JDBC.

If you're using Rails 3, you'll need to modify your *Gemfile* to use the
*activerecord-jdbc-adapter* gem under JRuby. Change your *Gemfile* to look
like the following (using MySQL as an example):

```ruby
gem 'mysql', platform: :ruby

platforms :jruby do
  gem 'jruby-openssl'
  gem 'activerecord-jdbcmysql-adapter'
end
```

If you're using Rails 2.3:

    jruby script/generate jdbc

3. Configure your *database.yml* in the normal Rails style:

```yml
development:
  adapter: mysql
  username: blog
  password: 1234
  host: localhost
  database: blog_development
```

**Legacy Configuration:** If you use one of the *activerecord-jdbcXXX-adapter* gems,
you can still put a 'jdbc' prefix in front of the database adapter name, e.g. `adapter: jdbcmysql`.

For plain JDBC database configurations, you'll need to know the database driver
class and URL (do not forget to put the driver jar on the class-path) e.g.:

```yml
development:
  adapter: jdbc
  username: blog
  password:
  driver: com.mysql.jdbc.Driver
  url: jdbc:mysql://localhost:3306/blog_development
```

For JNDI data sources, you may simply specify the JNDI location as follows (the
correct adapter type will be automatically detected):

```yml
production:
  adapter: jdbc
  jndi: jdbc/PostgreDB
```

JDBC driver specific properties might be set if you use an URL to specify the DB
or using the *properties:* syntax (available since AR-JDBC **1.2.6**):

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

If your SGBD isn't automatically discovered you can force a dialect as well:

```yml
development:
  [...]
  dialect: as400 # For example
```

More information on (configuring) AR-JDBC might be found on our [wiki][5].

### Standalone with ActiveRecord

Once the setup is made (see below) you can establish a JDBC connection like this (e.g. for `activerecord-jdbcderby-adapter`):

```ruby
ActiveRecord::Base.establish_connection(
  adapter: 'derby',
  database: 'db/my-database'
)
```

or using (requires that you manually put the driver jar on the classpath):

```ruby
ActiveRecord::Base.establish_connection(
  :adapter => 'jdbc',
  :driver => 'org.apache.derby.jdbc.EmbeddedDriver',
  :url => 'jdbc:derby:sample_db;create=true'
)
```

#### Using *Bundler*

Proceed as with Rails; in your *Gemfile* include `gem 'activerecord'` along the chosen adapers this time.

Your program should has:

```ruby
require 'bundler/setup'
require 'active_record'
```

#### Not using *Bundler*

Install the needed gems with JRuby:

    jruby -S gem install activerecord activerecord-jdbc-adapter

If you wish to use the adapter for a specific database, you can install it
directly and the driver gem (dependency) will be installed as well:

    jruby -S gem install activerecord-jdbcderby-adapter

Your program should include:

```ruby
require 'active_record'
require 'arjdbc'
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

This project was written by Nick Sieger <nick@nicksieger.com> and Ola Bini
<olabini@gmail.com> with lots of help from the JRuby community.

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
