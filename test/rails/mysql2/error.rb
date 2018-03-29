module Mysql2
  class Error < Exception
    def initialize(*)
      super("error")
    end
  end
end