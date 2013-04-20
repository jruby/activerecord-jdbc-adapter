namespace :rails do
  
  task :test do
    raise "need a DRIVER e.g. DRIVER=mysql" unless driver = ENV['DRIVER'] || ENV['ADAPTER']
    raise "need location of RAILS source code e.g. RAILS=../rails" unless rails_dir = ENV['RAILS']
    rails_dir = File.join(rails_dir, '..') if rails_dir =~ /activerecord$/
    activerecord_dir = File.join(rails_dir, 'activerecord') # rails/activerecord

    ar_jdbc_dir = File.expand_path('..', File.dirname(__FILE__))
    
    rubylib = [ 
      "#{ar_jdbc_dir}/lib",
      "#{ar_jdbc_dir}/test/rails",
      "#{ar_jdbc_dir}/jdbc-#{_driver(driver)}/lib",
      "#{ar_jdbc_dir}/activerecord-jdbc#{_adapter(driver)}-adapter/lib"
    ]
    rubylib << File.expand_path('activesupport/lib', rails_dir)
    rubylib << File.expand_path('activemodel/lib', rails_dir)
    rubylib << File.expand_path(File.join(activerecord_dir, 'lib'))
    requires = _requires(driver) || []

    Dir.chdir(activerecord_dir) do
      ruby = FileUtils::RUBY
      i_lib = "-I#{rubylib.join(':')}"
      r_requires = requires.map { |feat| "-r#{feat}" }.join(' ')
      sh "#{ruby} #{i_lib} #{r_requires} -S rake #{_target(driver)}"
    end
  end
  
  %w(MySQL SQLite3 Postgres).each do |adapter|
    desc "Run Rails' ActiveRecord tests with #{adapter} (JDBC)"
    task "test_#{adapter.downcase}" do
      ENV['ADAPTER'] = adapter; Rake::Task['rails:test'].invoke
    end
  end
  
  private
  
  def _adapter(name)
    case name
    when /postgres/i
      'postgresql'
    else
      name.downcase
    end
  end

  def _driver(name)
    case name
    when /postgres/i
      'postgres'
    else
      name.downcase
    end
  end

  def _target(name)
    case name
    when /postgres/i
      'test_jdbcpostgresql'
    else
      "test_jdbc#{name.downcase}"
    end
  end

  def _requires(name)
    case name
    when /mysql/i
      [ 'mysql' ] # -rmysql - so Rails tests do not complain about missing Mysql
    else
      nil
    end
  end
  
end
