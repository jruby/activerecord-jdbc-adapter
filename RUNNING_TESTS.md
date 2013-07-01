
## Running AR-JDBC's Tests

Most DB specific unit tests hide under the **test/db** directory, the files
included in the *test* directory are mostly shared test modules and helpers.

Rake tasks are loaded from **rakelib/02-test-rake**, most adapters have a
corresponding test_[adapter] task e.g. `rake test_sqlite3` that run against DB.
To check all available (test related) tasks simply `rake -T | grep test`.

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

Tests are by default run against the "current" ActiveRecord version locked down
by Bundler, however since we usually do support more versions from a single code
base run those with the (appraisal) provided task e.g. for MySQL :

    rake appraisal:rails31 test_mysql TEST=test/db/mysql/rake_test.rb

Observe the **TEST** variable used to specify a single file to be used to resolve
test cases, you pick tests by matching their names as well using **TESTOPTS** :

    rake appraisal:rails40 test_postgres TESTOPTS="--name=/integer/"

This of course also works when running the "plain" test (no appraisal:xxx) task.

Since 1.3.0 we also support prepared statements, these are off by default (AR)
but one can easily run tests with prepared statements enabled using env vars :

    rake test_derby PS=true # or PREPARED_STATEMENTS=true


### ActiveRecord (Rails) Tests

It's very desirable to pass all unit tests from ActiveRecord's own test suite.
Unfortunately it's been a while since we have accomplished that, luckily a lot
of failures are artificial (and would require tweaks at the Rails repo itself),
others simply need quality time spent to get them in shape and address issues.

First make sure you have the ActiveRecord (Rails) sources cloned locally :

    git clone git://github.com/rails/rails.git

To run the AR-JDBC's sources agains AR tests, use the **rails:test** task, be
sure to specify a **DRIVER** and the **RAILS** sources path on the file system :

    jruby -S rake rails:test DRIVER=derby RAILS=path/to/rails_source_dir

There's even tasks for Rails built-in adapters e.g. `rake rails:test_mysql`

You will likely only be able to run the Rails suite against the latest (stable)
ActiveRecord ~> version we support (check the *Gemfile.lock*) e.g. for
**activerecord (3.2.13)** you want to **git checkout 3-2-stable** branch.

We strive to not stub and include native (MRI) test required artefacts into
(non-test) code e.g. the `Mysql` module, instead put that into **test/rails**.

[![Build Status][0]](http://travis-ci.org/#!/jruby/activerecord-jdbc-adapter)

Happy Testing!

[0]: https://secure.travis-ci.org/jruby/activerecord-jdbc-adapter.png