## Sample DB Setup

    export PGDATABASE=bench
    export PGUSER=benchmark
    export PGPASSWORD=bench

`psql -d postgres -U postgres -W` :

    \set database `echo "$PGDATABASE"`
    DROP DATABASE IF EXISTS :database ;

    \set user `echo "$PGUSER"`
    \set password `echo "$PGPASSWORD"`
    DROP USER IF EXISTS :user ;
    CREATE USER :user CREATEDB SUPERUSER LOGIN PASSWORD ':password' ;

    CREATE DATABASE :database OWNER :user ;

## Running (with PostgreSQL)

    export AR_VERSION="~>4.1"
    export AR_ADAPTER=postgresql

### Supported ENV Variables

```
export AR_VERSION="~>4.1"
# by default latest installed is picked
export ARJDBC_VERSION="1.3.16"
# leave empty to use AR-JDBC from repo
export AR_ADAPTER=mysql2
export AR_USERNAME=bench
export AR_PASSWORD=passw
export AR_DATABASE=bench
export AR_LOGGER=debug
# look for active_record.log
export DATA_SIZE=10000
# default is 1000 records created
export TIMES=500
# default is 100 iterations
```

run some benchmark `ruby -Ijdbc-postgres/lib bench/benchmark_selects.rb 5000` :
```
--- RUBY_VERSION: 1.9.3 (JRUBY_VERSION: 1.7.19 1.7.0_72-b14)
--- ActiveRecord: 4.1.10 (AR-JDBC: 1.4.0.dev 265c2e9a)

 - BenchRecord.connection.drop_table(:bench_records) took 0.011
 - BenchRecord.connection.create_table(:bench_records) { ... } took 0.032

 - BenchRecord.create!(...) [1000x] took 12.726
Rehearsal ---------------------------------------------------------------------------------------------------
BenchRecord.select('a_binary').where(:id => i).first [5000x]     12.630000   0.330000  12.960000 ( 11.092000)
BenchRecord.select('a_boolean').where(:id => i).first [5000x]     9.470000   0.280000   9.750000 (  8.455000)
BenchRecord.select('a_date').where(:id => i).first [5000x]       12.200000   0.290000  12.490000 (  7.704000)
BenchRecord.select('a_datetime').where(:id => i).first [5000x]    4.090000   0.220000   4.310000 (  5.454000)
BenchRecord.select('a_decimal').where(:id => i).first [5000x]     3.560000   0.220000   3.780000 (  5.341000)
BenchRecord.select('a_float').where(:id => i).first [5000x]       3.940000   0.230000   4.170000 (  5.845000)
BenchRecord.select('a_integer').where(:id => i).first [5000x]     3.610000   0.230000   3.840000 (  5.500000)
BenchRecord.select('a_string').where(:id => i).first [5000x]      3.740000   0.230000   3.970000 (  5.645000)
BenchRecord.select('a_text').where(:id => i).first [5000x]        3.680000   0.220000   3.900000 (  5.495000)
BenchRecord.select('a_time').where(:id => i).first [5000x]        3.580000   0.210000   3.790000 (  5.345000)
BenchRecord.select('a_timestamp').where(:id => i).first [5000x]   3.690000   0.220000   3.910000 (  5.357000)
BenchRecord.select('*').where(:id => i).first [5000x]             4.820000   0.250000   5.070000 (  7.066000)
----------------------------------------------------------------------------------------- total: 71.940000sec

                                                                      user     system      total        real
BenchRecord.select('a_binary').where(:id => i).first [5000x]      3.980000   0.220000   4.200000 (  5.420000)
BenchRecord.select('a_boolean').where(:id => i).first [5000x]     3.530000   0.210000   3.740000 (  5.296000)
BenchRecord.select('a_date').where(:id => i).first [5000x]        4.600000   0.260000   4.860000 (  6.295000)
BenchRecord.select('a_datetime').where(:id => i).first [5000x]    3.640000   0.220000   3.860000 (  5.471000)
BenchRecord.select('a_decimal').where(:id => i).first [5000x]     3.630000   0.220000   3.850000 (  5.423000)
BenchRecord.select('a_float').where(:id => i).first [5000x]       3.600000   0.220000   3.820000 (  5.381000)
BenchRecord.select('a_integer').where(:id => i).first [5000x]     3.590000   0.220000   3.810000 (  5.429000)
BenchRecord.select('a_string').where(:id => i).first [5000x]      3.770000   0.230000   4.000000 (  5.681000)
BenchRecord.select('a_text').where(:id => i).first [5000x]        3.590000   0.220000   3.810000 (  5.386000)
BenchRecord.select('a_time').where(:id => i).first [5000x]        3.520000   0.210000   3.730000 (  5.216000)
BenchRecord.select('a_timestamp').where(:id => i).first [5000x]   3.900000   0.250000   4.150000 (  5.905000)
BenchRecord.select('*').where(:id => i).first [5000x]             4.270000   0.240000   4.510000 (  6.513000)

```

