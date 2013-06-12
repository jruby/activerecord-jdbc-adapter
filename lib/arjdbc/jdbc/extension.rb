module ArJdbc

  # Defines an AR-JDBC extension. An extension consists of a declaration using
  # this method and an ArJdbc::XYZ module that contains implementation and
  # overrides for methods in ActiveRecord::ConnectionAdapters::AbstractAdapter.
  # When you declare your extension, you provide a block that detects when a
  # database configured to use the extension is present and loads the necessary
  # code for it. AR-JDBC will patch the code into the base JdbcAdapter by
  # extending an instance of it with your extension module.
  #
  # +name+ the name of a module to be defined under the +ArJdbc+ module.
  #
  # +block+ should be a one- or two-arity block that receives the dialect name
  # or driver class name as the first argument, and optionally the whole
  # database configuration hash as a second argument
  #
  # Example:
  #
  #   ArJdbc.extension :FRoB do |name|
  #     if name =~ /frob/i
  #       require 'arjdbc/frob' # contains ArJdbc::FRoB
  #       true
  #     end
  #   end
  #
  def self.extension(name, &block)
    if const_defined?(name)
      mod = const_get(name)
    else
      mod = const_set(name, Module.new)
    end
    (class << mod; self; end).instance_eval do
      define_method :adapter_matcher do |_name, config|
        if block.arity == 1
          block.call(_name) ? mod : false
        else
          block.call(_name, config) ? mod : false
        end
      end
    end unless mod.respond_to?(:adapter_matcher)
  end

  private
  def self.discover_extensions
    if defined?(Gem) && Gem.respond_to?(:find_files)
      files = Gem.find_files('arjdbc/discover')
    else
      files = $LOAD_PATH.map do |path|
        discover = File.join(path, 'arjdbc', 'discover.rb')
        File.exist?(discover) ? discover : nil
      end.compact
    end
    files.each do |file|
      puts "Loading AR-JDBC extension #{file}" if $DEBUG
      require file
    end
  end

end
