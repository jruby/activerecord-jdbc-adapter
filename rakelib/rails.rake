namespace :rails do

  %w(MySQL SQLite3 PostgreSQL).each do |adapter|

    desc "Run Rails ActiveRecord tests with #{adapter} (JDBC)"
    task "test_#{adapter = adapter.downcase}" do
      puts "Use TESTOPTS=\"--verbose\" to pass --verbose to runners." if ARGV.include? '--verbose'

      require 'active_record/version'; ar_path = Gem.loaded_specs['activerecord'].full_gem_path
      unless File.exist? ar_test_dir = File.join(ar_path, 'test')
        raise "can not directly load Rails tests;" +
              " try setting a local repository path e.g. export RAILS=`pwd`/../rails && bundle install"
      end

      driver = "jdbc-#{adapter =~ /postgres/i ? 'postgres' : adapter}"
      adapter = 'mysql2' if adapter.eql?('mysql')

      root_dir = File.expand_path('..', File.dirname(__FILE__))
      env = {}
      env['ARCONFIG'] = File.join(root_dir, 'test/rails', 'config.yml')
      env['ARCONN'] = adapter
      env['BUNDLE_GEMFILE'] = ENV['BUNDLE_GEMFILE'] || File.join(root_dir, 'Gemfile') # use AR-JDBC's with Rails tests
      env['EXCLUDE_DIR'] = File.join(root_dir, 'test/rails/excludes', adapter) # minitest-excludes

      libs = [
          File.join(root_dir, 'lib'),
          File.join(root_dir, driver, 'lib'),
          File.join(root_dir, 'test/rails'),
          ar_test_dir
      ]

      test_files_finder = lambda do
        Dir.chdir(ar_path) do # taken from Rails' *activerecord/Rakefile* :
          ( Dir.glob("test/cases/**/*_test.rb").reject { |x| x =~ /\/adapters\// } +
            Dir.glob("test/cases/adapters/#{adapter}/**/*_test.rb") )
        end
      end

      task_stub = Class.new(Rake::TestTask) { def define; end }.new # no-op define
      test_loader_code = task_stub.run_code # :rake test-loader

      ruby_opts_string = "-I\"#{libs.join(File::PATH_SEPARATOR)}\""
      ruby_opts_string += " -C \"#{ar_path}\""
      ruby_opts_string += " -rbundler/setup"
      file_list_string = ENV["TEST"] ? FileList[ ENV["TEST"] ] : test_files_finder.call
      file_list_string = file_list_string.map { |fn| "\"#{fn}\"" }.join(' ')
      # test_loader_code = "-e \"ARGV.each{|f| require f}\"" # :direct
      option_list = ( ENV["TESTOPTS"] || ENV["TESTOPT"] || ENV["TEST_OPTS"] || '' )

      args = "#{ruby_opts_string} #{test_loader_code} #{file_list_string} #{option_list}"
      env_sh env, "#{FileUtils::RUBY} #{args}" do |ok, status|
        if !ok && status.respond_to?(:signaled?) && status.signaled?
          raise SignalException.new(status.termsig)
        elsif !ok
          fail "Command failed with status (#{status.exitstatus})"
        end
      end
    end
    task :test_mysql2 => :test_mysql

    FileUtils.module_eval do

      def env_sh(env, *cmd, &block)
        options = (Hash === cmd.last) ? cmd.pop : {}
        shell_runner = block_given? ? block : create_shell_runner(cmd)
        set_verbose_option(options)
        options[:noop] ||= Rake::FileUtilsExt.nowrite_flag
        Rake.rake_check_options options, :noop, :verbose

        cmd = env.map { |k,v| "#{k}=\"#{v}\"" }.join(' ') + ' ' + cmd.join(' ')
        Rake.rake_output_message cmd if options[:verbose]

        unless options[:noop]
          res = Kernel.system(cmd)
          status = $?
          status = Rake::PseudoStatus.new(1) if !res && status.nil?
          shell_runner.call(res, status)
        end
      end

      def env_system(env, cmd)
        Kernel.system(env.map { |k,v| "#{k}=\"#{v}\"" }.join(' ') + ' ' + cmd)
      end

    end

  end

  namespace :db do
    namespace :mysql do
      desc 'Build the MySQL test databases'
      task :build do
        config = ARTest.config['connections']['mysql2']
        %x( mysql --user=#{config['arunit']['username']} --password=#{config['arunit']['password']} -e "create DATABASE #{config['arunit']['database']} DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_unicode_ci ")
        %x( mysql --user=#{config['arunit2']['username']} --password=#{config['arunit2']['password']} -e "create DATABASE #{config['arunit2']['database']} DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_unicode_ci ")
      end

      desc 'Drop the MySQL test databases'
      task :drop do
        config = ARTest.config['connections']['mysql2']
        %x( mysqladmin --user=#{config['arunit']['username']} --password=#{config['arunit']['password']} -f drop #{config['arunit']['database']} )
        %x( mysqladmin --user=#{config['arunit2']['username']} --password=#{config['arunit2']['password']} -f drop #{config['arunit2']['database']} )
      end

      desc 'Rebuild the MySQL test databases'
      task :rebuild => [:drop, :build]
    end

    namespace :postgresql do
      desc 'Build the PostgreSQL test databases'
      task :build do
        config = ARTest.config['connections']['postgresql']
        %x( createdb -E UTF8 -T template0 #{config['arunit']['database']} )
        %x( createdb -E UTF8 -T template0 #{config['arunit2']['database']} )

        # prepare hstore
        if %x( createdb --version ).strip.gsub(/(.*)(\d\.\d\.\d)$/, "\\2") < "9.1.0"
          puts "Please prepare hstore data type. See http://www.postgresql.org/docs/current/static/hstore.html"
        end
      end

      desc 'Drop the PostgreSQL test databases'
      task :drop do
        config = ARTest.config['connections']['postgresql']
        %x( dropdb #{config['arunit']['database']} )
        %x( dropdb #{config['arunit2']['database']} )
      end

      desc 'Rebuild the PostgreSQL test databases'
      task :rebuild => [:drop, :build]
    end
  end

  # NOTE: we expect to, hopefully, not be using these anymore - delete at WILL!
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

    %w(MySQL SQLite3 Postgres).each do |adapter|
      task adapter.downcase do
        ENV['ADAPTER'] = adapter
        Rake::Task['rails:test:all'].invoke
      end

      namespace adapter.downcase do
        task "base_test" do
          ENV['TEST'] ||= 'test/cases/base_test.rb'
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
      rails_dir = ENV['RAILS'] || File.join('..', 'rails')
      unless File.directory? rails_dir
        raise "can't find RAILS source at '#{rails_dir}' (maybe set ENV['RAILS'])"
      end
      rails_dir = File.join(rails_dir, '..') if rails_dir =~ /activerecord$/
      File.expand_path(rails_dir)
    end

    def _ruby_lib(rails_dir, driver)
      ar_jdbc_dir = _ar_jdbc_dir

      if driver =~ /postgres/i
        adapter, driver = 'postgresql', 'postgres'
      else
        adapter, driver = driver.downcase, adapter
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
        'test_postgresql'
      else
        "test_jdbc#{name.downcase}"
      end
    end

  end
end
