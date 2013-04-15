namespace :rails do
  
  task :test do
    raise "need a DRIVER e.g. DRIVER=mysql" unless driver = ENV['DRIVER'] || ENV['ADAPTER']
    raise "need location of RAILS source code e.g. RAILS=../rails" unless rails_dir = ENV['RAILS']
    rails_dir = File.join(rails_dir, '..') if rails_dir =~ /activerecord$/
    activerecord_dir = File.join(rails_dir, 'activerecord') # rails/activerecord

    ar_jdbc_dir = File.expand_path('..', File.dirname(__FILE__))
    
    rubylib = [ 
      "#{ar_jdbc_dir}/lib",
      "#{ar_jdbc_dir}/test/rails", # just to load our rails_helper
      "#{ar_jdbc_dir}/jdbc-#{_driver(driver)}/lib",
      "#{ar_jdbc_dir}/activerecord-jdbc#{_adapter(driver)}-adapter/lib"
    ]
    rubylib << File.expand_path('activesupport/lib', rails_dir)
    rubylib << File.expand_path('activemodel/lib', rails_dir)
    rubylib << File.expand_path(File.join(activerecord_dir, 'lib'))

    Dir.chdir(activerecord_dir) do 
      rake_args = [ "RUBYLIB=#{rubylib.join(':')}", "#{_target(driver)}" ]
      ruby "-S", "rake", *rake_args # -rrails_helper
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
  
end
