# eazyBI build of `adapter_java.jar` (activerecord-jdbc-adapter 72.1)

This branch (`eazybi-72.1`) is the upstream **`v72.1`** tag plus a few eazyBI-specific
patches to the Java sources. Its only purpose is to build `adapter_java.jar`, which eazyBI
ships in its own repository.

eazyBI does **not** use a forked gem. It depends on the stock
`activerecord-jdbc-adapter` gem from rubygems.org and overrides just two files from
`~/rails/eazybi/lib/`, which comes earlier on `$LOAD_PATH` than the gem:

    lib/arjdbc/jdbc/java.rb            # requires the MSSQL jar, then adapter_java.jar
    lib/arjdbc/jdbc/adapter_java.jar   # <- built from this branch

That is why `ArJdbc::VERSION` on this branch stays `72.1` — the jar and the gem's Ruby code
must be the same version.

## Patches applied on top of `v72.1`

| Commit | File | Change |
| --- | --- | --- |
| `221a5c43` | `src/java/arjdbc/mysql/MySQLRubyJdbcConnection.java` | Override `timestampToRuby`, copied verbatim from `RubyJdbcConnection` |
| `5201d005` | same | Catch the `HOUR_OF_DAY` `SQLException` and fall back to `stringToRuby`. Happens when the app/DB time zone is not UTC and the value read (e.g. `updated_at_utc`) does not exist in the server time zone (DST gap) |
| `7a7f8ba3` | `src/java/arjdbc/postgresql/PostgreSQLRubyJdbcConnection.java` | Read `TimeZone.getDefault()` on every `setDate` instead of caching it in the `TZ_DEFAULT` constant, because eazyBI changes the default time zone at runtime |

All three are authored by Jānis Justaments and were originally made against 61.3 in
https://github.com/eazybi/activerecord-jdbc-adapter/pull/1. They are marked in the source
with `// PATCH:` comments, and the replaced upstream lines are kept commented out right
above, so the next upgrade can see exactly what changed.

### Upgrading to a newer upstream version

Create a new `eazybi-<version>` branch off the upstream tag and cherry-pick the three
commits above — do not merge this branch:

    git fetch upstream --tags
    git checkout -b eazybi-73.0 v73.0
    git cherry-pick 221a5c43 5201d005 7a7f8ba3   # order matters, 2 builds on 1

Then check that `RubyJdbcConnection#timestampToRuby` upstream has not changed, since the
MySQL override is a copy of it:

    git diff v72.1 v73.0 -- src/java/arjdbc/jdbc/RubyJdbcConnection.java

## Setting up the environment

Tool versions are pinned in the committed [`mise.toml`](mise.toml) — JRuby 9.4.15.0 (the
same JRuby eazyBI runs) and Temurin JDK 11. `mise` replaces the `rvm` setup used for the
61.3 builds; no `.rvmrc` is needed.

1. Check out this repository and the branch

        cd ~/rubygems
        git clone git@github.com:eazybi/activerecord-jdbc-adapter.git
        cd activerecord-jdbc-adapter
        git checkout eazybi-72.1

2. Let mise install the pinned toolchain

        mise trust
        mise install
        mise current     # expect: ruby jruby-9.4.15.0 / java temurin-11...

3. Install the gems, pinning ActiveRecord to the 7.2 series (same value upstream CI uses)

        AR_VERSION=7-2-stable bundle

   `AR_VERSION` makes the `Gemfile` pull ActiveRecord from the `7-2-stable` branch of
   rails/rails instead of using the `.gemspec` requirement. Any 7.2-compatible value works
   (`7-2-stable`, `7.2.3.1`, ...); it only affects the test suite, not the jar.

## Building the JAR file

1. Run the `rake` task to build the `adapter_java.jar` file

        rake jar

   The JDBC drivers needed on the compile classpath (`org.postgresql.*` is imported
   directly by the Postgres connection class) are committed in this repository, at
   `jdbc-postgres/lib/postgresql-42.7.1.jar` and
   `jdbc-mysql/lib/mysql-connector-j-9.1.0.jar`, so there is nothing extra to download.
   Use `rake jar:force` to rebuild when the sources have not changed.

2. The result is at `lib/arjdbc/jdbc/adapter_java.jar` (git-ignored).

## Java compatibility

The `Rakefile` compiles with `-source 1.8 -target 1.8` (unchanged from upstream). Combined
with the JDK 11 pinned in `mise.toml`, the classes in the jar are **class file version 52**,
which every JVM from Java 11 through Java 25 loads. eazyBI itself currently runs on
Temurin 25.

