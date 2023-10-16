## Setting up the environment

1. Check out the `activerecord-jdbc-adapter` repository

        cd ~/rubygems
        git clone git@github.com:eazybi/activerecord-jdbc-adapter.git

2. Go to the `activerecord-jdbc-adapter` folder and create the `.rvmrc` file

        cd ~/rubygems/activerecord-jdbc-adapter
        cat > .rvmrc <<RVMRC
        rvm jruby-9.3.7.0@activerecord_jdbc_adapter --create
        RVMRC

3. Load RVM configuration

        cd ~/rubygems/activerecord-jdbc-adapter

4. Run the `bundle` command with the specified ActiveRecord version
        AR_VERSION=6-1-stable bundle


## Building the JAR file

1. Run the `rake` task to build `adapter_java.jar` file

        rake jar

2. Copy the `adapter_java.jar` file to the eazybi repository

        cp ./lib/arjdbc/jdbc/adapter_java.jar ~/rails/eazybi/lib/arjdbc/jdbc/
