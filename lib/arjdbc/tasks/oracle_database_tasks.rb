module ArJdbc
  module Tasks
    class OracleDatabaseTasks < JdbcDatabaseTasks

      def purge
        establish_connection(:test)
        connection.structure_drop.split(";\n\n").each { |ddl| connection.execute(ddl) }
      end

      def structure_dump(filename)
        establish_connection(configuration)
        File.open(filename, "w:utf-8") { |f| f << connection.structure_dump }
      end

      def structure_load(filename)
        establish_connection(configuration)
        IO.read(filename).split(";\n\n").each { |ddl| connection.execute(ddl) }
      end
      
    end
  end
end