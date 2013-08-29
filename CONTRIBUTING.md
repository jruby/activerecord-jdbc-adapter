
## Contributing to ActiveRecord JDBC Adapter

AR-JDBC is (currently) a volunteer effort, it is not backed by any company ...
You can contribute and make a difference for all the JRuby on Rails deployments
out there.

### Reporting Issues

We encourage you to try looking into reported issues, esp. if the new issue is about
(Rails) incompatibility with MRI - as it might be fixed with some copy-paste magic.

Please consider testing against **master**, if you're in doubt whether it might
have been [fixed](History.md) already, change the following in your *Gemfile* :
`gem 'activerecord-jdbc-adapter', :github => 'jruby/activerecord-jdbc-adapter'`

Do not forget to **include the following with your bug report** :

* AR-JDBC's version used (if you've tested against master mention it)

* version of Rails / ActiveRecord you're running with

* JRuby version (you might include your Java version as well) - `jruby -v`

* if you've setup the JDBC driver yourself please mention that (+ it's version)

* include any (related) back-traces (or Java stack-traces) you've seen in the logs

* ... a way to reproduce :)

### Pull Requests

You're code will end up on upstream faster if you provide tests as well, read on
how to [run AR-JDBC tests](RUNNING_TESTS.md).

When fixing issues for a particular Rails version please be aware that we support
multiple AR versions from a single code-base (and that means supporting Ruby 1.8
as well - esp. targeting 4.x **we can not use the 1.9 syntax** yet).

Please keep our [test-suite](https://travis-ci.org/jruby/activerecord-jdbc-adapter)
green (been funky for a while and it's been hard-work getting in back to shape),
while making changes, if they're related to an adapter covered by those.

:heart: JRuby-Up!
