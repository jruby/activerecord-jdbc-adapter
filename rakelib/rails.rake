namespace :rails do
  def _adapter(n)
    case n
    when /postgres/
      'postgresql'
    else
      n
    end
  end

  def _driver(n)
    case n
    when /postgres/
      'postgres'
    else
      n
    end
  end

  def _target(n)
    case n
    when /postgres/
      'test_jdbcpostgresql'
    else
      "test_jdbc#{n}"
    end
  end

  task :test => :jar do
    raise "need a DRIVER" unless driver = ENV['DRIVER']
    raise "need location of RAILS source code" unless rails_dir = ENV['RAILS']
    rails_dir = File.join(rails_dir, '..') if rails_dir =~ /activerecord$/
    activerecord_dir = File.join(rails_dir, 'activerecord') # rails/activerecord

    ar_jdbc_dir = File.expand_path('..', File.dirname(__FILE__))

    rubylib = [ 
      "#{ar_jdbc_dir}/lib",
      "#{ar_jdbc_dir}/jdbc-#{_driver(driver)}/lib",
      "#{ar_jdbc_dir}/activerecord-jdbc#{_adapter(driver)}-adapter/lib"
    ]
    rubylib << File.expand_path('activesupport/lib', rails_dir)
    rubylib << File.expand_path('activemodel/lib', rails_dir)
    rubylib << File.expand_path(File.join(activerecord_dir, 'lib'))
    #rubylib << File.expand_path('actionpack/lib', rails_dir)

    Dir.chdir(activerecord_dir) { rake "RUBYLIB=#{rubylib.join(':')}", "#{_target(driver)}" }
  end
end
