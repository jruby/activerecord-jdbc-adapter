
## Contributing to ActiveRecord JDBC Adapter

AR-JDBC is (currently) a volunteer effort, you can contribute and make the world
a better place for all the JRuby on Rails deployments out there.

**NOTE:** master targets 1.4 please use the **1-3-stable** branch to target 1.3.x

### Reporting Issues

We encourage you to try looking into reported issues, esp. if for issues around
(Rails) incompatibility with MRI - as the fix often only needs some copy-pasting.

Please consider testing against **master**, if you're in doubt whether it might
have been [fixed](History.md) already, change the following in your *Gemfile* :

`gem 'activerecord-jdbc-adapter', :github => 'jruby/activerecord-jdbc-adapter'`

**NOTE:** the native extension *adapter_java.jar* has been included within the
source code until 1.4.0, you'll need to have JDK 7 installed to build it.

Please, do not forget to **include the following with your bug report** :

* AR-JDBC's version used (if you've tested against master mention it)

* version of Rails / ActiveRecord you're running with

* JRuby version (you might include your Java version as well) - `jruby -v`

* if you've setup the JDBC driver yourself please mention that (+ it's version)

* include any (related) back-traces (or Java stack-traces) you've seen in the logs

* ... a (deterministic) way to reproduce :)

### Pull Requests

You're code will end up on upstream faster if you provide tests as well, read on
how to [run AR-JDBC tests](RUNNING_TESTS.md).

When fixing issues for a particular Rails version please be aware that we support
multiple AR versions from a single code-base (and that might mean supporting Ruby
1.8 as well - esp. targeting 4.x **we can not use the 1.9 syntax** yet).

Please keep our [test-suite](https://travis-ci.org/jruby/activerecord-jdbc-adapter)
green (been funky for a while and it's been hard-work getting it in back to shape),
while making changes, or at least do not introduce new failures if there's some.

:heart: JRuby-Up!
