require File.expand_path('../../test/shared_helper', __FILE__)

namespace :db do

  desc "Creates the test database for MySQL"
  task :mysql do
    fail "could not create test database: mysql executable not found" unless mysql = which('mysql')
    load 'test/db/mysql_config.rb' # rescue nil
    script = sql_script <<-SQL, 'mysql'
DROP DATABASE IF EXISTS `#{MYSQL_CONFIG[:database]}`;
CREATE DATABASE `#{MYSQL_CONFIG[:database]}` DEFAULT CHARACTER SET `utf8` COLLATE `utf8_general_ci`;
GRANT ALL PRIVILEGES ON `#{MYSQL_CONFIG[:database]}`.* TO #{MYSQL_CONFIG[:username]}@localhost;
GRANT ALL PRIVILEGES ON `test\_%`.* TO #{MYSQL_CONFIG[:username]}@localhost;
SET PASSWORD FOR #{MYSQL_CONFIG[:username]}@localhost = PASSWORD('#{MYSQL_CONFIG[:password]}');
SQL
    params = { '-u' => 'root' }
    if ENV['DATABASE_YML']
      require 'yaml'
      password = YAML.load(File.new(ENV['DATABASE_YML']))["production"]["password"]
      params['--password'] = password
    end
    puts "Creating MySQL (test) database: #{MYSQL_CONFIG[:database]}"
    sh "cat #{script.path} | #{mysql} #{params.to_a.join(' ')}", :verbose => $VERBOSE # so password is not echoed
  end

  desc "Creates the test database for PostgreSQL"
  task :postgresql do
    fail 'could not create test database: psql executable not found' unless psql = which('psql')
    fail 'could not create test database: missing "postgres" role' unless PostgresHelper.postgres_role?
    load 'test/db/postgres_config.rb' # rescue nil
    script = sql_script <<-SQL, 'psql'
DROP DATABASE IF EXISTS #{POSTGRES_CONFIG[:database]};
DROP USER IF EXISTS #{POSTGRES_CONFIG[:username]};
CREATE USER #{POSTGRES_CONFIG[:username]} CREATEDB SUPERUSER LOGIN PASSWORD '#{POSTGRES_CONFIG[:password]}';
CREATE DATABASE #{POSTGRES_CONFIG[:database]} OWNER #{POSTGRES_CONFIG[:username]}
       TEMPLATE template0
       ENCODING '#{POSTGRES_CONFIG[:encoding]}' LC_COLLATE '#{POSTGRES_CONFIG[:collate]}' LC_CTYPE '#{POSTGRES_CONFIG[:collate]}';
SQL
    params = { '-U' => ENV['PSQL_USER'] || 'postgres' }
    params['-q'] = nil unless $VERBOSE
    puts "Creating PostgreSQL (test) database: #{POSTGRES_CONFIG[:database]}"
    sh "cat #{script.path} | #{psql} #{params.to_a.join(' ')}", :verbose => $VERBOSE
  end
  task :postgres => :postgresql

  private

  def sql_script(sql_content, name = 'sql_script')
    require 'tempfile'; script = Tempfile.new(name)
    script.puts sql_content
    yield(script) if block_given?
    script.close
    at_exit { script.unlink }
    script
  end

end
