config = {
  :username => 'blog',
  :password => 'blog',
  :adapter  => 'oracle',
  :host => ENV["ORACLE_HOST"] || 'localhost',
  :database => ENV["ORACLE_SID"] || 'XE' # XE is the default SID for oracle xe
}

ActiveRecord::Base.establish_connection(config)

# Here are some notes of things I had to do to get running on Oracle
# XE.
#
#   ON Linux:
#   create tablespace weblog_development
#     datafile '/usr/lib/oracle/xe/oradata/XE/weblog_development.dbf';
#   ON Windows XP:
#   create tablespace weblog_development 
#     datafile 'C:\ORACLEXE\ORADATA\XE\WEBLOGD.DBF' size 16m;
#
#   create user blog identified by blog
#     default tablespace weblog_development;
#   grant all privileges to blog;
#
# You might need to up the number of processes and restart the
# listener. (In my case, I had to reboot.) See
# http://it.newinstance.it/2007/06/01/ora-12519-tnsno-appropriate-service-handler-found/
#
#   alter system set PROCESSES=150 scope=SPFILE;
#
# These might be helpful too (numbers are rather arbitrary...)
#
#   alter system set TRANSACTIONS=126 scope=SPFILE;
#   alter system set SESSIONS=115 scope=SPFILE;
