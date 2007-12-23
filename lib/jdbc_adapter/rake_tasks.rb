if defined?(namespace)
  begin 
    load File.join(File.dirname(__FILE__), '..', 'tasks', 'jdbc_databases.rake')
  rescue Exception => e
  end
end
