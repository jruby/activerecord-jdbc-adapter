if defined?(Rake.application) && Rake.application
  skip = ENV["SKIP_AR_JDBC_RAKE_REDEFINES"] # jruby -J-Darjdbc.tasks.skip=true -S rake ...
  if !(Java::JavaLang::Boolean.getBoolean('arjdbc.tasks.skip') || ( skip && skip != 'false' ))
    databases_rake = File.expand_path('tasks/databases.rake', File.dirname(__FILE__))
    if Rake.application.lookup("db:create")
      load databases_rake # load the override tasks now
    else # rails tasks not loaded yet; load as an import
      Rake.application.add_import(databases_rake)
    end
  end
else
  warn "ArJdbc: could not load rake tasks - rake not loaded ..."
end
