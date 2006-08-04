#!/bin/sh

for test in *_test.rb; do
    ./jtest.sh $test
done

#jruby.sh -I connections/native_jdbc_mysql -e 'Dir.foreach(".") { |file| require file if file =~ /_test.rb$/ }' | tee all.log