sample MySQL run `AR_VERSION="~>3.2" AR_ADAPTER=mysql2 ruby -Ijdbc-mysql/lib bench/benchmark_update.rb 5000` :
```
--- RUBY_VERSION: 1.9.3 (JRUBY_VERSION: 1.7.19 1.7.0_72-b14)
--- ActiveRecord: 3.2.21 (AR-JDBC: 1.4.0.dev 265c2e9a)

 - BenchRecord.connection.drop_table(:bench_records) took 0.032
 - BenchRecord.connection.create_table(:bench_records) { ... } took 0.059

Rehearsal ---------------------------------------------------------------------------------------------------------------------------------------
BenchRecord#update() [5000x]                                                                          4.100000   0.410000   4.510000 (  3.115000)
BenchRecord#update('a_binary' => "\x06\xB5Q\x81YG+\xDEQv\x88\xFE\xEA\x9B\xA7\xE9...(1536)") [5000x]  13.760000   1.200000  14.960000 ( 46.058000)
BenchRecord#update('a_boolean' => true) [5000x]                                                      11.130000   1.040000  12.170000 ( 42.058000)
BenchRecord#update('a_date' => Mon, 27 Apr 2015) [5000x]                                             10.940000   1.190000  12.130000 ( 43.960000)
BenchRecord#update('a_datetime' => Mon, 27 Apr 2015 10:19:20 +0200) [5000x]                           8.250000   1.240000   9.490000 ( 44.488000)
BenchRecord#update('a_decimal' => #<BigDecimal:284fab15,'1234567890.55555',15(16)>) [5000x]           8.760000   1.310000  10.070000 ( 44.437000)
BenchRecord#update('a_float' => 999.99) [5000x]                                                       8.430000   1.400000   9.830000 ( 44.928000)
BenchRecord#update('a_integer' => 4242) [5000x]                                                       8.680000   1.680000  10.360000 ( 46.721000)
BenchRecord#update('a_string' => "BORAT Ipsum!") [5000x]                                              7.800000   1.450000   9.250000 ( 44.952000)
BenchRecord#update('a_text' => "Kazakhstan is th...(464)") [5000x]                                    8.590000   1.610000  10.200000 ( 47.619000)
BenchRecord#update('a_time' => 2015-04-27 10:19:20 +0200) [5000x]                                     8.530000   1.390000   9.920000 ( 45.802000)
BenchRecord#update('a_timestamp' => 2015-04-27 10:19:20 +0200) [5000x]                                9.280000   1.600000  10.880000 ( 47.332000)
BenchRecord#update(...) [5000x]                                                                       5.050000   0.580000   5.630000 (  4.978000)
---------------------------------------------------------------------------------------------------------------------------- total: 129.400000sec

                                                                                                          user     system      total        real
BenchRecord#update() [5000x]                                                                          1.500000   0.400000   1.900000 (  2.021000)
BenchRecord#update('a_binary' => "\x06\xB5Q\x81YG+\xDEQv\x88\xFE\xEA\x9B\xA7\xE9...(1536)") [5000x]   1.620000   0.410000   2.030000 (  2.373000)
BenchRecord#update('a_boolean' => true) [5000x]                                                       1.590000   0.390000   1.980000 (  2.289000)
BenchRecord#update('a_date' => Mon, 27 Apr 2015) [5000x]                                              1.710000   0.430000   2.140000 (  2.357000)
BenchRecord#update('a_datetime' => Mon, 27 Apr 2015 10:19:20 +0200) [5000x]                           2.220000   0.430000   2.650000 (  2.625000)
BenchRecord#update('a_decimal' => #<BigDecimal:284fab15,'1234567890.55555',15(16)>) [5000x]           1.670000   0.480000   2.150000 (  2.517000)
BenchRecord#update('a_float' => 999.99) [5000x]                                                       1.600000   0.410000   2.010000 (  2.326000)
BenchRecord#update('a_integer' => 4242) [5000x]                                                       1.770000   0.430000   2.200000 (  2.637000)
BenchRecord#update('a_string' => "BORAT Ipsum!") [5000x]                                              1.660000   0.400000   2.060000 (  2.438000)
BenchRecord#update('a_text' => "Kazakhstan is th...(464)") [5000x]                                    1.680000   0.440000   2.120000 (  2.506000)
BenchRecord#update('a_time' => 2015-04-27 10:19:20 +0200) [5000x]                                     1.660000   0.420000   2.080000 (  2.390000)
BenchRecord#update('a_timestamp' => 2015-04-27 10:19:20 +0200) [5000x]                                1.610000   0.370000   1.980000 (  2.308000)
BenchRecord#update(...) [5000x]                                                                       3.000000   0.400000   3.400000 (  3.655000)

```

**NOTE:** benchmarks are runnable under MRI (just remove `-I` and install the driver gem e.g. mysql2)
