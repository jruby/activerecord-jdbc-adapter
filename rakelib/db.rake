namespace :db do
  task :load_arjdbc do
    $LOAD_PATH.unshift 'test'
    $LOAD_PATH.unshift 'lib'
    require 'abstract_db_create'
  end

  desc "Creates the test database for MySQL."
  task :mysql => :load_arjdbc do
    load 'test/db/mysql.rb' rescue nil
    def db_config
      MYSQL_CONFIG
    end
    extend AbstractDbCreate
    do_setup('arjdbc', nil)
    Rake::Task['db:drop'].invoke rescue nil
    Rake::Task['db:create'].invoke
  end
end
