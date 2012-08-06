#!/bin/sh

jruby.sh -I connections/native_jdbc_mysql $1 | tee $1.log
