/***** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2012-2014 Karol Bucek <self@kares.org>
 * Copyright (c) 2006-2010 Nick Sieger <nick@nicksieger.com>
 * Copyright (c) 2006-2007 Ola Bini <ola.bini@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 ***** END LICENSE BLOCK *****/

package arjdbc.jdbc;

import java.sql.Connection;
import java.sql.SQLException;
import javax.sql.DataSource;

import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;


/**
 * Interface to be implemented in Ruby for retrieving a new connection.
 *
 * @author nicksieger
 */
@SuppressWarnings("deprecation")
public interface ConnectionFactory extends JdbcConnectionFactory {

    /**
     * Retrieve a (new) connection from the factory.
     * @return a connection
     * @throws SQLException
     */
    Connection newConnection() throws SQLException;

}

class DataSourceConnectionFactoryImpl implements ConnectionFactory {

    private final DataSource dataSource;
    final String username, password; // optional

    public DataSourceConnectionFactoryImpl(final DataSource dataSource) {
        this.dataSource = dataSource;
        this.username = null; this.password = null;
    }

    public DataSourceConnectionFactoryImpl(final DataSource dataSource,
        final String username, final String password) {
        this.dataSource = dataSource;
        this.username = username; this.password = password;
    }

    @Override
    public Connection newConnection() throws SQLException {
        if ( username != null ) {
            dataSource.getConnection(username, password);
        }
        return dataSource.getConnection();
    }

    DataSource getDataSource() { return dataSource; } /* for tests */

}

class DriverConnectionFactoryImpl implements ConnectionFactory {

    private final DriverWrapper driverWrapper;
    final String url;
    final String username, password; // null allowed

    public DriverConnectionFactoryImpl(final DriverWrapper driver, final String url) {
        this.driverWrapper = driver; this.url = url;
        this.username = null; this.password = null;
    }

    public DriverConnectionFactoryImpl(final DriverWrapper driver, final String url,
        final String username, final String password) {
        this.driverWrapper = driver; this.url = url;
        this.username = username; this.password = password;
    }

    @Override
    public Connection newConnection() throws SQLException {
        return driverWrapper.connect(url, username, password);
    }

    DriverWrapper getDriverWrapper() { return driverWrapper; } /* for tests */

}

// @legacy ActiveRecord::ConnectionAdapters::JdbcDriver
class RubyConnectionFactoryImpl implements ConnectionFactory {

    private final IRubyObject driver;
    final RubyString url;
    final IRubyObject username, password; // null allowed

    private final RubyObject contextProvider;

    public RubyConnectionFactoryImpl(final IRubyObject driver, final RubyString url,
        final IRubyObject username, final IRubyObject password) {
        this.driver = driver; this.url = url;
        this.username = username; this.password = password;
        contextProvider = (RubyObject) driver;
    }

    @Override
    public Connection newConnection() throws SQLException {
        final ThreadContext context = contextProvider.getRuntime().getCurrentContext();
        final IRubyObject connection = driver.callMethod(context, "connection", new IRubyObject[] { url, username, password });
        return (Connection) connection.toJava(Connection.class);
    }

    IRubyObject getDriver() { return driver; } /* for tests */

}