module ArJdbc
  def self.discover_extensions
    if defined?(::Gem)
      files = Gem.find_files('arjdbc/discover')
    else
      files = $LOAD_PATH.map do |p|
        discover = File.join(p, 'arjdbc','discover.rb')
        File.exist?(p) ? discover : nil
      end.compact
    end
    files.each do |f|
      puts "Loading #{f}" if $DEBUG
      require f
    end
  end

  discover_extensions
end
