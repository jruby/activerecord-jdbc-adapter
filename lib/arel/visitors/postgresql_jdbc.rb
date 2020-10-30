require 'arel/visitors/compat'

class Arel::Visitors::PostgreSQL
  # AREL converts bind argument markers "?" to "$n" for PG, but JDBC wants "?".
  
  # To fix, BIND_BLOCK is overloaded. The original looks like:
  # BIND_BLOCK = proc { |i| "$#{i}" }  
  BIND_BLOCK = proc { "?" }
  private_constant :BIND_BLOCK

  def bind_block; BIND_BLOCK; end
end
