
module StubHelper

  def connection_stub(spec)
    connection = mock('connection')
    (class << connection; self; end).class_eval do
      def self.alias_chained_method(*args); args; end
    end
    def connection.configure_connection; nil; end
    connection.extend spec
    connection
  end

  def connection_methods_stub
    if ArJdbc::ConnectionMethods == (class << ActiveRecord::Base; self; end)
      connection_handler = ActiveRecord::Base
    else
      connection_handler = Object.new
      connection_handler.extend ArJdbc::ConnectionMethods
    end
    connection_handler
  end
  alias_method :connection_handler_stub, :connection_methods_stub

end