If you bump the `java` pin in `mise.toml`, the jar is then compiled against that JDK's
platform classes while still emitting version 52 bytecode — it may link to methods that do
not exist on older JVMs. Keep the pin at JDK 11 unless you also switch the `Rakefile` to
`javac --release 11`.

## Verifying the built jar

    # 1. the MySQL override is present (it does not exist in stock 72.1)
    javap -p -classpath lib/arjdbc/jdbc/adapter_java.jar \
      arjdbc.mysql.MySQLRubyJdbcConnection | grep timestampToRuby

    # 2. the Postgres patch calls TimeZone.getDefault() at runtime
    javap -c -p -classpath lib/arjdbc/jdbc/adapter_java.jar \
      arjdbc.postgresql.PostgreSQLRubyJdbcConnection | grep -c 'TimeZone.getDefault'

    # 3. bytecode is Java 8/11-compatible -> expect "cafe babe 0000 0034"
    unzip -p lib/arjdbc/jdbc/adapter_java.jar \
      arjdbc/mysql/MySQLRubyJdbcConnection.class | head -c 8 | xxd

    # 4. it loads and queries under ActiveRecord 7.2 (repeat under Java 25 with
    #    `mise x java@temurin-25 -- env AR_VERSION=...`)
    AR_VERSION=7-2-stable bundle exec jruby -Ilib -e '
      require "active_record"; require "arjdbc"
      ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "postgres")
      p ActiveRecord::Base.connection.select_value("select now()")'

The adapter's own test suite can also be run against local databases, see
`rakelib/db.rake` and `rake -T test`.

### Confirming the patches still do something

Both patches were checked against 72.1 with a stock (unpatched) jar as a control, so the
observable difference is known:

- **MySQL / `HOUR_OF_DAY`**: store `2023-03-26 03:30:00` in a `datetime` column (a time that
  does not exist in `Europe/Riga`, clocks jump 03:00 -> 04:00) and read it back. Stock 72.1
  raises `ActiveRecord::JDBCError: HOUR_OF_DAY: 3 -> 4`; with the patch the value comes back
  as the raw String `"2023-03-26 03:30:00"` via the `stringToRuby` fallback, while ordinary
  timestamps still come back as `Time`.
- **Postgres / default time zone**: insert and read a `date` after calling
  `java.util.TimeZone.set_default(...)` post-connection. Stock 72.1 returns the date shifted
  by a day (`2023-03-25` for `2023-03-26`) because `TZ_DEFAULT` was captured at class load;
  with the patch it round-trips correctly under `UTC`, `Europe/Riga` and
  `America/Los_Angeles`.

If a future upstream version makes both of these pass unpatched, the corresponding patch can
be dropped.

## Installing the jar into eazyBI

**Do this only once eazyBI is actually on Rails 7.2 / arjdbc 72.1** — dropping a 72.1 jar
into a checkout that still uses the 61.3 gem will break it.

1. In `~/rails/eazybi`, the `Gemfile` must require the matching gem version

        gem 'activerecord-jdbc-adapter', '~> 72.1'

2. Copy the jar over

        cp lib/arjdbc/jdbc/adapter_java.jar ~/rails/eazybi/lib/arjdbc/jdbc/

3. The MySQL adapter is now registered as **`mysql2`**, not `mysql` (see
   `ActiveRecord::ConnectionAdapters.register` calls in [`lib/arjdbc.rb`](lib/arjdbc.rb)).
   eazyBI's `config/database.yml` still picks `"mysql"` under JRuby and has to use
   `mysql2` for both JRuby and MRI:

        adapter: <%= defined?(JRUBY_VERSION) ? "mysql" : "mysql2" %>   # 61.3
        adapter: mysql2                                               # 72.1

## Known issue: the separate MSSQL jar

eazyBI also ships `~/rails/eazybi/lib/arjdbc/jdbc/adapter_java_mssql.jar` alongside vendored
Ruby code in `~/rails/eazybi/lib/arjdbc/mssql/`. That jar contains `arjdbc.mssql.*` classes
built around 2021 from much older (arjdbc 52-era) sources, and `java.rb` requires it
*before* `adapter_java.jar`, so those old classes shadow the `arjdbc.mssql.*` classes that
are also inside the 72.1 jar.

Those old classes were compiled against a very different `RubyJdbcConnection`, so they may
not link correctly against the 72.1 one. This has to be resolved on the eazyBI side as part
of the Rails 7.2 migration — either rebuild the MSSQL jar, or drop it and adapt eazyBI's
vendored `lib/arjdbc/mssql/*.rb` to the `arjdbc.mssql` classes already contained in
`adapter_java.jar`. It is deliberately out of scope for this branch.
