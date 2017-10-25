DEFAULT_RAILS_DIR = File.join('..', 'rails')
DEFAULT_ADAPTERS = %w(MySQL SQLite3 Postgres)

namespace :rails do
  namespace :test do
    task :all do
      driver = ENV['DRIVER'] || ENV['ADAPTER']
      raise "need a DRIVER (DRIVER=mysql)" unless driver
      rails_dir = _rails_dir
      ENV['ARCONFIG'] = File.join(_ar_jdbc_dir, 'test', 'rails', 'config.yml')

      Dir.chdir(File.join(rails_dir, 'activerecord')) do
        sh FileUtils::RUBY, '-S', 'rake',
           "RUBYLIB=#{_ruby_lib(rails_dir, driver)}",
           _target(driver)
      end
    end

    DEFAULT_ADAPTERS.each do |adapter|
      desc "Run Rails ActiveRecord tests with #{adapter} (JDBC)"
      task adapter.downcase do
        ENV['ADAPTER'] = adapter
        Rake::Task['rails:test:all'].invoke
      end

      namespace adapter.downcase do
        desc "Runs Rails ActiveRecord base_test.rb with #{adapter}"
        task "base_test" do
          ENV['TEST'] = "test/cases/base_test.rb"
          ENV['ADAPTER'] = adapter
          Rake::Task['rails:test:all'].invoke
        end
      end
    end

    private

    def _ar_jdbc_dir
      @ar_jdbc_dir ||= File.expand_path('..', File.dirname(__FILE__))
    end

    def _rails_dir
      rails_dir = ENV['RAILS'] || DEFAULT_RAILS_DIR
      unless File.directory? rails_dir
        raise "can't find RAILS source '#{rails_dir}' (maybe set ENV['RAILS'])"
      end
      rails_dir = File.join(rails_dir, '..') if rails_dir =~ /activerecord$/
      rails_dir
    end

    def _ruby_lib(rails_dir, driver)
      ar_jdbc_dir = _ar_jdbc_dir

      if driver =~ /postgres/i
        adapter, driver = 'postgresql', 'postgres'
      else
        adapter = driver.downcase
        driver = adapter
      end

      [File.join(ar_jdbc_dir, 'lib'),
       File.join(ar_jdbc_dir, 'test', 'rails'),
       File.join(ar_jdbc_dir, "jdbc-#{driver}", 'lib'),
       File.join(ar_jdbc_dir, "activerecord-jdbc#{adapter}-adapter", 'lib'),
       File.expand_path('activesupport/lib', rails_dir),
       File.expand_path('activemodel/lib', rails_dir),
       File.expand_path('activerecord/lib', rails_dir)
      ].join(':')
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
end
