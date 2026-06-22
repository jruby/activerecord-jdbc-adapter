# activerecord-jdbcpostgresql-adapter

* https://github.com/jruby/activerecord-jdbc-adapter/

## Description

This is an ActiveRecord driver for PostgreSQL using JDBC running under JRuby.

It is part of the [activerecord-jdbc-adapter](https://github.com/jruby/activerecord-jdbc-adapter)
project; see the top-level README for general installation and configuration.

## Connection and resilience options

In addition to the standard ActiveRecord PostgreSQL settings, the adapter
recognizes the following `database.yml` keys. Each is translated to the
corresponding [pgjdbc connection parameter](https://jdbc.postgresql.org/documentation/use/#connection-parameters).
Setting timeouts and TCP keep-alive is strongly recommended when running behind a
connection pooler or a firewall that drops idle connections, so a dead/reaped
backend surfaces as an error instead of hanging the JVM thread.

| `database.yml` key | pgjdbc property | Meaning | Default |
| --- | --- | --- | --- |
| `connect_timeout` | `connectTimeout` | Timeout (seconds) for establishing a new connection. Also read from `PGCONNECT_TIMEOUT`. | pgjdbc default (10s) |
| `socket_timeout` | `socketTimeout` | Per-query read timeout (seconds) on an established connection. `0` = infinite. | unset (infinite) |
| `login_timeout` | `loginTimeout` | Timeout (seconds) for the connection + authentication handshake. | unset |
| `prepare_threshold` | `prepareThreshold` | How many executions before a query is promoted to a *named* server-side prepared statement. `0` keeps statements unnamed. Overrides the value derived from `prepared_statements`. | derived from `prepared_statements` |
| `keepalives` | `tcpKeepAlive` | Enable TCP keep-alive probes. | unset (off) |

You can also pass any pgjdbc property directly under `properties:` (e.g.
`tcpKeepAlive: true`). Example:

```yml
production:
  adapter: postgresql
  database: blog
  username: blog
  password: blog
  connect_timeout: 5      # cap connection establishment (pgjdbc connectTimeout)
  socket_timeout: 30      # cap per-query reads (pgjdbc socketTimeout)
  properties:
    tcpKeepAlive: true    # detect dead backends instead of hanging
```

> **Behavior change:** prior to this release `connect_timeout` was mapped to
> pgjdbc's `socketTimeout` (a per-query read timeout). It now maps to
> `connectTimeout`, matching the pg gem / libpq meaning of `connect_timeout`. If
> you relied on the old behavior to bound query execution time, set
> `socket_timeout` instead.

## Running behind PgBouncer (or another connection pooler)

The PostgreSQL adapter works out of the box with PgBouncer in **`session`**
pooling mode — every checkout keeps one backend, so per-session state is stable
and no special configuration is required.

In **`transaction`** or **`statement`** pooling mode PgBouncer reassigns the
server backend between transactions, which breaks anything that relies on
per-session server state. See the next section before using those modes.

| Concern | `session` mode | `transaction` / `statement` mode |
| --- | --- | --- |
| Prepared statements | works as-is | `prepared_statements: false` (or PgBouncer >= 1.21, see below) |
| Advisory locks (migrations) | works as-is | `advisory_locks: false` |
| Session `SET`s (timezone, search_path, intervalstyle) | applied at connect | must be enforced per backend (see below) |

## PgBouncer transaction (and statement) pooling mode

Use this configuration as a starting point:

```yml
production:
  adapter: postgresql
  host: 127.0.0.1
  port: 6432                   # PgBouncer listening port
  database: blog
  username: blog
  password: blog
  prepared_statements: false   # required: named server statements can't span backends
  advisory_locks: false        # required: session-scoped locks can't span backends
  connect_timeout: 5
  socket_timeout: 30
  properties:
    tcpKeepAlive: true
```

**Prepared statements.** With `prepared_statements: true` (the default) the
pgjdbc driver promotes a query to a *named* server-side prepared statement after
it has executed `prepareThreshold` (5 by default) times. That named statement
lives on one backend, so once PgBouncer hands the next transaction a different
backend you get `ERROR: prepared statement "S_1" does not exist`. Two options:

* Set `prepared_statements: false` — this forces pgjdbc `prepareThreshold=0`, so
  only unnamed statements are used, which are safe across backends.
* Or run PgBouncer >= 1.21 with `max_prepared_statements > 0` and keep prepared
  statements on. Tune the promotion point with `prepare_threshold:` if needed.

**Advisory locks.** Schema migrations take a session-level advisory lock that is
acquired and released across transaction boundaries. Under transaction/statement
pooling the unlock may land on a different backend and orphan the lock, so set
`advisory_locks: false`.

**Session `SET` statements.** On connect the adapter issues `SET TIME ZONE`,
`SET intervalstyle = iso_8601`, applies `schema_search_path`, etc. These do
**not** follow backend reassignment, which can *silently* corrupt results
(interval parsing, timestamps, querying the wrong schema). Because PgBouncer in
transaction/statement mode disallows per-session state, enforce these per backend
instead — for example:

* `ALTER ROLE blog SET intervalstyle = 'iso_8601';`
* `ALTER ROLE blog SET timezone = 'UTC';` (when using ActiveRecord UTC time zone support)
* set `search_path` via `ALTER ROLE`/`ALTER DATABASE` or PgBouncer's server-side
  connect options instead of `schema_search_path:`

If you cannot enforce that state globally, use `session` pooling for that database.
