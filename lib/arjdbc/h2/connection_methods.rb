ActiveRecord::ConnectionMethods.module_eval do
  def h2_connection(config)
    config[:url] ||= "jdbc:h2:#{config[:database]}"
    config[:driver] ||= "org.h2.Driver"
    config[:adapter_spec] = ::ArJdbc::H2
    embedded_driver(config)
  end
  alias_method :jdbch2_connection, :h2_connection
end