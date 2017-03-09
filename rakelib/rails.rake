DEFAULT_RAILS_DIR = File.join('..', 'rails')

namespace :rails do
  
  task :test do
    unless driver = ENV['DRIVER'] || ENV['ADAPTER']
      raise "need a DRIVER e.g. DRIVER=mysql"
    end
    rails_dir = ENV['RAILS'] || DEFAULT_RAILS_DIR
    unless File.directory? rails_dir
      raise "can't find RAILS source '#{rails_dir}' (maybe set ENV['RAILS'])"
    end
    rails_dir = File.join(rails_dir, '..') if rails_dir =~ /activerecord$/
    activerecord_dir = File.join(rails_dir, 'activerecord') # rails/activerecord

    ar_jdbc_dir = File.expand_path('..', File.dirname(__FILE__))
    
    ruby_lib = [ 
      "#{ar_jdbc_dir}/lib",
      "#{ar_jdbc_dir}/test/rails",
      "#{ar_jdbc_dir}/jdbc-#{_driver(driver)}/lib",
      "#{ar_jdbc_dir}/activerecord-jdbc#{_adapter(driver)}-adapter/lib"
    ]
    ruby_lib << File.expand_path('activesupport/lib', rails_dir)
    ruby_lib << File.expand_path('activemodel/lib', rails_dir)
    ruby_lib << File.expand_path(File.join(activerecord_dir, 'lib'))
    requires = _requires(driver) || []

    Dir.chdir(activerecord_dir) do
      ruby = FileUtils::RUBY
      rubylib = ruby_lib.join(':') # i_lib = "-I#{rubylib}"
      r_requires = requires.map { |feat| "-r#{feat}" }.join(' ')
      sh "#{ruby} -S rake RUBYLIB=#{rubylib} RUBYOPT=\"#{r_requires}\" #{_target(driver)}"
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
    requires = []
    requires << 'ubygems'
    requires << 'active_support/json' # avoid uninitialized constant BasicsTest::JSON
    case name
    when /mysql/i
      requires << 'mysql' # -rmysql - so Rails tests do not complain about Mysql
    end
    requires
  end
  
end
