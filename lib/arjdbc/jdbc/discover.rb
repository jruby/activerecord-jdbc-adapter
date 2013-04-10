module ArJdbc
  
  def self.discover_extensions
    if defined?(::Gem) && ::Gem.respond_to?(:find_files)
      files = ::Gem.find_files('arjdbc/discover')
    else
      files = $LOAD_PATH.map do |p|
        discover = File.join(p, 'arjdbc', 'discover.rb')
        File.exist?(discover) ? discover : nil
      end.compact
    end
    files.each do |file|
      puts "Loading AR-JDBC extension #{file}" if $DEBUG
      require file
    end
  end

  discover_extensions
  
end