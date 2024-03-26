There are two sets of tests which we run in CI.  Local (AR-JDBC) test and
Rails activerecord tests.  The next two sections details how to run each
and customize behavior.


## Running AR-JDBC's Tests

After you have built arjdbc (run rake), then you can try testing it (if you
do not build then adapter_java.jar is not put into the lib dir).  If you
change any of the .java files you will need to rebuild.

Most DB specific unit tests hide under the **test/db** directory, the files
included in the *test* directory are mostly shared test modules and helpers.

Rake tasks are loaded from **rakelib/02-test-rake**, most adapters have a
corresponding test_[adapter] task e.g. `rake test_sqlite3` that run against DB.
To check all available (test related) tasks simply `rake -T | grep test`.

### Database Setup

If the adapter supports creating a database it will try to do so automatically
(most embed databases such as SQLite3) for some adapters (MySQL, PostgreSQL) we
do this auto-magically (see the `rake db:create` tasks), but otherwise you'll
need to setup a database dedicated for tests (using the standard tools that come
with your DB installation).

Connection parameters: database, host etc. can usually be changed from the shell
`env` for adapters where there might be no direct control over the DB
instance/configuration, e.g. for Oracle (by looking at **test/db/oracle.rb**)
one might adapt the test database configuration using :
```
export ORACLE_HOST=192.168.1.2
export ORACLE_USER=SAMPLE
export ORACLE_PASS=sample
export ORACLE_SID=MAIN
```

Tests are run by calling the rake task corresponding the database adapter being
tested, e.g. for MySQL :

    rake test_mysql TEST=test/db/mysql/rake_test.rb

Observe the **TEST** variable used to specify a single file to be used to resolve
test cases, you pick tests by matching their names as well using **TESTOPTS** :

    rake test_postgres TESTOPTS="--name=/integer/"

Since 1.3.0 we also support prepared statements, these are enabled by default (AR)
but one can easily run tests with prepared statements disabled using env vars :

    rake test_derby PREPARED_STATEMENTS=false

#### MySQL with Docker

The standard Docker MySQL image can be used for testing and development. Depending on your environment these commands
may need to be run as root.

Pull the image:

```
sudo docker pull mysql
```

Start up the database with a root password (we show a simple one here but pick one no one else knows):

```
docker run -p 3306:3306 --name mysql -e MYSQL_ROOT_PASSWORD=testtest9 -d mysql
```

The `mysql` client can be run through Docker as well:

```sh
docker run -it --link mysql:mysql --rm mysql sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p"$MYSQL_ENV_MYSQL_ROOT_PASSWORD"'
```

Set up the database for the unit tests (you may need to replace 'localhost' with your container's IP):

```sql
CREATE USER 'rails'@'localhost' IDENTIFIED BY 'testtest9';
CREATE DATABASE activerecord_unittest;
GRANT ALL PRIVILEGES ON activerecord_unittest.* TO 'rails'@'localhost';
CREATE DATABASE activerecord_unittest2;
GRANT ALL PRIVILEGES ON activerecord_unittest2.* TO 'rails'@'localhost';
```

Then edit test/rails/config.yml for the appropriate configuration credentials.

### ActiveRecord (Rails) Tests

We also can run our adapters against Rails ActiveRecord tests.  There are two
ways you can do this:

 - Run against local clone (by setting RAILS environment variable). This is helpful when you are adding puts or hacking on activerecord code directly.

 - Run against bundler provided clone (by setting AR_VERSION environment variable). This is useful when you want to submit to travis and want all the adapters to run against your code.

Note: RAILS will trump AR_VERSION and setting neither will assume version as
set in the gemspec.

### Run against local clone

Make sure you have rails cloned somewhere:

```text
git clone git://github.com/rails/rails.git
```

Set up a fully qualified RAILS environment variable. For example, if you were
in activerecord direction you can just do something like:

```ext
export RAILS=`pwd`/../rails
```

Now that is this set up we may have changed the gems we need so we have
to run bundler:

```text
bundle install
```

Before you run tests you need to be aware that each support branch we have is
written to run with a single significant release of rails (50-stable will only
work well with rails 5.0.x).  So you need to make sure you local copy of rails
is checked out to match whatever you are testing (e.g. git checkout v5.0.6).
Now you can run rails tests:

```text
jruby -S rake rails:test_sqlite3
jruby -S rake rails:test_postgres
jruby -S rake rails:test_mysql
```

### Run against bundler provided clone

AR_VERSION is a very flexible variable.  You can:

 - specify tag (export AR_VERSION=v5.0.6)
 - specify version (export AR_VERSION=5.0.6)
 - specify SHA hash (export AR_VERSION=875bb788f56311ac4628402667187f755c1a331c)
 - specify branch (export AR_VERSION=verify-release)
 - specify nothing to assume LOADPATH has loaded it (export AR_VERSION=false)

Now that is this set up we may have changed the gems we need so we have
to run bundler:

```text
bundle install
```

Once you have picked what you want to test you can run:

```text
jruby -S rake rails:test_sqlite3
jruby -S rake rails:test_postgres
jruby -S rake rails:test_mysql
```

[![Build Status][0]](http://travis-ci.org/#!/jruby/activerecord-jdbc-adapter)

Happy Testing!

[0]: https://secure.travis-ci.org/jruby/activerecord-jdbc-adapter.png
