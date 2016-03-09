## 1.3.20 (03/09/16)

- Retrieve AM::Type::Boolean::FALSE_VALUES for Rails 5 (#705)
- [mysql] only mock mysql / mysql2 error under adapter /mysql/
  and make sure db:create works (#702)
- use system instead of `` to run dumps (on < 4.0) as it has issues under 1.7.x
- avoid column.default type_cast-ing on AR 4.2 (#715)
- [postgres] data_sources support - backport on AR 4.2
- add support for data sources (backport on AR 4.2) in base (jdbc) adapter
- [derby] Enable DDL transaction on Derby (#714)
- [db2] support for DB2 big integer (BIGINT) data type
- [mysql] Fixed MySQL primary key for MySQL >= 5.7.3 (#695)
- [sqlite] on AR 4.2 is not supposed to have an implicit string limit: 255
- [postgres] on AR 4.2 is not supposed to have an implicit string limit: 255

## 1.3.19 (11/02/15)

- [sqlite] add supports_partial_index? and remove duplicate support_index_sort_order?
- [sqlite] fix missing save-point removal in release_savepoint
- test and fix current savepoint_name compatibility with AR versions (mostly 4.2)
  * adjust returned current savepoint name to better match with AR (< 4.2)
  * make sure savepoint rollback behave AR compatibly
- [mysql] revert to extracting BIT into an int as tinyint(1) (#687)
- [mysql] do not validate connection_alive_sql as there's a special /* ping */ query
- support timeouts on connection validation with `config[:connection_alive_timeout]`

## 1.3.18 (09/14/15)

- since arel visitor instances might get re-used we need to avoid the @instance
- [postgres] work-around BC time parsing issue (on JRuby 1.7.x) by a patch
- [mssql] fix broken ordering on an aggregate queries (from #646 closing #532)
- [mssql] default to using a string limit: 4000 with newer AR
- [mssql] setup type map for SQLServer ... backwards compat as much as possible
- for better AR alignment on 4.2 shall do the AR type-casting of booleans/dates
- [mssql] ... port over visitor from sqlserver-adapter (to be used on AR 4.2)
- [mssql] allow to tune collation equality operator with *cs_equality_operator*
- [mssql] setup BINARY/TEXT types as binary_basic/text_basic (needed on 4.2)
- [mssql] setup a NATIVE_DATABASE_TYPES constant (for SQLServer > 2K) (#508)
- [jdbc] prefer BIT(1) as a better match for :boolean type than TINYINT
- [mssql] get_table_name bug with unusual queries has been fixed (#583)
- [mssql] make sure we set @primary on column instances even on AR 4.2
- [mssql] issue when using joins with distinct (#590) ... fixed with #608
- [firebird] tune arel visitor (limit/offset handling) to work on AR 4.2
- [firebird] avoid prefetch_primary_key? depending on column.primary due AR 4.2
- [firebird] introduce type map on AR 4.2 (not sure about :timestamp handling
- [firebird] boolean parameter with prepared-statements should be set as CHAR
- [firebird] standalone column and adapter classes +
  standalone custom (native) JdbcConnection class for firebird due CHAR handling
- [firebird] handle schema-prefixed table names in default_sequence_name
- [oracle] support for handling NUMBER(1) type as boolean just like on AR < 4.2
- [oracle] generic optimized NUMBER type extraction (with scale == 0 as integer)
- [oracle] support XMLTYPE as a custom type on AR 4.2
- [oracle] add disable_referential_integrity helper (for the duration of a block)
- base (adapter: jdbc) foreign_keys support for all (for AR 4.2 compatibility)
- [oracle] AR 4.2 type map support (ported over from oracle-enhanced adapter)
- [oracle] avoid error logging optional DROP SEQUENCE on drop_table
- [oracle] default config[:database] (when not provided) to **XE**
- [oracle] improved index + primary_key (detection) support not just for AR 4.2
- [oracle] update default_sequence_name to strip prefix + add trigger name
- [oracle] set statement_escape_processing: true by default on AR 4.x (#479)
- handle serialized attributes the AR 4.2 way (serialized_attributes deprecated)
- [db2] custom type map for AR 4.2 based on IBM_DB gem
- [db2] support XML as type on AR 4.2
- type-casting on our native side should now handle AR 4.2 right!
- jdbc connection should not attempt to type-cast date/time on AR 4.2
- [db2] arel visitor + handle basic type mapping the AR 4.2 way
- no longer warn on 4.2 + but still warn with (unsupported) adapters
- restore Ruby 1.8 (syntax) compatibility - was broken for MySQL/Derby
- use standard AREL with H2/HSQLDB as H2/HSQLDB support standard LIMIT and OFFSET
- [h2] working AR 4.2 support
- [hsqldb] working AR 4.2 support
- [rake] support adapter: mariadb as if it were mysql (on AR 4.x)
- [postgres] changes to avoid double cast for AR42 (with prepared statements)
- [postgres] use standard JDBC bind arguments marker "?" instead of "$n"
- [postgres] allow reading "infinity" and "BC timestamps on 4.2
- type cast bind arguments in RubyJdbcConnection (prepared statements)
- [derby] ActiveRecord 4.2 reports xml columns as XML(2147483647)
- [derby] working AR 4.2 support
- support cast_type on the JdbcConnection side for improved AR 4.2 compatibility

## 1.3.17 (06/30/15)

- [mysql] bulk compatibility with AR 4.2 - all _sql helper accept an options (hash)
- [mysql] back-port case sensitive/insensitive comparison
- [mysql] handle precision for datetimes when doing type_to_sql (AR 4.2 compat)
- [mysql] foreign key support based on AR 4.2 (#656)
- [postgres] foreign_key support back-ported from AR 4.2 (#656)
- moved jndi callbacks to happen outside adapter's `initialize` (#649, #620)
- [postgres] AR 4.2 compatibility with SchemaCreation
- [postgres] re-define `lookup_cast_type` (AR 4.2) + `conn.type_map` is public
- [postgres] override `valid_type?(type)` (AR 4.2 compatibility)
- [postgres] back-port change_column updates from AR 4.2 for compatibility
- [postgres] pass down array_member to hstore_to_string (fixes #647 on AR 4.1)
- [postgres] on AR 4.2 use core's schema_definitions.rb for improved compat (#644)
- back-port PGconn hack on AR 4.x (from #655 and following commits)
  to fix #651 as an unfortunate work-around for (non-shareable) AR internals (#652)
- seems that extension methods won't work in 9K the same as in 1.7.x thus work-around
  (originally reported as https://github.com/jruby/jruby/issues/2533)
- restore 1.8 compatibility in postgres' adapter (regression in 1.3.16 see #641)

## 1.3.16 (04/13/15)

- [h2] allow jdbch2 adapter to use jdbc-h2 1.4 (#639)
- [postgres] quote and type_cast should not be overriden on 4.2
- [postgres] fix table column resolution (slightly align it to our needs) on 4.2
- [postgres] re-arrange Column internals as some helpers end-up on Adapter in 4.2
- [mysql] change_column table is redefined on AR 4.2 so that it uses _sql version
- [mysql] more tuning/compatibility backports for AR 4.2 (working booleans #626)
- [mysql] type-map support copy-pasta from AR 4.2 (closer to full compat) (#617)
- [postgres] improved support for Amazon Redshift (based on user feedback #403)
- fixed problem with create table statements with references in MySQL (#629)
- fix RecordNotUnique reference in ArJdbc::SQlite3 (#634)
- [postgres] add support for jsonb column type (#633 #635 #637)

## 1.3.15 (03/09/15)

- [informix] adapter undefined method 'column_types' with Rails 4.x (#622)
- improve connection factory Ruby interface impls to match Java method-name (#621)
- [sqlite] truncate_fake - as due compatibility with do not want a truncate method
- truncate support 4 all (introduced in AR 4.2 but we let it work in all versions)
- [postgres] do not double load array_parser (on 4.2)
- [postgres] connection.truncate impl (AR 4.2 compat)
- [mysql] back-port missing truncate connection method (since AR 4.2)
- auto setup type-casting compat (pre 4.2 emulation) 4 all
- [postgres] backport bigserial key and bigint native type support

## 1.3.14 (01/28/15)

- [mysql] Fixed an undefined exception error in type_to_sql for MySQL (#616)
- [derby] support for empty insert statements (e.g. `DbModel.create!`) on AR 4.x
- [db2] revert limit/offset OVER( ORDER BY ) matching as it was not complete (#606)
- [db2] handle empty INSERT statement (default) VALUES in a way that works on AR 4.x
- [db2] `select` return value should be the same as core AR (Array on 3.2) (#607)
- [mysql] backport bulk change & schema-creation to be compatible with AR 4.x
- handle possible null values while extracting from XML columns (#615)
- DateTime columns are returned always as nil values (on Rails 4.2 #613)
- [oracle] do not override primary= within column methods on AR 4.2
- handle removed AR `Column#primary=` method on 4.2 (#609)
- [oracle] fix missing sequence_name_length method when doing a rename_table
- [mysql] do not force *DEFAULT CHARSET=utf8* when creating new tables
- [postgres] rename the primary key index when renaming a table in pg
- [db2] improve create_table on Z/OS (now supporting AR 4.x TableDefinition) (#581)

## 1.3.13 (11/21/14)

- handle ("hacked") date/time/timestamp conversion from the JDBC side on 4.2
- align SQLite's column class resolution with others in 1.3
- avoid the Column regressions in 1.3.12 caused by backporting too much (#603)

## 1.3.12 (11/18/14)

- [sqlite] support for latest JDBC 3.8
- [mysql] correctly map config[:encoding] into Connector-J characterEncoding
- [mysql] backport rename_index from Rails (corectly handling MariaDB as well)
- [mysql] core adapter compat - missing initialize_schema_migrations_table
- `supports_views?` is now a method available in 4.2 (most DBs support VIEWs)
- [postgres] table_exists? fully compatible with Rails 4.1
- handle pre JDBC 4 driver abstract method errors somehow gracefully
- tune ArJdbc scoped warnings/deprecations (can be off -J-Darjdbc.warn=false)

## 1.3.11 (10/20/14)

- arjdbc: performance improvement - avodinng JRuby's impl iface generation
- [firebird] Use ampersand literal in limit offset sub to fix FIRST 1/SKIP 1
- require super call is not needed and causes issues double loading features

## 1.3.10 (08/29/14)

- [postgres] preliminary (temp) fix for Marshal.dump broken since 1.3.8 (#573)
- [postgres] adapter was missing the custom rename_index method (fixes #577)
- [postgres] user defined types should not raise an error
- [postgres] align with Rails distict white-space fix (regression in 4.0.10)
- [mssql] allow for `offset(x)` without `limit(y)` to work ... (fixes #564)
- [mssql] correctly parse set_table_name string with owner (#574)
- allow database.yml or config option to set `:insert_returning` (#570)
- [sqlite3] savepoint without passed explicit name not supported
- synchronize setting resolved visitor type
- [mssql] (hopefully) fix ORDER BY mis-detection - closes #532 (improved #549)
- [mysql] columns were sometimes instantiated with the wrong column class (#566)

## 1.3.9 (07/07/14)

- [postgres] improve Range's type cast - fixing minor quoting failure on AR 4.x
- [postgres] range type's :exclude_start is actually += 1 (align with AR 4.1)
- [postgres] correctly quote numeric values with string/text column types
- [postgres] backport CVE-2014-3483 and protect against CVE-2014-3482 (from AR)

## 1.3.8 (06/27/14)

- [mysql] updated so that we can run with non-official driver (+ against MariaDB)
- [postgres] quote fix failure with ColumnDefinition on AR 4.0.6.rc2
- [mssql] performance improvements :
  * "optimized" quote_name_part in Java + avoid bytes copying in quoteCharWith
  * throwing exceptions in the hot path results in slow code
  * minor performance improvements to mssql type_cast
- [mssql] fix remove_column on AR < 3.2
- [mssql] dealing with column that need quoting (e.g. ids with spaces) in ORDER
  special care needs to be performed on AR <= 3.2 - Arel < '4.0' (closing #551)
- [mssql] correct default value quoting + update on change when non null with default
- [mssql] backport database ('.' in name) quoting fix from sqlserver adapter
- get the "correct" (AR::Base) record.class on AR 4.1 (#555)
- [oracle] support disabling generated keys `-Darjdbc.oracle.generated_keys=false`
- [postgres] fix returning generated keys + use *arjdbc.postgresql.generated_keys*
- [oracle] working `config[:insert_returning] = true` support (using prepared calls)
- [mysql] improve column instantiation - make sure strict/extra passed correctly
- [postgres] backport rails fix for not quoting array defaults correctly
- [postgres] handle the accessor (e.g. for hstore) added in AR 4.1 (#535)
- [postgres] handle oid_types resolution on AR 4.x (compat with MRI on Rails)
- [postgres] align Column's (string) cast helpers with AR 4.1
- [postgres] quote/cast compat with 4.x + do not quote default function values
- [postgres] align array parser with latest from AR 4.1
- [postgresl] Column AR 4.x compatibility methods: `number?` and `text?`
- [h2] should have it's own arel visitor class (`Arel::Visitors::H2`)
- [h2] support for latest beta of next major release - H2 database **1.4**

Code Contributors (in no particular order): Michael J. Cohen

## 1.3.7 (04/14/14)

- [postgres] set prepared values with array columns on AR < 4.0 correctly
- [postgres] handle null values in array columns with AR < 4.0 (fixes #548)
- [mysql] support for config[:reconnect] (might need some fine tuning to match mysql2)
- fix ordering on an aggregate in MSSQL (#532) (should fix #437 for good)
- introduce a deprecation (warn) method for AR-JDBC and start using it
- [mysql] do not set defaults for text/blob columns on rename/change (#543)
- try resolving config 'database' (if missing) from JDBC url: in rake tasks
- [mysql] needs to `reconnect!` when recreating database (fixes #539)
- remove_column compatibility with Rails 4.x for Oracle, Derby and MSSQL (#541)
- Fix connection without user and password (#542)
- fix db2 remove_column for ActiveRecord 4 (#537)
- FireBird's DB meta-identifier is 31 chars maximum, thanks @mariuz (#538)
- [derby] add emulate booleans option for derby adapter

Code Contributors (in no particular order): Mark Fraser, Pierrick Rouxel, @iaddict

## 1.3.6 (02/04/14)

- fix rails 4-0-stable compatibility (see #530)
- [mysql] support "disabling" abandoned connection cleanup thread
- [mssql] Handling of 'GROUP BY' and selected columns (#529)
  + SELECT DISTINCT clause with ORDER BY for MSSQL (partially fixes #437)
- [derby] only do the patched select_limited_ids if connection is Derby's
- [derby] support getting and setting transaction isolation on a connection
  + allow to configure whether isolation will be 'serializable' (work-around for #497)
- match 'int' as well as 'integer' when converting to SQL types for MSSQL (#527)

Code Contributors: Sean McCarthy, Jesko, Konstantin Shabanov

## 1.3.5 (01/10/14)

We're now green against Rails 4.1 (master), test and report issues if any.

- improved support for `config[:jndi]` with all supported custom adapters
- [mysql] fix incompatible character encodings: ASCII-8BIT and UTF-8
- rails 4.1 - create_table_definition changed from 3 to 4 parameters (#522)
- [firebird] Insert quotes for blobs to prevent failed inserts on not-null cols

Code Contributors: Ray Zane, Gary S. Weaver

## 1.3.4 (12/12/13)

- [postgres] unwrap connection instead of casting when adding custom types (#515)
- [postgres] allow returning string values for (JDBC) arrays with (#510)
- allow for symbol keys with custom JDBC properties in `config[:properties]`
- replacing use of AR::ConnectionFailed with AR::ConnectionNotEstablished (#513)
- [firebird] fix for missing args when visit_Arel_Nodes_SelectCore is called
- [postgres] better column compatibility with 3.x (avoid array/oid_type)
- [postgres] backport array-parser due `Column#extract_default` (#504)
- [postgres] backported "Correctly parse bigint defaults in PostgreSQL"
- [postgres] 4.0 compat - detect default_function just like on MRI
- [postgres] backport support for negative money values (in parenthesis)
- [postgres] support :login_timeout as a standalone config option
- [firebird] align `prefetch_primary_key?` with Oracle (only for simple PKs)
- [oracle] do not pre-fetch the primary key if multiple primary keys exist (#498)

Code Contributors: @andfx, Gavin Stark, Ray Zane, @chapmajs

## 1.3.3 (11/12/13)

- [mysql] allow encoding to be server-detected (using `encoding: false`)
  due compatibility we still default to `encoding: utf8` if not set (fixes #481)
- need to match AR 4.0 built-in patterns to re-define (oracle) tasks correctly
- [postgres] support some of libpg's ENV variables when connecting
- [derby] allow multiple parallell nested transactions on DERBY
- [mssql] when using the Microsoft SQL Server driver, fall back to
  rollback_savepoint when release_savepoint is called (#484)
- [mysql] only kill the connections cancel timer for driver < 5.1.11
- [sqlite3] work-around driver ignoring passed schema for table (fixes #483)
- now using explicit adapter classes with H2/HSQLDB
- [postgres] Add support for array as root element in JSON (#491)
- [postgres] MRI compat - make sure we have a `query` method (fixes #486)
- db:structure:load does not create schema for test db (#480)

Code Contributors (in no particular order): Glenn Goodrich, Joao Carlos,
Jason Franklin, Dominique d'Argent, Sean McCarthy, Uwe Kubosch

## 1.3.2 (10/11/13)

- when "pop-ing" current savepoint name - consider open transaction count (#477)
- [postgres] we should return "raw" hstore values on AR < 4.0 by default
  (regression caused by fixing #454 for AR >= 4.0)
- [postgres] needs ColumnDefinition.array? method used by SchemaCreation (#474)
- [mysql] backported bulk change table support from Rails (fixes #469)
- support MySQL's failover host configurations (multiple hosts specified)
- set JDBC specific config values as properties instead of URL options
- SQLite3's version object should return a string on `to_s`
- [sqlite3] support :timeout option as busy_timeout (similar to Rails)
- [sqlite3] mkdir for sqlite database (path) - just like AR 4.0 now does
- [postgres] handle :connect_timeout, :sslmode, :keepalives & :krbsrvname
- [postgres] support :hostaddr, :user and :dbname options just like Rails does
- fix rake task name **db:structure:load** - missing db: prefix (#465)
- Prevent rake from throwing an exception when task w/o comment is redefined

Code Contributors (in no particular order): Prathamesh Sonpatki, Stefan Wrobel,
Micah Jaffe, Rajan Agaskar

## 1.3.1 (09/17/13)

- helper gems should contain all files from lib/* (#463)
- [postgres] hstore values should be returned as Hash instances (#454)
- we should first allow super AbstractAdapter to initialize then extend spec
  otherwise using *adapter: jdbc* configuration might no work (#457)
- return early (from `table_exists?`) if table name is nil (#460)
- [MS-SQL] handle change_column error when column has default binding or indexes
- AR's `distinct` compatible with 4.x (and 3.x) for Oracle, Derby and Postgres
- re-invent `add_column_options!` (due next AR 4.1) to provide compatibility
- backport SchemaCreation (from AR 4.0/master) + support for all adapters

Code Contributors (in no particular order): Grant Hutchins, Avin Mathew, @emassip

## 1.3.0 (08/29/13)

- [oracle] fix structure_dump: `column['data_default']` might come back as ''
- [oracle] avoid the JDBC call `connection.getMetaData` with exec_query (#453)
- review MSSQL/HSQLDB/H2 explain - make sure prepared statements are used
- [oracle] make sure explain works with prepared statements
- warn users about using our now deprecated suble_binds "extension"
- [mysql] username defaults to 'root' on MRI
- [mysql] match `columns` returned with latest AR 4.0 (collation, strict, extra)
- only `suble_binds` if not an arel passed + allow to turn bind subling off
- [postgres] fix `extension_enabled?` to work with raw boolean values
- [derby] setting true/false into text/string columns values should use `to_s`
  also non-serializable attrs should use `to_s` (instead of `to_yaml`) on 3.x
- [derby] needs `quote_table_name_for_assignment` (on AR 4.0)
- [postgres] driver "hooks" to make PG types work with prepared statements, now
  working: ranges, arrays, interval, (ip) addr types, tsvector, json and uuid
- missing `last_insert_id_result` method on PostgreSQL (#450)
- emulate pre AR 4.0 behavior with date-times/booleans (in custom SELECTs) they
  will be returned as (raw) strings on AR 3.x
- warn when driver is not JDBC 4.0 compilant when checking if valid (#445)
- fix inline rescue syntax - invalid syntax at MSSQL's `string_to_time` (#444)
- no need to (double) update LOB values when using prepared statements
- replaced `emulate_booleans` with `emulate_booleans?` on adapter specs
- [firebird] emulate booleans with char(1) + fix time and review native types
- [db2] using new `update_lob_values` - now handles null inserts safely (#430)
- [mssql] configurable `update_lob_values?` - `string_to_binary` no longer abused
- refactored SerializedAttributesHelper and moved to Util::SerializedAttributes
  there's now a new `update_lob_columns` helper hooked onto AR::Base for adapters
  that send clob/blob values in a separate statement DB2, Oracle, MSSQL, Firebird

Code Contributors (in no particular order): Alexandros Giouzenis

## 1.3.0.rc1 (08/03/13)

- add activerecord gem as a dependency of the main AR-JDBC gem
- override `to_sql` due AR 4.0 - we want to consume the passed binds array
- [sqlite3] introduce Version constant (returned from sqlite_version)
- `execute` expects `skip_logging` param on AR <= 3.0 (+ does not accept binds)
- we shall not do any `to_sql` in any of the exec_xxx methods
- [postgres] array column defaults more reliable (ported from Rails)
- [mssql] review MSSQL date-time handling - no need for that customized quoting
- [mssql] MSSQL - `rake db:migrate:reset` can drop database
- [oracle] handle null strings (e.g. returned on XML columns) instead of NPE
- [oracle] get rid of oracle's `execute_id_insert` not sure how it ever worked
- [oracle] sequence quoting + `insert` refactoring + support for RETURNING
  revisit `insert` / `insert_sql` / `exec_insert` to work for all ARs we support
- [db2] refactor DB2's `last_insert_id` using *IDENTITY_VAL_LOCAL()*
- [db2] DB2 supports standalone *VALUES* statements (just like Derby does)
- [derby] last_insert_id for Derby using *IDENTITY_VAL_LOCAL()*
- [derby] only hookup SQL checks on #execute when no #exec_query etc. available
- [sqlite] query-ing last_insert_id after each INSERT seems redundant
- [sqlite] a saner way of getting last_insert_row_id() via the JDBC API
- better `last_inserted_id` unwrapping on the base (jdbc) adapter level
- [postgres] support exec_insert with PS + make sure RETURNING works
- (thread_safe based) quoted column/table name cache implementation
  currently used with PostgreSQL, Oracle and MS-SQL adapter (#432)
- [mssql] prevent special column corruption of ORDER BY (#431)
- [db2] fix error with timezone + use default date and time parsing
- [db2] fix error on named index removing
- [postgres] fix array values escaping: backslashes should be escaped too
- [postgres] fix `add_column` / `change_column` with arrays
- [mssql]  support for running with official MSSQL driver *adapter: sqlserver*
- [mssql] visitor update (based on built-in) to better resolve ORDER BY
- [mssql] handle SELECT DISTINCT correctly with LIMIT (#154)
- `add_limit_offset!` / `add_lock!` only to be available before AREL (2.3)
- remove Arel::SqlCompiler extensions - was only available with AR 3.0.0 pre
- refactored AREL support - esp. visitor resolution - simpler & more reliable
- [postgres] handle DISTINCT correctly with backwards-compat (#418)
- [firebird] full featured support - first class firebird_connection method
- [jdbc-] jdbc-firebird - packaged JayBird JDBC driver (gem) for FireBird 2.2.3
- [postgres] fix array quoting
- implemented support for returning Ruby Date/Time objects from JDBC
  allows such Ruby objects to be returned in custom SELECTs as well (#349)
- introduce a (better) `update_lob_value` as a `write_large_object` replacement
- beyond second precision with timestamp values for adapters that support 'em
- rename `MissingFunctionalityHelper` -> `TableCopier`
- finishing **prepared statement support** for all (Java API now stable), handles
  `exec_query`, `exec_update`, `exec_delete` and `exec_insert`
- use `init connection` to check if *connection_alive_sql* needed (old driver)
-  JDBC API based savepoint support (that should work for all adapters)
- remove `connection.config=` and make sure it does not change `config`
- avoid executing mysql/sqlite3 JDBC type resolving code (for some speed up)
- simplify native_database_types - now on adapter + overriden avoids jdbc
- [mysql] support canceling a timer for wrapped (JNDI) connections as well
- [mysql] refactor cancel timer (field access) to work correctly (#413)
- Java API: introduce newConnection + refactor @connection_factory to Java
- [postgres] missing point casting code + string to bit casts (#60)
- [derby] tables should only return those from current schema
- [derby] set current schema thus identifiers get resolved (closes #408)
- [derby] no *connection_alive_sql* needed since Derby 10.8
- [postgres] make sure uuid is correctly used/resolved as PK (AR 4.0)
- [postgres] match pk_and_sequence_for with AR 4.0

Code Contributors (in no particular order): Alexey Noskov, Pierrick Rouxel,
Matías Battocchia, @gapthemind and Sören Mothes

## 1.3.0.beta2 (05/30/13)

- only load rake tasks if AR is being used - AR::Railtie is loaded (#234)
- override #structure_dump so it won't silently return while doing nothing
- [h2] support empty insert statement (actually used by AR 4.0)
- [postgres] support 4.0 options for #indexes + dumping partial indexes
- [oracle] "better" rake tasks (kindly borrowed from the enhanced-adapter)
- [db2] some database tasks - with a tested (and fixed) structure_dump
- [db2] should set schema on configure_connection
- [mssql] Fix SQL server version matching on SQL Azure
- [mssql] collation and database_exists? helpers for SQLServer
- [h2] rake db: tasks support (db:structure: dump/load as well as db:drop)
- [hsqldb] structure:dump structure:load and fixed drop database support
- [hsqldb] handle config[:database] with db specific prefix
- [as400] error support for execure_and_auto_confirm
- [db2] remove unused explain method
- AR-4.0 inspired rake task impl (usable and shared with Rails 3.x/2.3 tasks)
- jdbc connection updates to better follow AR semantics
  * #active? should check whether connection is valid
  * #reconnect! should #configure_connection if available
  * use JDBC 4 isValid as alive check fallback (no need for connection_alive_sql)
- [sqlite3] missing adapter.encoding method
- [as400] auto discover support (+ current_schema) for AS/400 with jndi
- use (module) spec.initiialize! convention to perform (lazy) AR initialization
- allow for (potential) adapter_spec overides by user on connection method
- [oracle] column/table name (+ raw) quoting - inspired by enhanced adapter
- [db2] support for `ArJdbc::DB2.emulate_booleans = false`
- [oracle] support for `ArJdbc::Oracle.emulate_booleans = false` (#225)
- [mysql] AR::ConnectionAdapters::MysqlAdapter.emulate_booleans support
- [mysql] #indexes compatible with 4.0 as well as #pk_and_sequence_for
- add config parameter to disable (JDBC) statement escaping and
  disable statement escape processing by default for all (#243)
- [as400] add db2_schema to table_exists? + add support for nil schema
- [mssql] SQLServer visitor compat with next AREL
- [mssql] quote_table_name_for_assignment for MS-SQL
- quote_table_name_for_assignment should only be added on AR >= 4.0
- disable extension auto-discovery for installed gems (unless specified)
- [as400] fix as400 system schema + re-add jndi schema support
- [db2] separate AS400 code into a module + stadalone connection method
- [postgres] quoting that uses column.type (thus works with defs as well)
  only use #sql_type when necessary
- better compatibility with native MySQL/SQLite3 adapter (constants)
- [postgres] restore PostgreSQLColumn.new < 4.0 compatibility
- [h2] allow H2 to set auto increment default value
- [postgres] make sure intifnite date/time values are handled correctly
- [postgres] use quote_table_name_for_assignment from AR-4.0
- [sqlite3] fix remove_column on AR-4.0
- do not load the AR built-in adapters eagerly - but on demand (#353)
- [postgres] ignore encoding option, print a warning about it (#376)
- [h2] check if offset is set, otherwise use the Arel::Node::Offset#expr
- [as400] adding ordering support when using both limit and offset
- [as400] force decimal field with 0 scale to be integers
- [sqlite3] let the JDBC API to figure out indexes (#377)
- support for loading only the necessary Java parts per adapter (#353)
- AREL visitors base impl revisited (to fix long broken query cache),
  make sure a visitor is instantiated by the JDBC adapter (2.3 compatible)
- introduced ArJdbc.modules method that should return adapter modules
- move mysql gem API faking into (rails loadable) test code
- there should be no more need to fake out *pg.rb* (due native 'pg' gem)
- do not fake out SQLite3::Version ... gets only loaded while running tests now

Code Contributors (in no particular order): Jason Franklin, Alexey Noskov,
Brian Kulyk, Pierrick Rouxel, Mike Poltyn and Steve Lorek

## 1.3.0.beta1 (04/11/13)

- [db2] map datetime / timestamp / time types + correct time handling on AS400
- AREL values passed to #to_sql not handled correctly on AR-3.0 (#365)
- (Ruby) API cleanup - removed ArJdbc::Jdbc::Mutex and CompatibilityMethods
- new base implementations for all exec_xxx methods (introduced in AR 3.1)
- returning AR::Result from #exec_query + #exec_query_raw for old behavior
- [mssql] #table_exists? does not filter views (only #tables does)
- [postgres] introduced new types on AR 4.0 - same ones native adapter supports
  (uuid values, arrays, json, hstore, ltree, PG ranges, interval, cidr etc.)
- Java API - now compiled with Java 1.6 since we're using JDBC 4 API anyways
- generic #exec_query returning AR::Result + #exec_raw_query for compatibility
- [postgres] improve #insert_sql (uses primary_key, supports all AR versions)
- [postgres] support config[:insert_returning]
- [postgres] always return correct primary key (failing if no sequence)
- Java API - xxxToRuby refactorings - to allow for more flexible overrides
- [postgres] support BIT(n) type where n > 1 as "bit strings"
- [postgres] #disable_referential_integrity on USER level (AR 4.0 compatible)
- Java API - allow objectToRuby and arrayToRuby overrides
- allow more-intuitive initialize arguments when sub-classing JdbcColumn
- do not translate native (Java) exceptions into StatementInvalid (from #log)
- Java API - replaced #tableLookupBlock with (a new) #matchTables
- [mssql] better message for jTDS driver bug (support disabling explain)
- Java API:- accept (and use) catalog as arg[1] in #columns which does leads to
  a refactoring of #extractTableName to accept a catalog name
- [mssql] current_user and (change-able) default_schema support (#311)
- [sqlite3] correct empty insert statement value (on AR-4.0)
- Java API - do not wrap runtime exceptions when handling throwables
- [mysql] correct empty insert statement value (was not working on 4.0)
- Java API - handle :xml and :array AR column type to JDBC type conversion
- Java API - SQL Array and Object JDBC type (to Ruby) mappings
- Java API - reviewed (and updated) JDBC type handling for adapters :
  * FLOAT/DOUBLE types should be handled (just like REAL) as Double-s
  * NUMERIC/DECIMAL values should be handled as BigDecimal-s
  * BIT/BOOLEAN should be converted to (Ruby) true/false by default
  * NULL should always be returned as nil
  * close binary/character stream & free SQLXML once converted
  * JDBC 4.0 N(CHAR) types should be handled
- JdbcConnectionFactory.newConnection now throws SQLException - this is backwards
  incompatible but most extension do not need to deal with this interface (#347)
- (AR 4.0 compatible) transaction isolation support
- Java API - deprecate SQLBlock class in favor of a parameterized Callable iface
- Java API - #retry makes no sense during #rollback (should use the same connection)
- [postgres] session variables support (from configuration)
- [mysql] session variables support (from configuration)
- [mysql] :strict config option, for STRICT_ALL_TABLES on AR-4.0
- AR 4.0 (master) compatible #rename_table_indexes and #renamed_column_indexes
- [postgres] no need to clear_query_cache after insert on AR-2.3's #insert_sql
- Java API - connection #execute_delete "alias" for #execute_update
- [derby] XMLPARSE when inserting into an XML column type ...
  but still can not retrieve XML values using SELECT * FROM
- [sqlite3] IndexDefinition#unique should be a true/false
- [mssql] execute_procedure support, AR-SQLServer style (#266)
- [mssql] #charset, #current_database
- [mssql] config[:database] support + switching using #use_database (#311)
- [mssql] explain support
- [mssql] better query type detection - make sure WITHs work as SELECts
- [mssql] make sure there's a column class (#269) + better special column magic
- [mssql] better - working date/time quoting (with some ms precision support)
- Java API - re-arrange JDBC (to-ruby) type conversion methods
- [mssql] fix Model.first on SQL Server 2000 when called with only order
- [oracle] XMLTYPE column support - can't test due bug in driver
- [db2] working XML column type support
- [oracle] MATRIALIZED VIEWS/SYNONYMS should be usable on table_exists?
- a better (default) table_exists? (aligned with columns_internal) for all
- Java API - add #mapTables for OOP-ish mapping of results from #getTables
- [db2] [derby] some (working) connection alive sql (db gurus should help)
- [oracle] a working connection alive sql
- [db2] seems like DB2 on ZOS used a non-existing get_primary_key method
- do not call_discovered_column_callbacks for extending column impls
- [hsqldb] a 'valid' connection alive SQL for HSQLDB
- ActiveRecord::AbstractAdapter#exec_insert has 5 args in AR 4.0 (master)
- no need for a ArJdbc::Version module simply use ArJdbc::VERSION
- support auto-loading of adapter gems e.g. when specified in a Gemfile
- load out raltie from arjdbc instead of activerecord-jdbc-adapter thus it will
  work consistently even if only a specific adapter gem is specified in Gemfile
- make sure we require arjdbc instead of just arjdbc/jdbc from adapters

## 1.2.9 (03/20/13)

- [oracle] native database types ala oracle-enhanced adapter
- [oracle] fix #insert (broken since execute+to_sql refactoring) keeping binds
  respect 30 max identifier length with default sequence names
- [db2] add as400 primary key support and re-add explain method
- [mssql] fix table/column name quoting - do not quote if quoted already
- [mssql] change default constrain sql on 2005+ (closes #320)
- [mssql] fix substring issue that prevents detecting a query that contains *
- [mssql] adapter code cleanup + refactored (ArJdbc::) MsSQL -> MSSQL

## 1.2.8 (03/13/13)

- [derby] native types review & cleanup, externalize AR patch-ing
- [h2] correct schema dump (jdbc detected sql types)
- [hsqldb] correct schema dump (jdbc detected sql types)
- cleanup H2 / HSQLDB adapter - HSQLDB should not know about H2
- [mssql] [oracle] [db2] [derby] remove_column 3.x compatibility
- [sqlite3] setup native types + make sure tables accepts table_name as well
- [mysql] version + support_"feature" (as Rails)
- jdbc_connection unwrap parameter for unwrapping (pooled) connections
- (native) connection #columns #columns_internal expects string table_name
- [postgres] no need to clear_query_cache after insert on AR-2.3's #insert_sql
- there's still a double bind when "raw" crud methods used (re-closing #322)

## 1.2.7 (02/12/13)

- add some (probably redundant) synchronization + "arjdbc.disconnect.debug" flag
  as an attempt to detect when connection is set to null (#197 and #198)
  avoid (deprecated) Java.java_to_ruby when wrapping java.sql.Connection
- follow Column-naming convention in MySQL adapter ArJdbc module
- make sure update_sql is public in mysql adapter (Rails compatibility)
- fix 1.2.6 regression - incorrectly setup to_sql method based on Rails version
  this caused double '?' bind substitution issues (#322)

## 1.2.6 (01/31/13)

- [postgres] only set --schema (to search path) for pg_dump if configured (#315)
- [oracle] id limits + quoting; current user/db/schema + savepoint support
- execute "log" (sql) name correctly based on AR version
- deprecate substitute_binds and extract_sql
- [derby] make sure we never modify the passed sql param
- [sqlite3] execute on insert_sql + savepoint support
- [mssql] [firebird] [informix] (shared) serialized attribute support
- [oracle] shared serialized attribute support
- [sqlite3] fix binary column handling failure (#51)
- renamed Sqlite3RubyJdbcConnection to SQLite3RubyJdbcConnection
- [mysql] re-define remove_index! for "better" AR-2.3 compatibility
- [derby] avoid failures with #quote when second arg nil + keep string encoding
- [db2] binary support & improved quoting +
  use lob callback for all since it was failing on BLOB/CLOB inserts otherwise
- [db2] better (simplified) type handling for DB2
- JRuby 1.6.8 compatibility when rescue-ing Java exception
- [mysql] avoid encoding issues with MySQL's quoting methods (#185)
- [postgres] ignore binary precision / limit for bytea
- [oracle] explain (query) support
- [oracle] since Oracle supports TIMESTAMP for quite a while we should not
  create DATE columns for a :timestamp column type
- [oracle] avoid CREATE DDL failure when BLOB has length specified
- [jdbc-] review autoloading backwards-incompatible change in jdbc- gems
  auto-load (backwards-compat) can be enabled back using jdbc.driver.autoload
  system property or using the driver specific autoload option as well
- [jdbc-] Update version handling introduce DRIVER_VERSION constant
- [oracle] should support WITH statements (as SELECTs)
- expose select? and insert? helpers on JdbcAdapter class
- [postgres] bug in create_database without options (#306)
- [db2] correct DB2 schema selection (when as400 url has parameters)
- [db2] DB2 becomes a first-class citizen (adapter) `adapter: db2`
- [h2] [hsqldb] explain support for H2 and HSQLDB
- [db2] column should be checked if ain't nil when quoting on DB2
- [mssql] raise exception when offset is specified but limit is not
- [sqlite3] SQLite3 explain support (Rails style)
- [postgres] re-usable explain support for PostgreSQL (based on Rails)
- [h2] update handling of time fields on H2/HSQLDB (#252)
- rescue (and wrap) only SQLExceptions from driver.connect this caused
  swallowing of runtime exceptions from JDBC drivers
- support for setting (custom) jdbc driver properties in config
- when a new adapter (constant) gets loaded column types should pick it up
- [jdbc-derby] updated to 10.8.3.0
- raise LoadError with explanation on with jTDS 1.3.0 on non Java 1.7
- setup the connection methods when adapter is loaded (broken in 1.2.5)

## 1.2.5 (01/02/13)

- backwards compat with older jdbc- (driver) gems (#279)
- no need to set the :driver for jndi config (did not work anyways) when jdbc is being
  configured + do not raise if there's a :driver_instance setup instead of the :driver
- support extra options with recreate_database (for postgres)
- [jdbc-derby] update Derby to 10.8.2.2
- [jdbc-h2] update H2 to 1.3.170
- no need for poluting Kernel (#jdbc_require_driver) anymore
- [sqlite3] updated sqlite3 binary handling
- [jdbc-jtds] upgrade to jtds (driver) 1.3.0
- JDBC driver names should be on one (re-usable) place
- make sure that (jdbc-xxx gem) .jars are only loaded (required) when first connection
  is attempted (this avoids e.g. sqlite-jdbc.jar being always among loaded features)
- jdbc-* gems should expose the driver_jar instead of (auto) loading it
- [oracle] adding in_clause_limit override to properly handle Oracle's 1000 entry limit
- [jdbc-mysql] upgrade to mysql connector 5.1.22
- [jdbc-postgres] upgade to postgresql-9.2 jar version 9.2-1002
- [postgres] fix standard_conforming_strings's default not being set and
  backslash escaping to account for standard_conforming_strings
- [jdbc-postgres] upgrade to postgres.jar 9.1.903 driver
- [jdbc-h2] update h2.jar to 1.3.168
- [postgres] use newer hex-encoding for postgresql >= 9.0
- [postgres] use updated postgres string escaping for byte arrays
- [hsqldb] fix binary data quoting
- [jdbc-hsqldb] update hsqldb.jar to 2.2.9
- [db2] if guessing the date or time fails return the value
- [db2] fix crasher regression on dump of primary keys
- [db2] fix change_column always executing as as400
- [db2] add support for primary keys to structure_dump
- [db2] detect identity columns in db2 structure_dump
- [mysql] added support for Rails 3.2 explain feature (#159)
- add support for DB_STRUCTURE in db:structure:dump
  (and db:structure:load task) (#203)
- [postgres] rename sequence during table rename
- [db2] iseries returns date with two digit year - leave it as string
- [mssql] fix pessimistic locking
- [mssql] fix row_number errors on SQL Server 2000
- [db2] support WITH statements in select
- [db2] use DECIMAL(1) for boolean fields
- [db2] fetch a sequence value manually for tables with no identity columns
- [postgres] add support for template in PostgreSQLAdapter
- [db2] add recognition of MQTs and ALIASes as table types for DB2
- [postgres] remove count distinct restriction to match native ruby adapter
- [mssql] pull back primary key using table name via AR
- [db2] return nil if using jndi and schema/user is not set
- fixed support for AR 3.2.1
- [postgres] implemented dynamic search path management

## 1.2.2.1 (10/18/12)

- [postgresql] fix regression on insert for Rails 2.3 (#173)

## 1.2.2 (01/27/12)

- Thanks George Murphy and Dwayne Litzenberger for their significant
  work this release!
- AR 3.2.x compatibility via #156 (thanks George Murphy)
- #152: Bunch of derby and mssql fixes (thanks Dwayne Litzenberger)
- #137: Fix configure_arel2_visitors for vanilla JDBC adapters
- #136: query cache fix
- #138: error message improvement for #table_structure (threez)
- #130, #139: sqlite3 should log inserts (Uwe Kubosch)
- #141 column queries logging (George Murphy)
- #142 MySQL fixes for AR 3-1-stable tests (George Murphy)
- #147, #149 Improve speed of PG metadata queries (George Murphy)
- #148 PostgreSQL fixes for AR 3-1-stable tests (George Murphy)
- #128, #129 Fix for invalid :limit on date columns in schema.rb (Lenny Marks)
- #144 Stop using ParseDate (not 1.9 friendly) (Bill Koch)
- #146 Upgrade PG drivers (David Kellum)
- #150 avoid 'TypeError: can't dup Fixnum' for performance (Bruce Adams)

## 1.2.1 (11/23/11)

- #117: Skip ? substitution when no bind parameters are given
- #115: Work around bug in ResultSetMetaData in SQLite
- Enhance the 'change_column' in H2 adapter to support additional options
- Deal with changes in RubyBigDecimal in trunk
- Decimal with scale zero handling (George Murphy)
- Fix blob handling for SQLite3 since SQLiteJDBC does not support
  getBinary (Jean-Dominique Morani)

## 1.2.0 (09/13/11)

- Support for Rails 3.1
- Improvements to index usage on PostgreSQL (albertosaurus and
  pazustep)
- Compatibility: tested with Rails 2.3, 3.0 and 3.1

## 1.1.3 (07/26/11)

- Remove AR version < 3 guard around some caching methods (sugg. invadersmustdie)
- Small bug in arjdbc/discover logic, thanks autotelik.
- Added bigint serial support + some testcases for native type mapping (postgres only)
- mssql: use subscript instead of #first. (Kim Toms)
- #71: fix yield called out of block error
- Silence Rake::DSL warnings for Rake > 0.9

## 1.1.2 (06/20/11)

- Update version of H2 driver from 1.1.107 to 1.3.153 (Ketan
  Padegaonkar, Jeremy Stephens)
- Fix errors in db:test:clone_structure with PostgreSQL (Andrea Campi)
- Fixing limit for sqlServer2000 if primary key is not named 'id'
  (Luca Simone)
- DB2: define jdbc_columns (fixes table_exists? bug) (Nick Kreucher)
- ACTIVERECORD_JDBC-152 - omitting limit when dumping bytea fields
  (Gregor Schmidt)
- Postgres doesn't support a limit for bytea columns (Alex Tambellini)
- JRUBY-5642: Default to schema public if no schema given for postgres
  (Anthony Juckel)
- Sqlite3 supports float data type so use float (Alex Tambellini)
- GH #21: Now using sqlite3 driver from
  http://www.xerial.org/trac/Xerial/wiki/SQLiteJDBC (thanks Ukabu)
- GH #65: PG: Respect integer sizes (Alex Tambellini)
- GH #59: PG: Properly escape bytea-escaped string
- GH #53: oracle: allow configuration of schema through schema: key
- GH #50: PG: support multiple schema in search_path (Daniel
  Schreiber)
- GH #25: Reload ArJdbc.column_types if number of constants changed
- GH #47: Allow table statistics for indexes to be approximate; speeds
  up Oracle
- GH #67: Change primary_keys to use the same catalog/schema/table
  separation logic as columns_internal (Marcus Brito). This change
  allows set_table_name to specify a custom schema.
- GH #49: mssql: quote table names like column names
- GH #56: mssql: Fix 'select 1' behavior introduced by AR 3.0.7
- GH #55: Make decimal columns with no precision or scale stay
  decimals
- GH #45: Add Arel limit support for Firebird (Systho))
- GH #39: PG: allow negative integer default values
- GH #19: Make a stub Mysql::Error class
- ACTIVERECORD_JDBC-148: mssql: Ensure regex doesn't match 'from' in a
  field name
- GH#31: mssql: Remove extra code breaking mssql w/o limit
- ACTIVERECORD_JDBC-156: mssql: Logic fix for detecting select_count?

## 1.1.1 (01/14/11)

- Arel 2.0.7 compatibility: fix bugs arising from use of Arel 2.0.7 +
  ArJdbc 1.1.0.
  - Gracefully handle changes to limit in Arel's AST
  - Avoid conflict with Arel 2.0.7's mssql visitor
- Upgrade to PostgreSQL 9.0.801 JDBC drivers (David Kellum)

## 1.1.0 (12/09/10)

- Don't narrow platform to '-java' only: revert back to 0.9.2 where
  ar-jdbc can be installed under any Ruby (for easier Bundler/Warbler
  usage and less confusion on rubygems.org).
- Upgrade MySQL execute code to use RETURN_GENERATED_KEYS.
- Upgrade to MySQL driver version 5.1.13
- Add multi-statement support, idea from oruen. For databases that
  support it, you can now do:
      results = Model.connection.execute("select 1; select 2")
  and receive back an array of multiple result set arrays. For use with
  MySQL, you need to add
      options:
        allowMultiQueries: true
  in database.yml.
- ACTIVERECORD_JDBC-144: Fix limits appearing in schema dump for some
  datatypes (Uwe Kubosch)
- Fixes for DB2 limit/offset
- Fix rake db:create for 'jdbc' adapter (Joeri Samson)
- add create/drop database methods to h2 adapter (sahglie)
- Use connection getDatabaseProductName instead of getClass.getName
  when detecting JNDI dialects (Denis Odorcic)
- ACTIVERECORD_JDBC-146: Fix create_table to not append encoding (Marc Slemko)
- All green on SQLite3 Rails master ActiveRecord tests
- ACTIVERECORD_JDBC-140: Sync postgres add/change column code from Rails master
- ACTIVERECORD_JDBC-139: TEXT/DATE on PostgreSQL should not have limits

## 1.0.3 (11/29/10)

- ACTIVERECORD_JDBC-143: Implement table_exists? fixing association
  table names with schema prefixes
- Cleanup of column code for hsqldb (Denis Odorcic)
- Rails 3.0.3 support - add Arel 2 visitors for all adapters
- Fix MySQL date types to not have limits (Chris Lowder)
- ACTIVERECORD_JDBC-141: Better schema support in H2

## 1.0.2

- ACTIVERECORD_JDBC-134: Fix conflicting adapter/column superclasses
- ACTIVERECORD_JDBC-135: Fix regression on PG with boolean and :limit
- Slew of Derby fixes courtesy of Denis Odorcic

## 1.0.1

- Fix db:test:purge issue affecting all adapters in 1.0.0 due to
  incorrect fix to JRUBY-5081 in 8b4b9c5

## 1.0.0

- Thanks to David Kellum, Dmitry Denisov, Dwayne Litzenberger, Gregor
  Schmidt, James Walker, John Duff, Joshua Suggs, Nicholas J Kreucher,
  Peter Donald, Geoff Longman, Uwe Kubosch, Youhei Kondou, Michael
  Pitman, Alex B, and Ryan Bell for their contributions to this
  release.
- BIG set of DB2 updates (Thanks Nick Kreucher)
- Deprecate jdbc_adapter/rake_tasks
- (1.0.0.beta1)
- Make database-specific extensions only load when necessary
- Allow for discovery of database extensions outside of ar-jdbc
  proper. This should allow for custom database development to be
  developed and released without relying on AR-JDBC core.
- Get AR's own tests running as close to 100% as possible. MySQL is
  currently 100%, SQLite3 is close.
- JRUBY-4876: Bump up Derby's max index name length (Uwe Kubosch)
- (1.0.0.beta2)
- 98 commits since beta1
- MSSQL updates from dlitz and realityforge
- ACTIVERECORD_JDBC-131: Fix string slug issue for DB2 (Youhei Kondou)
- JRUBY-1642: Don't use H2 INFORMATION_SCHEMA in table or column
  searches
- JRUBY-4972: Attempt to deal with type(0)/:limit => 0 by not setting
  it808e213
- JRUBY-5040: Fix issue with limits on timestamps in MySQL
- JRUBY-3555: Allow setting Derby schema with 'schema:' option
- ACTIVERECORD_JDBC-98: Make sure we actuall raise an error when
  inappropriately configured
- ACTIVERECORD_JDBC-112: Add schema dumper tests for already-fixed
  MySQL type limits
- ACTIVERECORD_JDBC-113: Fix PG float precision issue
- ACTIVERECORD_JDBC-103: Fix decimal options for PG add/change column
  (Michael Pitman)
- ACTIVERECORD_JDBC-127: Fix quoting of Date vs. Time(stamp) for
  Oracle (Lenny Marks)
- Oracle: Sort out the NUMBER vs NUMBER(x) vs NUMBER(x,y) situation.
- JRUBY-3051: Think we finally got the PG mixed-case patches applied.
- JRUBY-5081: Consolidate code for dropping DB via postgres
- ACTIVERECORD_JDBC-101: Add override of LONGVARCHAR => CLOB for
  informix
- ACTIVERECORD_JDBC-107: Fix MySQL update_all issue on AR 2.3
- ACTIVERECORD_JDBC-124: Filter out special _row_num column
- ACTIVERECORD_JDBC-126: Fix sql 2000 limit/offset per Michael Pitman
- ACTIVERECORD_JDBC-125: Add tweak to limit/offset code for HABTM
  queries (alex b)
- ACTIVERECORD_JDBC-129: Don't have limits for text, binary or bit
  fields
- (1.0.0 final)
- Fix a few more SQLite3 AR tests
- SQLite3: handle ":memory:" database
- Release new SQLite3 driver 3.6.14.2 and new Derby driver 10.6.2.1

## 0.9.7

- JRUBY-4781: Fix multiple database connection collision issue w/
  Oracle
- ACTIVERECORD_JDBC-115: Support SAVEPOINTS for MySQL and PG so that
  nested transactions can be faked
- ACTIVERECORD_JDBC-116: Handle schema.table better for MySQL (thanks
  Dilshod Mukhtarov)
- Fix 'Wrong # of arguments (2 for 1)' issue with #create_database for
  MySQL and AR 3.0
- SQLServer 2000 support (thanks Jay McGaffigan)

## 0.9.6

- The Oracle release!
- Oracle should be working much better with this release. Also updated
  to work with Rails 3.
- Get all unit tests running cleanly on Oracle, fixing previous
  datetime/timezone issues.
- ACTIVERECORD_JDBC-83: Add :sequence_start_value option to
  create_table, following oracle_enhanced adapter
- ACTIVERECORD_JDBC-33: Don't double-quote table names in oracle
- ACTIVERECORD_JDBC-17: Fix Oracle primary keys so that /^NUMBER$/ => :integer
- Fix remaining blockers ACTIVERECORD_JDBC-82, JRUBY-3675,
  ACTIVERECORD_JDBC-22, ACTIVERECORD_JDBC-27, JRUBY-4759

## 0.9.5

- The MSSQL release, courtesy of Mike Williams and Lonely
  Planet.
- JRuby + AR-JDBC is now seen as the hassle-free way of using Rails
  with SQLServer!
- Many fixes for MSSQL, including ACTIVERECORD_JDBC-18,
  ACTIVERECORD_JDBC-41, ACTIVERECORD_JDBC-56, ACTIVERECORD_JDBC-94,
  ACTIVERECORD_JDBC-99, JRUBY-3805, JRUBY-3793, JRUBY-4221
- All tests pass on Rails 3.0.0.beta3!

## 0.9.4

- ACTIVERECORD_JDBC-96: DB2 JdbcSpec cannot dump schema correctly
  (Youhei Kondou)
- ACTIVERECORD_JDBC-97: Dont use Rails 3 deprecated constants (David
  Calavera)
- Updates for rake db:schema:dump compatibility with Rails 2.3+ and
  MySQL (Joakim Kolsj�)
- Rails 3.0.0.beta2 compatibility
- Return of Derby, H2, Hsqldb support (requires AR >= 3.0.0.beta2)

## 0.9.3

- Rails 3 compatibility
- PLEASE NOTE: ActiveRecord in Rails 3 has changed in a way that
  doesn't allow non-standard DBs (such as the Derby and H2 embedded
  DBs) to work. We're investigating the effort required to support
  these databases and hope to have something for a future release.
- ACTIVERECORD_JDBC-91: Fix schema search path for PostgreSQL (Alex
  Kuebo)
- ACTIVERECORD_JDBC-87: DB2 ID insert fix (Youhei Kondou)
- ACTIVERECORD_JDBC-90: MSSQL fix for DATEs (jlangenauer)
- ACTIVERECORD_JDBC-93: Fix string IDs for sqlite3, hsql/h2 (moser)
- ACTIVERECORD_JDBC-86: Fix Derby queries starting with VALUES (Dwayne Litzenberger)
- ACTIVERECORD_JDBC-95: Fix INSERT ... RETURNING for PostgreSQL

## 0.9.2

- The main, highly awaited fix for this release is a solution to the
  rake db:create/db:drop issue. The main change is a new 'jdbc' rails
  generator that should be run once to prepare a Rails application to
  use JDBC. The upside of this generator is that you no longer will
  need to alter database.yml for JDBC. See the README.txt for details.
- Cleanup and reconnect if errors occur during begin/rollback
  (Jean-Dominique Morani, Christian Seiler)
- ACTIVERECORD_JDBC-1: Add #drop_database method for oracle (does the
  same thing as recreate_database)
- Sqlite3 and MSSQL fixes (Jean-Dominique Morani)
- JRUBY-3512: Treat LONGVARCHAR as a CLOB for Mssql
- JRUBY-3624: Upgrade Derby to 10.5.3.0 and add native limit/offset
  support (Christopher Saunders)
- JRUBY-3616: Fix postgres non-sequence primary keys (David Kellum)
- JRUBY-3669: Fix Oracle case with unconfigured schema (Dan Powell)
- Fixed quote_column_name of jdbc_oracle to accept numbers (Marcelo
  Murad)
- Fix for mysql tables with non standard primary keys such that the
  schema dump is correct (Nick Zalabak)
- MSSQL fixes from Mike Luu:
  - add support for MSSQL uniqueidentifier datatype
  - always quote strings using unicode identifier for MSSQL
- Changes primary_key generation to use always instead of by default
  for DB2 (Amos King)
- Improves the SQLite adapter by fixing rename_column, change_column,
  change_column_default, changing remove_column, and adding
  remove_columns (Ryan Baumann)
- More oracle love courtesy Ben Browning and Jens Himmelreich
- JRUBY-3608: Add missing change_column_null method for postgres
- JRUBY-3508: Fix quoting of integer and float columns

## 0.9.1

- We did a lot of internal cleanup this release in the hopes of
  simplifying the code and increasing performance.
- Many SQLite updates (thanks Nils Christian Haugen)
- JRUBY-2912: Fix MSSQL create/drop database (Joern Hartmann)
- JRUBY-2767: Mistake in selecting identity with H2/HSQLDB
- JRUBY-2884: jdbc_postgre.rb issue handling nil booleans (also a fix
  for hsqldb/h2) + tests
- JRUBY-2995: activerecord jdbc derby adapter should quote columns
  called 'year'
- JRUBY-2897:  jdbc_postgre.rb needs microsecond support
- JRUBY-3282: Upgrade to derby 10.4.2.0 to allow unique constraints
  with nullable columns
- Update h2 from 1.0.63 to 1.1.107 in driver
- JRUBY-3026: [Derby] Allow select/delete/update conditions with
  comparison to NULL using '='
- JRUBY-2996: ...(actually this fixes only remaining issue of this bug
  which was symbols making into quote were exploding
- JRUBY-2691: Update sybase driver to pass simple unit tests with jtds
  and verify it works with the new dialect keyword. patch by Leigh
  Kennedy
- Make :float type work on h2,hsql [returned as string]. Make :float
  work on hsqldb (no paren value supported). Make REAL_TYPE just
  return RubyFloat
- JRUBY-3222: Upgrade #type_to_sql to variation of AR 2.1.2 version
- Add patch supplied in JRUBY-3489 (patch by Jean-Dominique Morani)
- Various Oracle fixes by edsono
- JRUBY-2688: Don't hard-code MySQL connection character encoding to
  utf8

## 0.9

- Now updated to support ActiveRecord 2.2. JNDI-based connections will
  automatically connect/disconnect for every AR connection pool
  checkout/checkin. For best results, set your pool: parameter >= the
  actual maximum size of the JNDI connection pool. (We'll look at how
  to eliminate the need to configure AR's pool in the future.)
- NEW! Informix support courtesy of Javier Fernandez-Ivern.
- Backport another Oracle CLOB issue, thanks Edson C�sar.
- Rubyforge #22018: chomp final trailing semicolon for oracle
- JRUBY-2848: Fix NPE error in set_native_database_types
- Rework oracle lob saving callback to be Rails 2.1 friendly (assist
  from court3nay)
- JRUBY-2715: Add create/drop database methods to Postgres (Peter Williams)
- JRUBY-3183: Fix structure dump for Postgres (Ryan Bell)
- JRUBY-3184: recreate_database for test database working for PG (Ryan Bell)
- JRUBY-3186: disable referential integrity for PG (Ryan Bell)
- Authoritative repository now hosted at
  git://github.com/nicksieger/activerecord-jdbc-adapter.git; rubyforge
  svn trunk cleaned out.

## 0.8.2

- Added an optional config key called :dialect. Using :dialect allows you to
  override the default SQL dialect for the driver class being used. There are
  a few cases for this:
  - Using using Sybase w/ the jTDS driver.
  - Using rebranded drivers.
  - It makes more sense to use :dialect, rather then :driver when using JNDI.
- JRUBY-2619: Typo with :test config causing problems with dev database (Igor Minar)
- 20524, JRUBY-2612: Since when did I think that there was a #true? method on Object?

## 0.8.1

- Now sporting a JDBC sqlite3 adapter! Thanks Joseph Athman.
- Added support for InterSystems Cache database (Ryan Bell)
- Fix for JRUBY-2256
- JRUBY-1638, JRUBY-2404, JRUBY-2463: schema.table handling and Oracle NUMBER fixes (Darcy Schultz & Jesse Hu)
- Add structure dump and other DDL-ish for DB2 (courtesy abedra and stuarthalloway)
- Fix missing quote_table_name function under Rails 1.2.6 and earlier
- Small tweaks to jdbc.rake to select proper config
- JRUBY-2011: Fix MSSQL string un-quoting issue (Silvio Fonseca)
- JRUBY-1977, 17427: Fix information_schema select issue with MSSQL (Matt Burke)
- 20479: Improve get_table_name for MSSQL (Aslak Hellesøy)
- 20243: numerics improvements for MSSQL (Aslak Hellesøy)
- 20172: don't quote table names for MSSQL (Thor Marius Henrichsen)
- 19729: check for primary key existence in postgres during insert (Martin Luder)
- JRUBY-2297, 18846: retrying failing SQL statements is harmful when not autocommitting (Craig McMillan)
- 10021: very preliminary sybase support. (Mark Atkinson) Not usable until collision w/ sqlserver driver is resolved.
- JRUBY-2312, JRUBY-2319, JRUBY-2322: Oracle timestamping issues (Jesse Hu & Michael König)
- JRUBY-2422: Fix MySQL referential integrity and rollback issues
- JRUBY-2382: mysql string quoting fails with ArrayIndexOutofBoundsException

## 0.8

- NOTE: This release is only compatible with JRuby 1.1RC3 or later.
- Because of recent API changes in trunk in preparation for JRuby 1.1, this release is not
  backward compatible with previous JRuby releases. Hence the version bump.
- Internal: convert Java methods to be defined with annotations
- Fix problem with reserved words coming back pre-quoted from #indexes in postgres
- JRUBY-2205: Fix N^2 allocation of bytelists for mysql quoting (taw)
- Attempt a fix for Rubyforge 18059
- Upgrade derby to 10.3.2.1
- Fix db:create etc. in the case where JDBC is loaded in Rails' preinitializer.rb
- Fix db:drop to actually work
- Fix for Rubyforge #11567 (Matt Williams)

## 0.7.2

- JRUBY-1905: add_column for derby, hsqldb, and postgresql (Stephen Bannasch)
- Fix db:create for JDBC
- Support Rails 2 with the old "require 'jdbc_adapter'" approach
- JRUBY-1966: Instead of searching for just tables, search for views and tables.
- JRUBY-1583: DB2 numeric quoting (Ryan Shillington)
- JRUBY-1634: Oracle DATE type mapping (Daniel Wintschel)
- JRUBY-1543: rename_column issue with more recent MySQL drivers (Oliver Schmelzle)
- Rubyforge #15074: ConnectionAdapters::JdbcAdapter.indexes is missing name and
  schema_name parameters in the method signature (Igor Minar)
- Rubyforge #13558: definition for the indexes method (T Meyarivan)
- JRUBY-2051: handle schemaname and tablename more correctly for columns
- JRUBY-2102: Postgres Adapter cannot handle datetime type (Rainer Hahnekamp)
- JRUBY-2018: Oracle behind ActiveRecord-JDBC fails with "Invalid column index" (K Venkatasubramaniyan)
- JRUBY-2012: jdbc_mysql structure dump fails for mysql views (Tyler Jennings)

## 0.7.1

- Add adapter and driver for H2 courtesy of Caleb Land
- Fix "undefined method `last' for {}:Hash" error introduced with new Rake 0.8.1 (JRUBY-1859)

## 0.7

- PLEASE NOTE: This release is not compatible with JRuby releases earlier than
  1.0.3 or 1.1b2. If you must use JRuby 1.0.2 or earlier, please install the
  0.6 release.
- Release coincides with JRuby 1.0.3 and JRuby 1.1b2 releases
- Simultaneous support for JRuby trunk and 1.0 branch
- Get rid of log_no_bench method, so we time SQL execution again.
- Implement #select_rows
- MySQL migration and quoting updates

## 0.6

- Gem is renamed to "activerecord-jdbc-adapter" to follow new conventions
  introduced in Rails 2.0 for third-party adapters. Rails 2.0 compatibility is
  introduced.
- Add dependency on ActiveRecord >= 1.14 (from the Rails 1.1.x release)
- New drivers (jdbc-XXX) and adapter (activerecord-jdbcXXX-adapter) gems
  available separately. See the README.txt file for details.
- Plain "jdbc" driver is still available if you want to use the full
  driver/url way of specifying the driver.
- More bugfixes to Oracle and SQLServer courtesy of Ola & ThoughtWorks

## 0.5

- Release coincides with JRuby 1.0.1 release
- It is no longer necessary to specify :driver and :url configuration
  parameters for the mysql, postgresql, oracle, derby, hsqldb, and h2
  adapters. The previous configuration is still valid and compatible, but for
  new applications, this makes it possible to use the exact same database.yml
  configuration as Rails applications running under native Ruby.
- JDBC drivers can now be dynamically loaded by Ruby code, without being on
  the classpath prior to launching JRuby. Simply use "require
  'jdbc-driver.jar'" in JRuby code to add it to the runtime classpath.
- Updates to HSQL, MS SQLServer, Postgres, Oracle and Derby adapters

## 0.4

- Release coincides with JRuby 1.0 release
- Shoring up PostgreSQL (courtesy Dudley Flanders) and HSQL (courtesy Matthew
  Williams)
- Fix timestamps on Oracle to use DATE (as everything else)
- Derby fixes: Fix for open result set issue, better structure dump, quoting,
  column type changing
- Sybase type recognition fix (courtesy Dean Mao)

## 0.3.1

- Derby critical fixes shortly after 0.3

## 0.3

- Release coincides with JRuby 1.0.0RC1 release
- Improvements for Derby, Postgres, and Oracle, all of which are running
  > 95% of AR tests

## 0.2.4

- Release coincides with JRuby 0.9.9 release
- JRuby 0.9.9 is required
- MySQL close to 100% working
- Derby improvements
- DECIMAL/NUMERIC/FLOAT/REAL bugs fixed with type recognition for Oracle,
  Postgres, etc.
- HSQLDB has regressed this release and may not be functioning; we'll get it
  fixed for the next one

## 0.2.3

- Release coincides (and compatible) with JRuby 0.9.8 release
- 8 bugs fixed: see http://rubyurl.com/0Da
- Improvements and compatibility fixes for Rails 1.2.x

## 0.2.1, 0.2.2

- Early releases, added better support for multiple databases

## 0.0.1

- Initial, very alpha release
