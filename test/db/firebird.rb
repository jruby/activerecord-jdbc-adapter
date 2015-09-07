require 'test_helper'

# FireBird setup (Debian/Ubuntu) :
# sudo dpkg-reconfigure firebird2.5-super
# - check your SYSDBA password at :
# sudo cat /etc/firebord/2.5/SYSDBA.password
# - create a database, run `isql-fb` and :
#
# CREATE DATABASE './test.fdb'
# USER 'SYSDBA' PASSWORD 'masterkey'
# DEFAULT CHARACTER SET UTF8 ;
#

config = { :adapter => 'firebird' }
config[:host] = ENV['FB_HOST'] if ENV['FB_HOST']
config[:username] = ENV['FB_USER'] || 'sysdba'
config[:password] = ENV['FB_PASS'] || 'masterkey'
config[:database] = ENV['FB_DATABASE'] || './test.fdb'

ActiveRecord::Base.establish_connection(config)
