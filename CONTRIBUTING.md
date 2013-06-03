
ActiveRecord-JDBC-Adapter is currently a volunteer effort, not backed by any company!

We would like to encourage you to try looking into the issue, esp. if it's working on MRI - as it might be a simple incompatibility with a copy-paste fix.

If you're reporting an issue (esp. against **1.2.x**) please consider testing against master, if you're in doubt whether it might have been fixed already.
Simply change to `gem 'activerecord-jdbc-adapter', :github => 'jruby/activerecord-jdbc-adapter'` in your *Gemfile*.

Please make sure you include the following with your bug report :

* version of gem the issue happened (if you've tested against master mention that)

* version of Rails / ActiveRecord you're running with

* JRuby version used (you might include your Java version as well)

* if you've setup the JDBC driver yourself please mention that

* include any (relaed) JRuby back-traces (or Java stack-traces) you've seen in your logs

* ... and a way to reproduce :)

To speed-up the response on your issues or simply support the development (of **1.3.x**) you might [donate](https://www.bountysource.com/#fundraisers/311-activerecord-jdbc-adapter-1-3-x).

:heart: JRuby-Up!
