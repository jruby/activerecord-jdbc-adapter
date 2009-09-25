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

  task :test => "java_compile" do
    driver = ENV['DRIVER']
    raise "need a DRIVER" unless driver
    activerecord = ENV['RAILS']
    raise "need location of RAILS source code" unless activerecord
    activerecord = File.join(activerecord, 'activerecord') unless activerecord =~ /activerecord$/
    ar_jdbc = File.expand_path(File.dirname(__FILE__) + '/..')
    rubylib = "#{ar_jdbc}/lib:#{ar_jdbc}/drivers/#{_driver(driver)}/lib:#{ar_jdbc}/adapters/#{_adapter(driver)}/lib"
    Dir.chdir(activerecord) do
      rake "RUBYLIB=#{rubylib}", "#{_target(driver)}"
    end
  end
end
