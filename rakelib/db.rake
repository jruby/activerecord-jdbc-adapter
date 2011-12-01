def have_postgres?
  if find_executable?("psql")
    if `psql -c '\\l' -U postgres 2>&1` && $?.exitstatus == 0
      true
    else
      warn "No \"postgres\" role? You might need to execute `createuser postgres -drs' first."
      false
    end
  end
end

namespace :db do
  desc "Creates the test database for MySQL."
  task :mysql do
    load 'test/db/mysql.rb' rescue nil
    t = Tempfile.new("mysql")
    t.puts <<-SQL
DROP DATABASE IF EXISTS `#{MYSQL_CONFIG[:database]}`;
CREATE DATABASE `#{MYSQL_CONFIG[:database]}` DEFAULT CHARACTER SET `utf8`;
GRANT ALL PRIVILEGES ON `#{MYSQL_CONFIG[:database]}`.* TO #{MYSQL_CONFIG[:username]}@localhost;
GRANT ALL PRIVILEGES ON `test\_%`.* TO #{MYSQL_CONFIG[:username]}@localhost;
SET PASSWORD FOR #{MYSQL_CONFIG[:username]}@localhost = PASSWORD('#{MYSQL_CONFIG[:password]}');
SQL
    t.close
    at_exit { t.unlink }
    password = ""
    password = " --password=#{ENV['MYSQL_PASS']}" if ENV['MYSQL_PASS']
    sh("cat #{t.path} | mysql -u root#{password}")
  end

  desc "Creates the test database for PostgreSQL."
  task :postgres do
    fail unless have_postgres?
    load 'test/db/postgres.rb' rescue nil
    t = Tempfile.new("psql")
    t.puts <<-SQL
DROP DATABASE IF EXISTS #{POSTGRES_CONFIG[:database]};
DROP USER IF EXISTS #{POSTGRES_CONFIG[:username]};
CREATE USER #{POSTGRES_CONFIG[:username]} CREATEDB SUPERUSER LOGIN PASSWORD '#{POSTGRES_CONFIG[:password]}';
CREATE DATABASE #{POSTGRES_CONFIG[:database]} OWNER #{POSTGRES_CONFIG[:username]};
SQL
    t.close
    at_exit { t.unlink }
    sh "cat #{t.path} | psql -U postgres"
  end
end
