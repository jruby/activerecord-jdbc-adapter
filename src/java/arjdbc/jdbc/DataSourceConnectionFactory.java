/*
 * The MIT License
 *
 * Copyright 2014 Karol Bucek.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
package arjdbc.jdbc;

import java.sql.Connection;
import java.sql.SQLException;

import javax.sql.DataSource;
import javax.naming.InitialContext;
import javax.naming.NameNotFoundException;
import javax.naming.NamingException;

import org.jruby.runtime.ThreadContext;

import static arjdbc.jdbc.RubyJdbcConnection.getConnectionNotEstablished;
import static arjdbc.jdbc.RubyJdbcConnection.wrapException;

/**
 *
 * @author kares
 */
final class DataSourceConnectionFactory implements ConnectionFactory {

    private DataSource dataSource;
    private final String lookupName;
    String username;
    String password; // optional

    public DataSourceConnectionFactory(final DataSource dataSource) {
        this.dataSource = dataSource;
        this.lookupName = null;
    }

    DataSourceConnectionFactory(final DataSource dataSource, final String lookupName) {
        this.dataSource = dataSource;
        this.lookupName = lookupName;
    }

    public void setUsername(final String username) {
        this.username = username;
    }

    public void setPassword(final String password) {
        this.password = password;
    }

    @Override
    public Connection newConnection() throws SQLException {
        // in case DS failed previously look it up again from JNDI :
        if (dataSource == null) {
            lookupDataSource();
        }
        try {
            if (username != null) {
                return dataSource.getConnection(username, password);
            }
            return dataSource.getConnection();
        } catch (SQLException e) {
            // DS failed - maybe it's no longer a valid one
            if (lookupName != null) {
                dataSource = null;
            }
            throw e;
        }
    }

    private void lookupDataSource() throws SQLException {
        try {
            dataSource = (DataSource) getInitialContext().lookup(lookupName);
        }
        catch (NamingException e) { throw new SQLException(e); }
    }

    DataSource getDataSource() { return dataSource; } /* for tests */

    // NOTE: keep it here so that RubyJdbcConnection does not force loading of javax.naming classes
    static DataSource lookupDataSource(final ThreadContext context, final String name) {
        try {
            final Object bound = getInitialContext().lookup(name);
            if ( ! ( bound instanceof DataSource ) ) {
                if ( bound == null ) throw new NameNotFoundException(); // unlikely to happen
                final String msg = "bound object at '" + name + "' is not a " + DataSource.class.getName() + " but a " + bound.getClass().getName() + "\n" + bound;
                throw wrapException(context, getConnectionNotEstablished(context.runtime), new ClassCastException(msg), msg);
            }
            return (DataSource) bound;
        }
        catch (NameNotFoundException e) {
            final String message;
            if ( name == null || name.isEmpty() ) {
                message = "unable to lookup data source - no name given, please set jndi:";
            }
            else if ( name.indexOf("env", 0) == -1 ) {
                final StringBuilder msg = new StringBuilder();
                msg.append("name: '").append(name).append("' not found, ");
                msg.append("try using full name (including env) e.g. ");
                msg.append("java:/comp/env"); // e.g. java:/comp/env/jdbc/MyDS
                if ( name.charAt(0) != '/' ) msg.append('/');
                msg.append(name);
                message = msg.toString();
            }
            else {
                message = "unable to lookup data source - name: '" + name + "' not found";
            }
            throw wrapException(context, getConnectionNotEstablished(context.runtime), e, message);
        }
        catch (NamingException e) {
            throw wrapException(context, context.runtime.getRuntimeError(), e);
        }
    }

    // NamigHelper :

    static final boolean contextCached = Boolean.getBoolean("arjdbc.jndi.context.cached");

    private static InitialContext initialContext;

    static InitialContext getInitialContext() throws NamingException {
        if ( initialContext != null ) return initialContext;
        if ( contextCached ) return initialContext = new InitialContext();
        return new InitialContext();
    }

    /**
     * Currently, the only way to bypass <code>new InitialContext()</code>
     * without the environment being passed in.
     * @param context
     * @see #getInitialContext()
     */
    static void setInitialContext(final InitialContext context) {
        DataSourceConnectionFactory.initialContext = context;
    }

}
