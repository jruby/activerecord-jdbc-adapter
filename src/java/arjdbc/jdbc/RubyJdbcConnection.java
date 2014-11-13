/***** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2012-2013 Karol Bucek <self@kares.org>
 * Copyright (c) 2006-2011 Nick Sieger <nick@nicksieger.com>
 * Copyright (c) 2006-2007 Ola Bini <ola.bini@gmail.com>
 * Copyright (c) 2008-2009 Thomas E Enebo <enebo@acm.org>
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

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.io.Reader;
import java.io.StringReader;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.sql.Array;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.SQLXML;
import java.sql.Statement;
import java.sql.Date;
import java.sql.SQLFeatureNotSupportedException;
import java.sql.Savepoint;
import java.sql.Time;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.TimeZone;

import arjdbc.util.StringHelper;
import org.joda.time.DateTime;
import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyBignum;
import org.jruby.RubyBoolean;
import org.jruby.RubyClass;
import org.jruby.RubyException;
import org.jruby.RubyFixnum;
import org.jruby.RubyFloat;
import org.jruby.RubyHash;
import org.jruby.RubyIO;
import org.jruby.RubyInteger;
import org.jruby.RubyModule;
import org.jruby.RubyNumeric;
import org.jruby.RubyObject;
import org.jruby.RubyString;
import org.jruby.RubySymbol;
import org.jruby.RubyTime;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.ext.bigdecimal.RubyBigDecimal;
import org.jruby.javasupport.JavaEmbedUtils;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.Block;
import org.jruby.runtime.Helpers;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.Visibility;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.builtin.Variable;
import org.jruby.runtime.component.VariableEntry;
import org.jruby.util.ByteList;
import org.jruby.util.SafePropertyAccessor;
import org.jruby.util.TypeConverter;

import arjdbc.util.DateTimeUtils;
import arjdbc.util.ObjectSupport;
import arjdbc.util.StringCache;

import static arjdbc.util.StringHelper.newDefaultInternalString;
import static arjdbc.util.StringHelper.newUTF8String;
import static arjdbc.util.StringHelper.nonWhitespaceIndex;
import static arjdbc.util.StringHelper.readBytes;


/**
 * Most of our ActiveRecord::ConnectionAdapters::JdbcConnection implementation.
 */
public class RubyJdbcConnection extends RubyObject {

    private static final long serialVersionUID = 3803945791317576818L;

    private static final String[] TABLE_TYPE = new String[] { "TABLE" };
    private static final String[] TABLE_TYPES = new String[] { "TABLE", "VIEW", "SYNONYM" };

    private ConnectionFactory connectionFactory;
    private IRubyObject config;
    private IRubyObject adapter; // the AbstractAdapter instance we belong to
    private volatile boolean connected = true;

    private boolean lazy = false; // final once set on initialize
    private boolean jndi; // final once set on initialize
    private boolean configureConnection = true; // final once initialized

    protected RubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    private static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new RubyJdbcConnection(runtime, klass);
        }
    };

    public static RubyClass createJdbcConnectionClass(final Ruby runtime) {
        final RubyClass JdbcConnection = getConnectionAdapters(runtime).
            defineClassUnder("JdbcConnection", runtime.getObject(), ALLOCATOR);
        JdbcConnection.defineAnnotatedMethods(RubyJdbcConnection.class);
        return JdbcConnection;
    }

    public static RubyClass getJdbcConnectionClass(final Ruby runtime) {
        return getConnectionAdapters(runtime).getClass("JdbcConnection");
    }

    protected static RubyModule ActiveRecord(ThreadContext context) {
        return context.runtime.getModule("ActiveRecord");
    }

    public static RubyClass getBase(final Ruby runtime) {
        return (RubyClass) runtime.getModule("ActiveRecord").getConstantAt("Base");
    }

    /**
     * @param runtime
     * @return <code>ActiveRecord::Result</code>
     */
    protected static RubyClass getResult(final Ruby runtime) {
        return (RubyClass) runtime.getModule("ActiveRecord").getConstantAt("Result");
    }

    /**
     * @param runtime
     * @return <code>ActiveRecord::ConnectionAdapters</code>
     */
    protected static RubyModule getConnectionAdapters(final Ruby runtime) {
        return (RubyModule) runtime.getModule("ActiveRecord").getConstant("ConnectionAdapters");
    }

    /**
     * @param runtime
     * @return <code>ActiveRecord::ConnectionAdapters::IndexDefinition</code>
     */
    protected static RubyClass getIndexDefinition(final Ruby runtime) {
        return getConnectionAdapters(runtime).getClass("IndexDefinition");
    }

    /**
     * @param runtime
     * @return <code>ActiveRecord::ConnectionAdapters::ForeignKeyDefinition</code>
     * @note only since AR 4.2
     */
    protected static RubyClass getForeignKeyDefinition(final Ruby runtime) {
        return getConnectionAdapters(runtime).getClass("ForeignKeyDefinition");
    }

    /**
     * @param runtime
     * @return <code>ActiveRecord::JDBCError</code>
     */
    protected static RubyClass getJDBCError(final Ruby runtime) {
        return runtime.getModule("ActiveRecord").getClass("JDBCError");
    }

    /**
     * @param runtime
     * @return <code>ActiveRecord::ConnectionNotEstablished</code>
     */
    protected static RubyClass getConnectionNotEstablished(final Ruby runtime) {
        return runtime.getModule("ActiveRecord").getClass("ConnectionNotEstablished");
    }

    /**
     * @param runtime
     * @return <code>ActiveRecord::TransactionIsolationError</code>
     */
    protected static RubyClass getTransactionIsolationError(final Ruby runtime) {
        return (RubyClass) runtime.getModule("ActiveRecord").getConstant("TransactionIsolationError");
    }

    @JRubyMethod(name = "transaction_isolation", alias = "get_transaction_isolation")
    public IRubyObject get_transaction_isolation(final ThreadContext context) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final int level = connection.getTransactionIsolation();
                final String isolationSymbol = formatTransactionIsolationLevel(level);
                if ( isolationSymbol == null ) return context.nil;
                return context.runtime.newSymbol(isolationSymbol);
            }
        });
    }

    @JRubyMethod(name = "transaction_isolation=", alias = "set_transaction_isolation")
    public IRubyObject set_transaction_isolation(final ThreadContext context, final IRubyObject isolation) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final int level;
                if ( isolation.isNil() ) {
                    level = connection.getMetaData().getDefaultTransactionIsolation();
                }
                else {
                    level = mapTransactionIsolationLevel(isolation);
                }

                connection.setTransactionIsolation(level);

                final String isolationSymbol = formatTransactionIsolationLevel(level);
                if ( isolationSymbol == null ) return context.nil;
                return context.runtime.newSymbol(isolationSymbol);
            }
        });
    }

    public static String formatTransactionIsolationLevel(final int level) {
        if ( level == Connection.TRANSACTION_READ_UNCOMMITTED ) return "read_uncommitted"; // 1
        if ( level == Connection.TRANSACTION_READ_COMMITTED ) return "read_committed"; // 2
        if ( level == Connection.TRANSACTION_REPEATABLE_READ ) return "repeatable_read"; // 4
        if ( level == Connection.TRANSACTION_SERIALIZABLE ) return "serializable"; // 8
        if ( level == 0 ) return null;
        throw new IllegalArgumentException("unexpected transaction isolation level: " + level);
    }

    /*
      def transaction_isolation_levels
        {
          read_uncommitted: "READ UNCOMMITTED",
          read_committed:   "READ COMMITTED",
          repeatable_read:  "REPEATABLE READ",
          serializable:     "SERIALIZABLE"
        }
      end
    */

    public static int mapTransactionIsolationLevel(final IRubyObject isolation) {
        final Object isolationString;
        if ( isolation instanceof RubySymbol ) {
            isolationString = isolation.toString(); // RubySymbol.toString (interned)
        }
        else {
            isolationString = isolation.asString().toString().toLowerCase().intern();
        }

        if ( isolationString == "read_uncommitted" ) return Connection.TRANSACTION_READ_UNCOMMITTED; // 1
        if ( isolationString == "read_committed" ) return Connection.TRANSACTION_READ_COMMITTED; // 2
        if ( isolationString == "repeatable_read" ) return Connection.TRANSACTION_REPEATABLE_READ; // 4
        if ( isolationString == "serializable" ) return Connection.TRANSACTION_SERIALIZABLE; // 8

        throw new IllegalArgumentException(
                "unexpected isolation level: " + isolation + " (" + isolationString + ")"
        );
    }

    @JRubyMethod(name = "supports_transaction_isolation?", optional = 1)
    public IRubyObject supports_transaction_isolation_p(final ThreadContext context,
        final IRubyObject[] args) throws SQLException {
        final IRubyObject isolation = args.length > 0 ? args[0] : null;

        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final DatabaseMetaData metaData = connection.getMetaData();
                final boolean supported;
                if ( isolation != null && ! isolation.isNil() ) {
                    final int level = mapTransactionIsolationLevel(isolation);
                    supported = metaData.supportsTransactionIsolationLevel(level);
                }
                else {
                    final int level = metaData.getDefaultTransactionIsolation();
                    supported = level > Connection.TRANSACTION_NONE; // > 0
                }
                return context.runtime.newBoolean(supported);
            }
        });
    }

    @JRubyMethod(name = {"begin", "transaction"}, required = 1) // optional isolation argument for AR-4.0
    public IRubyObject begin(final ThreadContext context, final IRubyObject isolation) {
        try { // handleException == false so we can handle setTXIsolation
            return withConnection(context, false, new Callable<IRubyObject>() {
                public IRubyObject call(final Connection connection) throws SQLException {
                    return beginTransaction(context, connection, isolation.isNil() ? null : isolation);
                }
            });
        } catch (SQLException e) {
            return handleException(context, e);
        }
    }

    @JRubyMethod(name = {"begin", "transaction"}) // optional isolation argument for AR-4.0
    public IRubyObject begin(final ThreadContext context) {
        try { // handleException == false so we can handle setTXIsolation
            return withConnection(context, false, new Callable<IRubyObject>() {
                public IRubyObject call(final Connection connection) throws SQLException {
                    return beginTransaction(context, connection, null);
                }
            });
        } catch (SQLException e) {
            return handleException(context, e);
        }
    }

    protected IRubyObject beginTransaction(final ThreadContext context, final Connection connection,
        final IRubyObject isolation) throws SQLException {
        if ( isolation != null ) {
            setTransactionIsolation(context, connection, isolation);
        }
        if ( connection.getAutoCommit() ) connection.setAutoCommit(false);
        return context.nil;
    }

    protected final void setTransactionIsolation(final ThreadContext context, final Connection connection,
        final IRubyObject isolation) throws SQLException {
        final int level = mapTransactionIsolationLevel(isolation);
        try {
            connection.setTransactionIsolation(level);
        }
        catch (SQLException e) {
            RubyClass txError = ActiveRecord(context).getClass("TransactionIsolationError");
            if ( txError != null ) throw wrapException(context, txError, e);
            throw e; // let it roll - will be wrapped into a JDBCError (non 4.0)
        }
    }

    @JRubyMethod(name = "commit")
    public IRubyObject commit(final ThreadContext context) {
        final Connection connection = getConnection(true);
        try {
            if ( ! connection.getAutoCommit() ) {
                try {
                    connection.commit();
                    resetSavepoints(context); // if any
                    return context.runtime.newBoolean(true);
                }
                finally {
                    connection.setAutoCommit(true);
                }
            }
            return context.nil;
        }
        catch (SQLException e) {
            return handleException(context, e);
        }
    }

    @JRubyMethod(name = "rollback")
    public IRubyObject rollback(final ThreadContext context) {
        final Connection connection = getConnection(true);
        try {
            if ( ! connection.getAutoCommit() ) {
                try {
                    connection.rollback();
                    resetSavepoints(context); // if any
                    return context.runtime.getTrue();
                } finally {
                    connection.setAutoCommit(true);
                }
            }
            return context.nil;
        }
        catch (SQLException e) {
            return handleException(context, e);
        }
    }

    @JRubyMethod(name = "supports_savepoints?")
    public IRubyObject supports_savepoints_p(final ThreadContext context) throws SQLException {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final DatabaseMetaData metaData = connection.getMetaData();
                return context.runtime.newBoolean( metaData.supportsSavepoints() );
            }
        });
    }

    @JRubyMethod(name = "create_savepoint", optional = 1)
    public IRubyObject create_savepoint(final ThreadContext context, final IRubyObject[] args) {
        IRubyObject name = args.length > 0 ? args[0] : null;
        final Connection connection = getConnection(true);

        try {
            connection.setAutoCommit(false);

            final Savepoint savepoint ;
            // NOTE: this will auto-start a DB transaction even invoked outside
            // of a AR (Ruby) transaction (`transaction { ... create_savepoint }`)
            // it would be nice if AR knew about this TX although that's kind of
            // "really advanced" functionality - likely not to be implemented ...
            if ( name != null && ! name.isNil() ) {
                savepoint = connection.setSavepoint(name.toString());
            }
            else {
                savepoint = connection.setSavepoint();
                name = RubyString.newString( context.runtime,
                    Integer.toString( savepoint.getSavepointId() )
                );
            }
            getSavepoints(context).put(name, savepoint);

            return name;
        }
        catch (SQLException e) {
            return handleException(context, e);
        }
    }

    @JRubyMethod(name = "rollback_savepoint", required = 1)
    public IRubyObject rollback_savepoint(final ThreadContext context, final IRubyObject name) {
        if ( name == null || name.isNil() ) {
            throw context.runtime.newArgumentError("nil savepoint name given");
        }
        final Connection connection = getConnection(true);
        try {
            Savepoint savepoint = getSavepoints(context).get(name);
            if ( savepoint == null ) {
                throw context.runtime.newRuntimeError("could not rollback savepoint: '" + name + "' (not set)");
            }
            connection.rollback(savepoint);
            return context.nil;
        }
        catch (SQLException e) {
            return handleException(context, e);
        }
    }

    @JRubyMethod(name = "release_savepoint", required = 1)
    public IRubyObject release_savepoint(final ThreadContext context, final IRubyObject name) {
        Ruby runtime = context.runtime;

        if ( name == null || name.isNil() ) throw runtime.newArgumentError("nil savepoint name given");

        try {
            Object savepoint = getSavepoints(context).remove(name);

            if (savepoint == null) {
                RubyClass invalidStatement = ActiveRecord(context).getClass("StatementInvalid");
                throw runtime.newRaiseException(invalidStatement, "could not release savepoint: '" + name + "' (not set)");
            }

            // NOTE: RubyHash.remove does not convert to Java as get does :
            if (!( savepoint instanceof Savepoint )) {
                savepoint = ((IRubyObject) savepoint).toJava(Savepoint.class);
            }

            getConnection(true).releaseSavepoint((Savepoint) savepoint);
            return runtime.getNil();
        } catch (SQLException e) {
            return handleException(context, e);
        }
    }

    @SuppressWarnings("unchecked")
    protected Map<IRubyObject, Savepoint> getSavepoints(final ThreadContext context) {
        if ( hasInstanceVariable("@savepoints") ) {
            IRubyObject savepoints = getInstanceVariable("@savepoints");
            return (Map<IRubyObject, Savepoint>) savepoints.toJava(Map.class);
        }
        else { // not using a RubyHash to preserve order on Ruby 1.8 as well :
            Map<IRubyObject, Savepoint> savepoints = new LinkedHashMap<IRubyObject, Savepoint>(4);
            setInstanceVariable("@savepoints", convertJavaToRuby(savepoints));
            return savepoints;
        }
    }

    protected boolean resetSavepoints(final ThreadContext context) {
        if ( hasInstanceVariable("@savepoints") ) {
            removeInstanceVariable("@savepoints");
            return true;
        }
        return false;
    }

    @Deprecated // second argument is now mandatory - only kept for compatibility
    @JRubyMethod(required = 1)
    public final IRubyObject initialize(final ThreadContext context, final IRubyObject config) {
        doInitialize(context, config, context.nil);
        return this;
    }

    @JRubyMethod(required = 2)
    public final IRubyObject initialize(final ThreadContext context, final IRubyObject config, final IRubyObject adapter) {
        doInitialize(context, config, adapter);
        return this;
    }

    protected void doInitialize(final ThreadContext context, final IRubyObject config, final IRubyObject adapter) {
        this.config = config; this.adapter = adapter;

        this.jndi = setupConnectionFactory(context);
        this.lazy = jndi; // JNDIs are lazy by default otherwise eager
        try {
            initConnection(context);
        }
        catch (SQLException e) {
            String message = e.getMessage();
            if ( message == null ) message = e.getSQLState();
            throw wrapException(context, e, message);
        }

        IRubyObject value = getConfigValue(context, "configure_connection");
        if ( value == context.nil ) this.configureConnection = true;
        else {
            this.configureConnection = value != context.runtime.getFalse();
        }
    }

    @JRubyMethod(name = "adapter")
    public IRubyObject adapter(final ThreadContext context) {
        final IRubyObject adapter = getAdapter();
        return adapter == null ? context.nil : adapter;
    }

    @JRubyMethod(name = "connection_factory")
    public IRubyObject connection_factory() {
        return convertJavaToRuby( getConnectionFactory() );
    }

    @JRubyMethod(name = "connection_factory=", required = 1)
    public IRubyObject set_connection_factory(final IRubyObject factory) {
        setConnectionFactory( (ConnectionFactory) factory.toJava(ConnectionFactory.class) );
        return factory;
    }

    /**
     * Called during <code>initialize</code> after the connection factory
     * has been set to check if we can connect and/or perform any initialization
     * necessary.
     * <br/>
     * NOTE: connection has not been configured at this point,
     * nor should we retry - we're creating a brand new JDBC connection
     *
     * @param context
     * @return connection
     */
    @Deprecated
    @JRubyMethod(name = "init_connection")
    public synchronized IRubyObject init_connection(final ThreadContext context) {
        try {
            return initConnection(context);
        }
        catch (SQLException e) {
            return handleException(context, e); // throws
        }
    }

    private IRubyObject initConnection(final ThreadContext context) throws SQLException {
        final IRubyObject adapter = getAdapter(); // self.adapter
        if ( adapter == null || adapter == context.nil ) {
            warn(context, "adapter not set, please pass adapter on JdbcConnection#initialize(config, adapter)");
        }

        if ( ! lazy ) setConnection( newConnection() );

        return context.nil;
    }

    private void configureConnection() {
        if ( ! configureConnection ) return; // return false;

        final IRubyObject adapter = getAdapter(); // self.adapter
        if ( adapter != null && ! adapter.isNil() ) {
            if ( adapter.respondsTo("configure_connection") ) {
                final ThreadContext context = getRuntime().getCurrentContext();
                adapter.callMethod(context, "configure_connection");
            }
        }
    }

    @JRubyMethod(name = "configure_connection")
    public IRubyObject configure_connection(final ThreadContext context) {
        if ( ! lazy || getConnectionImpl() != null ) configureConnection();
        return context.nil;
    }

    @JRubyMethod(name = "jdbc_connection", alias = "connection")
    public final IRubyObject connection(final ThreadContext context) {
        return convertJavaToRuby( connectionImpl(context) );
    }

    @JRubyMethod(name = "jdbc_connection", alias = "connection", required = 1)
    public final IRubyObject connection(final ThreadContext context, final IRubyObject unwrap) {
        if ( unwrap.isNil() || unwrap == context.runtime.getFalse() ) {
            return connection(context);
        }
        Connection connection = connectionImpl(context);
        try {
            if ( connection.isWrapperFor(Connection.class) ) {
                return convertJavaToRuby( connection.unwrap(Connection.class) );
            }
        }
        catch (AbstractMethodError e) {
            debugStackTrace(context, e);
            warn(context, "driver/pool connection does not support unwrapping: " + e);
        }
        catch (SQLException e) {
            debugStackTrace(context, e);
            warn(context, "driver/pool connection does not support unwrapping: " + e);
        }
        return convertJavaToRuby( connection );
    }

    private Connection connectionImpl(final ThreadContext context) {
        Connection connection = getConnection(false);
        if ( connection == null ) {
            synchronized (this) {
                connection = getConnection(false);
                if ( connection == null ) {
                    reconnect(context);
                    connection = getConnection(false);
                }
            }
        }
        return connection;
    }

    @JRubyMethod(name = "active?", alias = "valid?")
    public RubyBoolean active_p(final ThreadContext context) {
        if ( ! connected ) return context.runtime.getFalse();
        if ( isJndi() ) {
            // for JNDI the data-source / pool is supposed to
            // manage connections for us thus no valid check!
            boolean active = getConnectionFactory() != null;
            return context.runtime.newBoolean( active );
        }
        final Connection connection = getConnection();
        if ( connection == null ) return context.runtime.getFalse(); // unlikely
        return context.runtime.newBoolean( isConnectionValid(context, connection) );
    }

    @JRubyMethod(name = "disconnect!")
    public synchronized IRubyObject disconnect(final ThreadContext context) {
        setConnection(null); connected = false;
        return context.nil;
    }

    @JRubyMethod(name = "reconnect!")
    public synchronized IRubyObject reconnect(final ThreadContext context) {
        try {
            connectImpl( ! lazy ); connected = true;
        }
        catch (SQLException e) {
            debugStackTrace(context, e);
            handleException(context, e);
        }
        return context.nil;
    }

    private void connectImpl(final boolean forceConnection) throws SQLException {
        setConnection( forceConnection ? newConnection() : null );
        if ( forceConnection ) configureConnection();
    }

    @JRubyMethod(name = { "open?" /* "conn?" */ })
    public IRubyObject open_p(final ThreadContext context) {
        final Connection connection = getConnection(false);

        if (connection == null) return context.runtime.getFalse();

        try {
            // NOTE: isClosed method generally cannot be called to determine
            // whether a connection to a database is valid or invalid ...
            return context.runtime.newBoolean(!connection.isClosed());
        } catch (SQLException e) {
            return handleException(context, e);
        }
    }

    @JRubyMethod(name = "close")
    public IRubyObject close(final ThreadContext context) {
        final Connection connection = getConnection(false);

        if (connection == null) return context.runtime.getFalse();

        try {
            if (connection.isClosed()) return context.runtime.getFalse();

            setConnection(null); // does connection.close();
        } catch (Exception e) {
            debugStackTrace(context, e);
            return context.nil;
        }

        return context.runtime.getTrue();
    }

    @JRubyMethod(name = "database_name")
    public IRubyObject database_name(final ThreadContext context) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                String name = connection.getCatalog();
                if ( name == null ) {
                    name = connection.getMetaData().getUserName();
                    if ( name == null ) return context.nil;
                }
                return context.runtime.newString(name);
            }
        });
    }

    @JRubyMethod(name = "execute", required = 1)
    public IRubyObject execute(final ThreadContext context, final IRubyObject sql) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                Statement statement = null;
                final String query = sql.convertToString().getUnicodeValue();

                try {
                    statement = createStatement(context, connection);

                    // For DBs that do support multiple statements, lets return the last result set
                    // to be consistent with AR
                    boolean hasResultSet = doExecute(statement, query);
                    int updateCount = statement.getUpdateCount();

                    ColumnData[] columns = null;
                    IRubyObject result = null;
                    ResultSet resultSet = null;

                    while (hasResultSet || updateCount != -1) {

                        if (hasResultSet) {
                            resultSet = statement.getResultSet();

                            // Unfortunately the result set gets closed when getMoreResults()
                            // is called, so we have to process the result sets as we get them
                            // this shouldn't be an issue in most cases since we're only getting 1 result set anyways
                            columns = extractColumns(context.runtime, connection, resultSet, false);
                            result = mapToResult(context, context.runtime, connection, resultSet, columns);
                        } else {
                            resultSet = null;
                        }

                        // Check to see if there is another result set
                        hasResultSet = statement.getMoreResults();
                        updateCount = statement.getUpdateCount();
                    }

                    // Need to check resultSet instead of result because result
                    // may have been populated in a previous iteration of the loop
                    if (resultSet == null) {
                        return context.runtime.newEmptyArray();
                    } else {
                        return result;
                    }
                } catch (final SQLException e) {
                    debugErrorSQL(context, query);
                    throw e;
                } finally {
                    close(statement);
                }
            }
        });
    }

    protected Statement createStatement(final ThreadContext context, final Connection connection)
        throws SQLException {
        final Statement statement = connection.createStatement();
        IRubyObject statementEscapeProcessing = getConfigValue(context, "statement_escape_processing");
        // NOTE: disable (driver) escape processing by default, it's not really
        // needed for AR statements ... if users need it they might configure :
        if ( statementEscapeProcessing.isNil() ) {
            statement.setEscapeProcessing(false);
        }
        else {
            statement.setEscapeProcessing(statementEscapeProcessing.isTrue());
        }
        return statement;
    }

    /**
     * Execute a query using the given statement.
     * @param statement
     * @param query
     * @return true if the first result is a <code>ResultSet</code>;
     *         false if it is an update count or there are no results
     * @throws SQLException
     */
    protected boolean doExecute(final Statement statement, final String query) throws SQLException {
        return statement.execute(query);
    }

    @JRubyMethod(name = "execute_insert", required = 1)
    public IRubyObject execute_insert(final ThreadContext context, final IRubyObject sql)
        throws SQLException {
        final String query = sql.convertToString().getUnicodeValue();
        return executeUpdate(context, query, true);
    }

    @JRubyMethod(name = "execute_insert", required = 2)
    public IRubyObject execute_insert(final ThreadContext context,
        final IRubyObject sql, final IRubyObject binds) throws SQLException {
        final String query = sql.convertToString().getUnicodeValue();
        if ( binds == null || binds.isNil() ) { // no prepared statements
            return executeUpdate(context, query, true);
        }
        else { // we allow prepared statements with empty binds parameters
            return executePreparedUpdate(context, query, (RubyArray) binds, true);
        }
    }

    /**
     * Executes an UPDATE (DELETE) SQL statement.
     * @param context
     * @param sql
     * @return affected row count
     * @throws SQLException
     */
    @JRubyMethod(name = {"execute_update", "execute_delete"}, required = 1)
    public IRubyObject execute_update(final ThreadContext context, final IRubyObject sql)
        throws SQLException {
        final String query = sql.convertToString().getUnicodeValue();
        return executeUpdate(context, query, false);
    }

    /**
     * Executes an UPDATE (DELETE) SQL (prepared - if binds provided) statement.
     * @param context
     * @param sql
     * @return affected row count
     * @throws SQLException
     *
     * @see #execute_update(ThreadContext, IRubyObject)
     */
    @JRubyMethod(name = {"execute_update", "execute_delete"}, required = 2)
    public IRubyObject execute_update(final ThreadContext context,
        final IRubyObject sql, final IRubyObject binds) throws SQLException {

        final String query = sql.convertToString().getUnicodeValue();
        if ( binds == null || binds.isNil() ) { // no prepared statements
            return executeUpdate(context, query, false);
        }
        else { // we allow prepared statements with empty binds parameters
            return executePreparedUpdate(context, query, (RubyArray) binds, false);
        }
    }

    @JRubyMethod(name = {"execute_prepared_update"}, required = 2)
    public IRubyObject execute_prepared_update(final ThreadContext context,
        final IRubyObject sql, final IRubyObject binds) throws SQLException {

        final String query = sql.convertToString().getUnicodeValue();
        return executePreparedUpdate(context, query, (RubyArray) binds, false);
    }

    /**
     * @param context
     * @param query
     * @param returnGeneratedKeys
     * @return row count or generated keys
     *
     * @see #execute_insert(ThreadContext, IRubyObject)
     * @see #execute_update(ThreadContext, IRubyObject)
     */
    protected IRubyObject executeUpdate(final ThreadContext context, final String query,
        final boolean returnGeneratedKeys) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                Statement statement = null;
                try {
                    statement = createStatement(context, connection);
                    if ( returnGeneratedKeys ) {
                        statement.executeUpdate(query, Statement.RETURN_GENERATED_KEYS);
                        IRubyObject keys = mapGeneratedKeys(context.runtime, connection, statement);
                        return keys == null ? context.nil : keys;
                    }
                    else {
                        final int rowCount = statement.executeUpdate(query);
                        return context.runtime.newFixnum(rowCount);
                    }
                }
                catch (final SQLException e) {
                    debugErrorSQL(context, query);
                    throw e;
                }
                finally { close(statement); }
            }
        });
    }

    private IRubyObject executePreparedUpdate(final ThreadContext context, final String query,
        final RubyArray binds, final boolean returnGeneratedKeys) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                PreparedStatement statement = null;
                try {
                    if ( returnGeneratedKeys ) {
                        statement = connection.prepareStatement(query, Statement.RETURN_GENERATED_KEYS);
                        setStatementParameters(context, connection, statement, binds);
                        statement.executeUpdate();
                        IRubyObject keys = mapGeneratedKeys(context.runtime, connection, statement);
                        return keys == null ? context.nil : keys;
                    }
                    else {
                        statement = connection.prepareStatement(query);
                        setStatementParameters(context, connection, statement, binds);
                        final int rowCount = statement.executeUpdate();
                        return context.runtime.newFixnum(rowCount);
                    }
                }
                catch (final SQLException e) {
                    debugErrorSQL(context, query);
                    throw e;
                }
                finally { close(statement); }
            }
        });
    }

    /**
     * This is the same as execute_query but it will return a list of hashes.
     *
     * @see RubyJdbcConnection#execute_query(ThreadContext, IRubyObject[])
     * @param context which context this method is executing on.
     * @param args arguments being supplied to this method.
     * @param block (optional) block to yield row values (Hash(name: value))
     * @return List of Hash(name: value) unless block is given.
     * @throws SQLException when a database error occurs<
     */
    @JRubyMethod(required = 1, optional = 2)
    public IRubyObject execute_query_raw(final ThreadContext context,
        final IRubyObject[] args, final Block block) throws SQLException {
        final String query = args[0].convertToString().getUnicodeValue(); // sql
        final RubyArray binds;
        final int maxRows;

        // args: (sql), (sql, max_rows), (sql, binds), (sql, max_rows, binds)
        switch (args.length) {
            case 2:
                if (args[1] instanceof RubyNumeric) { // (sql, max_rows)
                    maxRows = RubyNumeric.fix2int(args[1]);
                    binds = null;
                } else {                              // (sql, binds)
                    maxRows = 0;
                    binds = (RubyArray) TypeConverter.checkArrayType(args[1]);
                }
                break;
            case 3:                                   // (sql, max_rows, binds)
                maxRows = RubyNumeric.fix2int(args[1]);
                binds = (RubyArray) TypeConverter.checkArrayType(args[2]);
                break;
            default:                                  // (sql) 1-arg
                maxRows = 0;
                binds = null;
                break;
        }

        return doExecuteQueryRaw(context, query, maxRows, block, binds);
    }

    private IRubyObject doExecuteQueryRaw(final ThreadContext context,
        final String query, final int maxRows, final Block block, final RubyArray binds) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                Statement statement = null; boolean hasResult;
                try {
                    if ( binds == null || binds.isEmpty()) { // plain statement
                        statement = createStatement(context, connection);
                        statement.setMaxRows(maxRows); // zero means there is no limit
                        hasResult = statement.execute(query);
                    }
                    else {
                        final PreparedStatement prepStatement;
                        statement = prepStatement = connection.prepareStatement(query);
                        statement.setMaxRows(maxRows); // zero means there is no limit
                        setStatementParameters(context, connection, prepStatement, binds);
                        hasResult = prepStatement.execute();
                    }

                    if (block.isGiven()) {
                        if (hasResult) {
                            // yield(id1, name1) ... row 1 result data
                            // yield(id2, name2) ... row 2 result data
                            return yieldResultRows(context, connection, statement.getResultSet(), block);
                        }
                        return context.nil;
                    }
                    if (hasResult) {
                        return mapToRawResult(context, connection, statement.getResultSet(), false);
                    }
                    return context.runtime.newEmptyArray();
                }
                catch (final SQLException e) {
                    debugErrorSQL(context, query);
                    throw e;
                }
                finally {
                    close(statement);
                }
            }
        });
    }

    /**
     * Executes a query and returns the (AR) result.  There are three parameters:
     * <ul>
     *     <li>sql - String of sql</li>
     *     <li>max_rows - Integer of how many rows to return</li>
     *     <li>binds - Array of bindings for a prepared statement</li>
     * </ul>
     *
     * In true Ruby fashion if there are only two arguments then the last argument
     * may be either max_rows or binds.  Note: If you want to force the query to be
     * done using a prepared statement then you must provide an empty array to binds.
     *
     * @param context which context this method is executing on.
     * @param args arguments being supplied to this method.
     * @return a Ruby <code>ActiveRecord::Result</code> instance
     * @throws SQLException when a database error occurs
     *
     */
    @JRubyMethod(required = 1, optional = 2)
    public IRubyObject execute_query(final ThreadContext context, final IRubyObject[] args) throws SQLException {
        final String query = args[0].convertToString().getUnicodeValue(); // sql
        final RubyArray binds;
        final int maxRows;

        // args: (sql), (sql, max_rows), (sql, binds), (sql, max_rows, binds)
        switch (args.length) {
            case 2:
                if (args[1] instanceof RubyNumeric) { // (sql, max_rows)
                    maxRows = RubyNumeric.fix2int(args[1]);
                    binds = null;
                } else {                              // (sql, binds)
                    maxRows = 0;
                    binds = (RubyArray) TypeConverter.checkArrayType(args[1]);
                }
                break;
            case 3:                                   // (sql, max_rows, binds)
                maxRows = RubyNumeric.fix2int(args[1]);
                binds = (RubyArray) TypeConverter.checkArrayType(args[2]);
                break;
            default:                                  // (sql) 1-arg
                maxRows = 0;
                binds = null;
                break;
        }

        if (binds != null) { // prepared statement
            return executePreparedQuery(context, query, binds, maxRows);
        } else {
            return executeQuery(context, query, maxRows);
        }
    }

    @JRubyMethod(name = "execute_prepared_query")
    public IRubyObject execute_prepared_query(final ThreadContext context,
                                              final IRubyObject sql, final IRubyObject binds) throws SQLException {
        final String query = sql.convertToString().getUnicodeValue();

        if (binds == null || !(binds instanceof RubyArray)) {
            throw context.runtime.newArgumentError("binds exptected to an instance of Array");
        }

        return executePreparedQuery(context, query, (RubyArray) binds, 0);
    }

    /**
     *
     * @param context
     * @param query
     * @param maxRows
     * @return AR (mapped) query result
     *
     */
    protected IRubyObject executeQuery(final ThreadContext context, final String query, final int maxRows) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                Statement statement = null;
                ResultSet resultSet = null;

                try {
                    statement = createStatement(context, connection);
                    statement.setMaxRows(maxRows); // zero means there is no limit
                    resultSet = statement.executeQuery(query);
                    return mapQueryResult(context, connection, resultSet);
                } catch (final SQLException e) {
                    debugErrorSQL(context, query);
                    throw e;
                } finally {
                    close(resultSet);
                    close(statement);
                }
            }
        });
    }

    // Called from exec_query in abstract/database_statements
    @JRubyMethod(required = 3)
    public IRubyObject execute_prepared(final ThreadContext context, final IRubyObject sql,
        final IRubyObject binds, final IRubyObject cachedStatement) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final boolean cached = !(cachedStatement == null || cachedStatement.isNil());
                final String query = sql.convertToString().getUnicodeValue();
                PreparedStatement statement = null;

                try {
                    if (cached) {
                        statement = (PreparedStatement) JavaEmbedUtils.rubyToJava(cachedStatement);
                    } else {
                        statement = connection.prepareStatement(query);
                    }

                    setStatementParameters(context, connection, statement, (RubyArray) binds);
                    boolean hasResultSet = statement.execute();

                    if (hasResultSet) {
                        ResultSet resultSet = statement.getResultSet();
                        ColumnData[] columns = extractColumns(context.runtime, connection, resultSet, false);

                        IRubyObject results = mapToResult(context, context.runtime, connection, resultSet, columns);

                        if (cached) {
                            // Make sure we free the result set if we are caching the statement
                            // It gets closed automatically when the statement is closed if we aren't caching
                            resultSet.close();
                        }

                        return results;
                    } else {
                        return context.runtime.newEmptyArray();
                    }
                } catch (final SQLException e) {
                    debugErrorSQL(context, query);
                    throw e;
                } finally {
                    if ( cached ) {
                        statement.clearParameters();
                    } else {
                        close(statement);
                    }
                }
            }
        });
    }

    protected IRubyObject executePreparedQuery(final ThreadContext context, final String query,
        final RubyArray binds, final int maxRows) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                PreparedStatement statement = null; ResultSet resultSet = null;
                try {
                    statement = connection.prepareStatement(query);
                    statement.setMaxRows(maxRows); // zero means there is no limit
                    setStatementParameters(context, connection, statement, binds);
                    resultSet = statement.executeQuery();
                    return mapQueryResult(context, connection, resultSet);
                }
                catch (final SQLException e) {
                    debugErrorSQL(context, query);
                    throw e;
                }
                finally { close(resultSet); close(statement); }
            }
        });
    }

    private IRubyObject mapQueryResult(final ThreadContext context,
        final Connection connection, final ResultSet resultSet) throws SQLException {
        final ColumnData[] columns = extractColumns(context, connection, resultSet, false);
        return mapToResult(context, context.runtime, connection, resultSet, columns);
    }

    /**
     * @deprecated please do not use this method
     */
    @Deprecated // only used by Oracle adapter - also it's really a bad idea
    @JRubyMethod(name = "execute_id_insert", required = 2)
    public IRubyObject execute_id_insert(final ThreadContext context,
        final IRubyObject sql, final IRubyObject id) throws SQLException {
        final Ruby runtime = context.runtime;

        callMethod("warn", RubyString.newUnicodeString(runtime, "DEPRECATED: execute_id_insert(sql, id) will be removed"));

        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                PreparedStatement statement = null;
                final String insertSQL = sql.convertToString().getUnicodeValue();
                try {
                    statement = connection.prepareStatement(insertSQL);
                    statement.setLong(1, RubyNumeric.fix2long(id));
                    statement.executeUpdate();
                }
                catch (final SQLException e) {
                    debugErrorSQL(context, insertSQL);
                    throw e;
                }
                finally { close(statement); }
                return id;
            }
        });
    }

    @JRubyMethod(name = "supported_data_types")
    public IRubyObject supported_data_types(final ThreadContext context) throws SQLException {
        final Connection connection = getConnection(true);
        final ResultSet typeDesc = connection.getMetaData().getTypeInfo();
        final IRubyObject types;
        try {
            types = mapToRawResult(context, connection, typeDesc, true);
        }
        finally { close(typeDesc); }

        return types;
    }

    @JRubyMethod(name = "primary_keys", required = 1)
    public IRubyObject primary_keys(ThreadContext context, IRubyObject tableName) throws SQLException {
        @SuppressWarnings("unchecked")
        List<IRubyObject> primaryKeys = (List) primaryKeys(context, tableName.toString());
        return context.runtime.newArray(primaryKeys);
    }

    protected static final int PRIMARY_KEYS_COLUMN_NAME = 4;

    @Deprecated // NOTE: this should go private
    protected final List<RubyString> primaryKeys(final ThreadContext context, final String tableName) {
        return withConnection(context, new Callable<List<RubyString>>() {
            public List<RubyString> call(final Connection connection) throws SQLException {
                final String _tableName = caseConvertIdentifierForJdbc(connection, tableName);
                final TableName table = extractTableName(connection, null, null, _tableName);
                return primaryKeys(context, connection, table);
            }
        });
    }

    protected List<RubyString> primaryKeys(final ThreadContext context,
        final Connection connection, final TableName table) throws SQLException {
        final DatabaseMetaData metaData = connection.getMetaData();
        ResultSet resultSet = null;
        final List<RubyString> keyNames = new ArrayList<RubyString>();
        try {
            resultSet = metaData.getPrimaryKeys(table.catalog, table.schema, table.name);
            final Ruby runtime = context.runtime;
            while ( resultSet.next() ) {
                String columnName = resultSet.getString(PRIMARY_KEYS_COLUMN_NAME);
                columnName = caseConvertIdentifierForRails(connection, columnName);
                keyNames.add( RubyString.newUnicodeString(runtime, columnName) );
            }
        }
        finally { close(resultSet); }
        return keyNames;
    }

    @Deprecated //@JRubyMethod(name = "tables")
    public IRubyObject tables(ThreadContext context) {
        return tables(context, null, null, null, TABLE_TYPE);
    }

    @Deprecated //@JRubyMethod(name = "tables")
    public IRubyObject tables(ThreadContext context, IRubyObject catalog) {
        return tables(context, toStringOrNull(catalog), null, null, TABLE_TYPE);
    }

    @Deprecated //@JRubyMethod(name = "tables")
    public IRubyObject tables(ThreadContext context, IRubyObject catalog, IRubyObject schemaPattern) {
        return tables(context, toStringOrNull(catalog), toStringOrNull(schemaPattern), null, TABLE_TYPE);
    }

    @Deprecated //@JRubyMethod(name = "tables")
    public IRubyObject tables(ThreadContext context, IRubyObject catalog, IRubyObject schemaPattern, IRubyObject tablePattern) {
        return tables(context, toStringOrNull(catalog), toStringOrNull(schemaPattern), toStringOrNull(tablePattern), TABLE_TYPE);
    }

    @JRubyMethod(name = "tables", required = 0, optional = 4)
    public IRubyObject tables(final ThreadContext context, final IRubyObject[] args) {
        switch ( args.length ) {
            case 0: // ()
                return tables(context, null, null, null, TABLE_TYPE);
            case 1: // (catalog)
                return tables(context, toStringOrNull(args[0]), null, null, TABLE_TYPE);
            case 2: // (catalog, schemaPattern)
                return tables(context, toStringOrNull(args[0]), toStringOrNull(args[1]), null, TABLE_TYPE);
            case 3: // (catalog, schemaPattern, tablePattern)
                return tables(context, toStringOrNull(args[0]), toStringOrNull(args[1]), toStringOrNull(args[2]), TABLE_TYPE);
        }
        return tables(context, toStringOrNull(args[0]), toStringOrNull(args[1]), toStringOrNull(args[2]), getTypes(args[3]));
    }

    protected IRubyObject tables(final ThreadContext context,
        final String catalog, final String schemaPattern, final String tablePattern, final String[] types) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                return matchTables(context.runtime, connection, catalog, schemaPattern, tablePattern, types, false);
            }
        });
    }

    protected String[] getTableTypes() {
        return TABLE_TYPES;
    }

    @JRubyMethod(name = "table_exists?")
    public IRubyObject table_exists_p(final ThreadContext context, IRubyObject table) {
        if ( table.isNil() ) {
            throw context.runtime.newArgumentError("nil table name");
        }
        final String tableName = table.toString();

        return tableExists(context, null, tableName);
    }

    @JRubyMethod(name = "table_exists?")
    public IRubyObject table_exists_p(final ThreadContext context, IRubyObject table, IRubyObject schema) {
        if ( table.isNil() ) {
            throw context.runtime.newArgumentError("nil table name");
        }
        final String tableName = table.toString();
        final String defaultSchema = schema.isNil() ? null : schema.toString();

        return tableExists(context, defaultSchema, tableName);
    }

    protected IRubyObject tableExists(final ThreadContext context,
        final String defaultSchema, final String tableName) {
        final Ruby runtime = context.runtime;
        return withConnection(context, new Callable<RubyBoolean>() {
            public RubyBoolean call(final Connection connection) throws SQLException {
                final TableName components = extractTableName(connection, null, defaultSchema, tableName);
                return runtime.newBoolean( tableExists(runtime, connection, components) );
            }
        });
    }

    @JRubyMethod(name = {"columns", "columns_internal"}, required = 1, optional = 2)
    public IRubyObject columns_internal(final ThreadContext context, final IRubyObject[] args)
        throws SQLException {
        return withConnection(context, new Callable<RubyArray>() {
            public RubyArray call(final Connection connection) throws SQLException {
                ResultSet columns = null;
                try {
                    final String tableName = args[0].toString();
                    // optionals (NOTE: catalog argumnet was never used before 1.3.0) :
                    final String catalog = args.length > 1 ? toStringOrNull(args[1]) : null;
                    final String defaultSchema = args.length > 2 ? toStringOrNull(args[2]) : null;

                    final TableName components;
                    components = extractTableName(connection, catalog, defaultSchema, tableName);

                    if ( ! tableExists(context.runtime, connection, components) ) {
                        throw new SQLException("table: " + tableName + " does not exist");
                    }

                    final DatabaseMetaData metaData = connection.getMetaData();
                    columns = metaData.getColumns(components.catalog, components.schema, components.name, null);
                    return mapColumnsResult(context, metaData, components, columns);
                }
                finally {
                    close(columns);
                }
            }
        });
    }

    @JRubyMethod(name = "indexes")
    public IRubyObject indexes(final ThreadContext context, IRubyObject tableName, IRubyObject name) {
        return indexes(context, toStringOrNull(tableName), toStringOrNull(name), null);
    }

    @JRubyMethod(name = "indexes")
    public IRubyObject indexes(final ThreadContext context, IRubyObject tableName, IRubyObject name, IRubyObject schemaName) {
        return indexes(context, toStringOrNull(tableName), toStringOrNull(name), toStringOrNull(schemaName));
    }

    // NOTE: metaData.getIndexInfo row mappings :
    protected static final int INDEX_INFO_TABLE_NAME = 3;
    protected static final int INDEX_INFO_NON_UNIQUE = 4;
    protected static final int INDEX_INFO_NAME = 6;
    protected static final int INDEX_INFO_COLUMN_NAME = 9;

    /**
     * Default JDBC introspection for index metadata on the JdbcConnection.
     *
     * JDBC index metadata is denormalized (multiple rows may be returned for
     * one index, one row per column in the index), so a simple block-based
     * filter like that used for tables doesn't really work here.  Callers
     * should filter the return from this method instead.
     */
    protected IRubyObject indexes(final ThreadContext context, final String tableName, final String name, final String schemaName) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final Ruby runtime = context.runtime;
                final RubyClass IndexDefinition = getIndexDefinition(context);

                String _tableName = caseConvertIdentifierForJdbc(connection, tableName);
                String _schemaName = caseConvertIdentifierForJdbc(connection, schemaName);
                final TableName table = extractTableName(connection, null, _schemaName, _tableName);

                final List<RubyString> primaryKeys = primaryKeys(context, connection, table);

                ResultSet indexInfoSet = null;
                final List<IRubyObject> indexes = new ArrayList<IRubyObject>();
                try {
                    final DatabaseMetaData metaData = connection.getMetaData();
                    indexInfoSet = metaData.getIndexInfo(table.catalog, table.schema, table.name, false, true);
                    String currentIndex = null;

                    while ( indexInfoSet.next() ) {
                        String indexName = indexInfoSet.getString(INDEX_INFO_NAME);
                        if ( indexName == null ) continue;
                        indexName = caseConvertIdentifierForRails(metaData, indexName);

                        final String columnName = indexInfoSet.getString(INDEX_INFO_COLUMN_NAME);
                        final RubyString rubyColumnName = RubyString.newUnicodeString(
                                runtime, caseConvertIdentifierForRails(metaData, columnName)
                        );
                        if ( primaryKeys.contains(rubyColumnName) ) continue;

                        // We are working on a new index
                        if ( ! indexName.equals(currentIndex) ) {
                            currentIndex = indexName;

                            String indexTableName = indexInfoSet.getString(INDEX_INFO_TABLE_NAME);
                            indexTableName = caseConvertIdentifierForRails(metaData, indexTableName);

                            final boolean nonUnique = indexInfoSet.getBoolean(INDEX_INFO_NON_UNIQUE);

                            IRubyObject[] args = new IRubyObject[] {
                                RubyString.newUnicodeString(runtime, indexTableName), // table_name
                                RubyString.newUnicodeString(runtime, indexName), // index_name
                                runtime.newBoolean( ! nonUnique ), // unique
                                runtime.newArray() // [] for column names, we'll add to that in just a bit
                                // orders, (since AR 3.2) where, type, using (AR 4.0)
                            };

                            indexes.add( IndexDefinition.callMethod(context, "new", args) ); // IndexDefinition.new
                        }

                        // One or more columns can be associated with an index
                        IRubyObject lastIndexDef = indexes.isEmpty() ? null : indexes.get(indexes.size() - 1);
                        if (lastIndexDef != null) {
                            lastIndexDef.callMethod(context, "columns").callMethod(context, "<<", rubyColumnName);
                        }
                    }

                    return runtime.newArray(indexes);

                } finally { close(indexInfoSet); }
            }
        });
    }

    protected RubyClass getIndexDefinition(final ThreadContext context) {
        final RubyClass adapterClass = getAdapter().getMetaClass();
        IRubyObject IDef = adapterClass.getConstantAt("IndexDefinition");
        return IDef != null ? (RubyClass) IDef : getIndexDefinition(context.runtime);
    }

    @JRubyMethod
    public IRubyObject foreign_keys(final ThreadContext context, IRubyObject table_name) {
        return foreignKeys(context, table_name.toString(), null, null);
    }

    protected IRubyObject foreignKeys(final ThreadContext context, final String tableName, final String schemaName, final String catalog) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final Ruby runtime = context.runtime;
                final RubyClass FKDefinition = getForeignKeyDefinition(context);

                String _tableName = caseConvertIdentifierForJdbc(connection, tableName);
                String _schemaName = caseConvertIdentifierForJdbc(connection, schemaName);
                final TableName table = extractTableName(connection, catalog, _schemaName, _tableName);

                ResultSet fkInfoSet = null;
                final List<IRubyObject> fKeys = new ArrayList<IRubyObject>(8);
                try {
                    final DatabaseMetaData metaData = connection.getMetaData();
                    fkInfoSet = metaData.getImportedKeys(table.catalog, table.schema, table.name);

                    while ( fkInfoSet.next() ) {
                        final RubyHash options = RubyHash.newHash(runtime);

                        String fkName = fkInfoSet.getString("FK_NAME");
                        if (fkName != null) {
                            fkName = caseConvertIdentifierForRails(metaData, fkName);
                            options.put(runtime.newSymbol("name"), fkName);
                        }

                        String columnName = fkInfoSet.getString("FKCOLUMN_NAME");
                        options.put(runtime.newSymbol("column"), caseConvertIdentifierForRails(metaData, columnName));

                        columnName = fkInfoSet.getString("PKCOLUMN_NAME");
                        options.put(runtime.newSymbol("primary_key"), caseConvertIdentifierForRails(metaData, columnName));

                        String fkTableName = fkInfoSet.getString("FKTABLE_NAME");
                        fkTableName = caseConvertIdentifierForRails(metaData, fkTableName);

                        String pkTableName = fkInfoSet.getString("PKTABLE_NAME");
                        pkTableName = caseConvertIdentifierForRails(metaData, pkTableName);

                        final String onDelete = extractForeignKeyRule( fkInfoSet.getInt("DELETE_RULE") );
                        if ( onDelete != null ) options.op_aset(context, runtime.newSymbol("on_delete"), runtime.newSymbol(onDelete));

                        final String onUpdate = extractForeignKeyRule( fkInfoSet.getInt("UPDATE_RULE") );
                        if ( onUpdate != null ) options.op_aset(context, runtime.newSymbol("on_update"), runtime.newSymbol(onUpdate));

                        IRubyObject[] args = new IRubyObject[] {
                            RubyString.newUnicodeString(runtime, fkTableName), // from_table
                            RubyString.newUnicodeString(runtime, pkTableName), // to_table
                            options
                        };

                        fKeys.add( FKDefinition.callMethod(context, "new", args) ); // ForeignKeyDefinition.new
                    }

                    return runtime.newArray(fKeys);

                } finally { close(fkInfoSet); }
            }
        });
    }

    protected String extractForeignKeyRule(final int rule) {
        switch (rule) {
            case DatabaseMetaData.importedKeyNoAction :  return null ;
            case DatabaseMetaData.importedKeyCascade :   return "cascade" ;
            case DatabaseMetaData.importedKeySetNull :   return "nullify" ;
            case DatabaseMetaData.importedKeySetDefault: return "default" ;
        }
        return null;
    }

    protected RubyClass getForeignKeyDefinition(final ThreadContext context) {
        final RubyClass adapterClass = getAdapter().getMetaClass();
        IRubyObject FKDef = adapterClass.getConstantAt("ForeignKeyDefinition");
        return FKDef != null ? (RubyClass) FKDef : getForeignKeyDefinition(context.runtime);
    }


    @JRubyMethod(name = "supports_foreign_keys?")
    public IRubyObject supports_foreign_keys_p(final ThreadContext context) throws SQLException {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final DatabaseMetaData metaData = connection.getMetaData();
                return context.runtime.newBoolean( metaData.supportsIntegrityEnhancementFacility() );
            }
        });
    }

    @JRubyMethod(name = "supports_views?")
    public IRubyObject supports_views_p(final ThreadContext context) throws SQLException {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                final DatabaseMetaData metaData = connection.getMetaData();
                final ResultSet tableTypes = metaData.getTableTypes();
                try {
                    while ( tableTypes.next() ) {
                        if ( "VIEW".equalsIgnoreCase( tableTypes.getString(1) ) ) {
                            return context.runtime.newBoolean( true );
                        }
                    }
                }
                finally {
                    close(tableTypes);
                }
                return context.runtime.newBoolean( false );
            }
        });
    }

    @JRubyMethod(name = "with_connection_retry_guard", frame = true)
    public IRubyObject with_connection_retry_guard(final ThreadContext context, final Block block) {
        return withConnection(context, new Callable<IRubyObject>() {
            public IRubyObject call(final Connection connection) throws SQLException {
                return block.call(context, new IRubyObject[] { convertJavaToRuby(connection) });
            }
        });
    }

    /*
     * (binary?, column_name, table_name, id_key, id_value, value)
     */
    @Deprecated
    @JRubyMethod(name = "write_large_object", required = 6)
    public IRubyObject write_large_object(final ThreadContext context, final IRubyObject[] args)
        throws SQLException {

        final boolean binary = args[0].isTrue();
        final String columnName = args[1].toString();
        final String tableName = args[2].toString();
        final String idKey = args[3].toString();
        final IRubyObject idVal = args[4];
        final IRubyObject lobValue = args[5];

        int count = updateLobValue(context, tableName, columnName, null, idKey, idVal, null, lobValue, binary);
        return context.runtime.newFixnum(count);
    }

    @JRubyMethod(name = "update_lob_value", required = 3)
    public IRubyObject update_lob_value(final ThreadContext context,
        final IRubyObject record, final IRubyObject column, final IRubyObject value)
        throws SQLException {

        final boolean binary = // column.type == :binary
            column.callMethod(context, "type").toString() == (Object) "binary";

        final IRubyObject recordClass = record.callMethod(context, "class");
        final IRubyObject adapter = recordClass.callMethod(context, "connection");

        IRubyObject columnName = column.callMethod(context, "name");
        columnName = adapter.callMethod(context, "quote_column_name", columnName);
        IRubyObject tableName = recordClass.callMethod(context, "table_name");
        tableName = adapter.callMethod(context, "quote_table_name", tableName);
        final IRubyObject idKey = recordClass.callMethod(context, "primary_key"); // 'id'
        // callMethod(context, "quote", primaryKey);
        final IRubyObject idColumn = // record.class.columns_hash['id']
            recordClass.callMethod(context, "columns_hash").callMethod(context, "[]", idKey);

        final IRubyObject id = record.callMethod(context, "id"); // record.id

        final int count = updateLobValue(context,
            tableName.toString(), columnName.toString(), column,
            idKey.toString(), id, idColumn, value, binary
        );
        return context.runtime.newFixnum(count);
    }

    private int updateLobValue(final ThreadContext context,
        final String tableName, final String columnName, final IRubyObject column,
        final String idKey, final IRubyObject idValue, final IRubyObject idColumn,
        final IRubyObject value, final boolean binary) {

        final String sql = "UPDATE "+ tableName +" SET "+ columnName +" = ? WHERE "+ idKey +" = ?" ;

        // TODO: Fix this, the columns don't have the info needed to handle this anymore
        //       currently commented out so that it will compile

        return withConnection(context, new Callable<Integer>() {
            public Integer call(final Connection connection) throws SQLException {
                PreparedStatement statement = null;
                try {
                    statement = connection.prepareStatement(sql);
                    /*
                    if ( binary ) { // blob
                        setBlobParameter(context, connection, statement, 1, value, column, Types.BLOB);
                    }
                    else { // clob
                        setClobParameter(context, connection, statement, 1, value, column, Types.CLOB);
                    }
                    setStatementParameter(context, context.runtime, connection, statement, 2, idValue, idColumn);
                    */
                    return statement.executeUpdate();
                }
                finally { close(statement); }
            }
        });
    }

    protected String caseConvertIdentifierForRails(final Connection connection, final String value)
        throws SQLException {
        if ( value == null ) return null;
        return caseConvertIdentifierForRails(connection.getMetaData(), value);
    }

    /**
     * Convert an identifier coming back from the database to a case which Rails is expecting.
     *
     * Assumption: Rails identifiers will be quoted for mixed or will stay mixed
     * as identifier names in Rails itself.  Otherwise, they expect identifiers to
     * be lower-case.  Databases which store identifiers uppercase should be made
     * lower-case.
     *
     * Assumption 2: It is always safe to convert all upper case names since it appears that
     * some adapters do not report StoresUpper/Lower/Mixed correctly (am I right postgres/mysql?).
     */
    protected static String caseConvertIdentifierForRails(final DatabaseMetaData metaData, final String value)
        throws SQLException {
        if ( value == null ) return null;
        return metaData.storesUpperCaseIdentifiers() ? value.toLowerCase() : value;
    }

    protected String caseConvertIdentifierForJdbc(final Connection connection, final String value)
        throws SQLException {
        if ( value == null ) return null;
        return caseConvertIdentifierForJdbc(connection.getMetaData(), value);
    }

    /**
     * Convert an identifier destined for a method which cares about the databases internal
     * storage case.  Methods like DatabaseMetaData.getPrimaryKeys() needs the table name to match
     * the internal storage name.  Arbitrary queries and the like DO NOT need to do this.
     */
    protected static String caseConvertIdentifierForJdbc(final DatabaseMetaData metaData, final String value)
        throws SQLException {
        if ( value == null ) return null;

        if ( metaData.storesUpperCaseIdentifiers() ) {
            return value.toUpperCase();
        }
        else if ( metaData.storesLowerCaseIdentifiers() ) {
            return value.toLowerCase();
        }
        return value;
    }

    @JRubyMethod(name = "jndi_config?", meta = true)
    public static IRubyObject jndi_config_p(final ThreadContext context,
        final IRubyObject self, final IRubyObject config) {
        return context.runtime.newBoolean( isJndiConfig(context, config) );
    }

    private static boolean isJndiConfig(final ThreadContext context, final IRubyObject config) {
        // config[:jndi] || config[:data_source]

        final Ruby runtime = context.runtime;

        IRubyObject configValue;

        if ( config.getClass() == RubyHash.class ) { // "optimized" version
            final RubyHash configHash = ((RubyHash) config);
            configValue = configHash.fastARef(runtime.newSymbol("jndi"));
            if ( configValue == null ) {
                configValue = configHash.fastARef(runtime.newSymbol("data_source"));
            }
        }
        else {
            configValue = config.callMethod(context, "[]", runtime.newSymbol("jndi"));
            if ( configValue.isNil() ) configValue = null;
            if ( configValue == null ) {
                configValue = config.callMethod(context, "[]", runtime.newSymbol("data_source"));
            }
        }

        if ( configValue == null || configValue.isNil() || configValue == runtime.getFalse() ) {
            return false;
        }
        return true;
    }

    @JRubyMethod(name = "jndi_lookup", meta = true)
    public static IRubyObject jndi_lookup(final ThreadContext context,
                                          final IRubyObject self, final IRubyObject name) {
        try {
            final Object bound = DataSourceConnectionFactory.getInitialContext().lookup( name.toString() );
            return JavaUtil.convertJavaToRuby(context.runtime, bound);
        }
        catch (Exception e) { // javax.naming.NamingException
            if ( e instanceof RaiseException ) throw (RaiseException) e;
            throw wrapException(context, context.runtime.getNameError(), e);
        }
    }

    @Deprecated
    @JRubyMethod(name = "setup_jdbc_factory", visibility = Visibility.PROTECTED)
    public IRubyObject set_driver_factory(final ThreadContext context) {
        setDriverFactory(context);
        return get_connection_factory(context.runtime);
    }

    private ConnectionFactory setDriverFactory(final ThreadContext context) {

        final IRubyObject url = getConfigValue(context, "url");
        final IRubyObject driver = getConfigValue(context, "driver");
        final IRubyObject username = getConfigValue(context, "username");
        final IRubyObject password = getConfigValue(context, "password");

        final IRubyObject driver_instance = getConfigValue(context, "driver_instance");

        if ( url.isNil() || ( driver.isNil() && driver_instance.isNil() ) ) {
            final Ruby runtime = context.runtime;
            final RubyClass errorClass = getConnectionNotEstablished( runtime );
            throw new RaiseException(runtime, errorClass, "adapter requires :driver class and jdbc :url", false);
        }

        final String jdbcURL = buildURL(context, url);
        final ConnectionFactory factory;

        if ( driver_instance != null && ! driver_instance.isNil() ) {
            final Object driverInstance = driver_instance.toJava(Object.class);
            if ( driverInstance instanceof DriverWrapper ) {
                setConnectionFactory(factory = new DriverConnectionFactory(
                        (DriverWrapper) driverInstance, jdbcURL,
                        ( username.isNil() ? null : username.toString() ),
                        ( password.isNil() ? null : password.toString() )
                ));
                return factory;
            }
            else {
                setConnectionFactory(factory = new RubyConnectionFactoryImpl(
                        driver_instance, context.runtime.newString(jdbcURL),
                        ( username.isNil() ? username : username.asString() ),
                        ( password.isNil() ? password : password.asString() )
                ));
                return factory;
            }
        }

        final String user = username.isNil() ? null : username.toString();
        final String pass = password.isNil() ? null : password.toString();

        final DriverWrapper driverWrapper = newDriverWrapper(context, driver.toString());
        setConnectionFactory(factory = new DriverConnectionFactory(driverWrapper, jdbcURL, user, pass));
        return factory;
    }

    protected DriverWrapper newDriverWrapper(final ThreadContext context, final String driver) throws RaiseException {
        try {
            return new DriverWrapper(context.runtime, driver, resolveDriverProperties(context));
        }
        //catch (ClassNotFoundException e) {
        //    throw wrapException(context, context.runtime.getNameError(), e, "cannot load driver class " + driver);
        //}
        catch (ExceptionInInitializerError e) {
            throw wrapException(context, context.runtime.getNameError(), e, "cannot initialize driver class " + driver);
        }
        catch (LinkageError e) {
            throw wrapException(context, context.runtime.getNameError(), e, "cannot link driver class " + driver);
        }
        catch (ClassCastException e) {
            throw wrapException(context, context.runtime.getNameError(), e);
        }
        catch (IllegalAccessException e) { throw wrapException(context, e); }
        catch (InstantiationException e) {
            throw wrapException(context, e.getCause() != null ? e.getCause() : e);
        }
        catch (SecurityException e) {
            throw wrapException(context, context.runtime.getSecurityError(), e);
        }
    }

    @Deprecated // no longer used - only kept for API compatibility
    @JRubyMethod(visibility = Visibility.PRIVATE)
    public IRubyObject jdbc_url(final ThreadContext context) {
        final IRubyObject url = getConfigValue(context, "url");
        return context.runtime.newString( buildURL(context, url) );
    }

    private String buildURL(final ThreadContext context, final IRubyObject url) {
        IRubyObject options = getConfigValue(context, "options");
        if ( options != null && options.isNil() ) options = null;
        return DriverWrapper.buildURL(url, (Map) options);
    }

    private Properties resolveDriverProperties(final ThreadContext context) {
        IRubyObject properties = getConfigValue(context, "properties");
        if ( properties == null || properties.isNil() ) return null;
        Map<?, ?> propertiesJava = (Map) properties.toJava(Map.class);
        if ( propertiesJava instanceof Properties ) {
            return (Properties) propertiesJava;
        }
        final Properties props = new Properties();
        for ( Map.Entry entry : propertiesJava.entrySet() ) {
            props.setProperty(entry.getKey().toString(), entry.getValue().toString());
        }
        return props;
    }

    @JRubyMethod(name = "setup_jndi_factory", visibility = Visibility.PROTECTED)
    public IRubyObject set_data_source_factory(final ThreadContext context) {
        setDataSourceFactory(context);
        return get_connection_factory(context.runtime);
    }

    private ConnectionFactory setDataSourceFactory(final ThreadContext context) {
        final javax.sql.DataSource dataSource; final String lookupName;
        IRubyObject value = getConfigValue(context, "data_source");
        if ( value == context.nil ) {
            value = getConfigValue(context, "jndi");
            lookupName = value.toString();
            dataSource = DataSourceConnectionFactory.lookupDataSource(context, lookupName);
        }
        else {
            dataSource = (javax.sql.DataSource) value.toJava(javax.sql.DataSource.class);
            lookupName = null;
        }
        ConnectionFactory factory = new DataSourceConnectionFactory(dataSource, lookupName);
        setConnectionFactory(factory);
        return factory;
    }

    private static transient IRubyObject defaultConfig;
    private static volatile boolean defaultConfigJndi;
    private static transient ConnectionFactory defaultConnectionFactory;

    /**
     * Sets the connection factory from the available configuration.
     * @param context
     * @see #initialize
     */
    @Deprecated
    @JRubyMethod(name = "setup_connection_factory", visibility = Visibility.PROTECTED)
    public IRubyObject setup_connection_factory(final ThreadContext context) {
        setupConnectionFactory(context);
        return get_connection_factory(context.runtime);
    }

    private IRubyObject get_connection_factory(final Ruby runtime) {
        return JavaUtil.convertJavaToRuby(runtime, connectionFactory);
    }

    /**
     * @return whether the connection factory is JNDI based
     */
    private boolean setupConnectionFactory(final ThreadContext context) {
        final IRubyObject config = getConfig();

        if ( defaultConfig == null ) {
            synchronized(RubyJdbcConnection.class) {
                if ( defaultConfig == null ) {
                    final boolean jndi = isJndiConfig(context, config);
                    if ( jndi ) {
                        defaultConnectionFactory = setDataSourceFactory(context);
                    }
                    else {
                        defaultConnectionFactory = setDriverFactory(context);
                    }
                    defaultConfigJndi = jndi; defaultConfig = config;
                    return jndi;
                }
            }
        }

        if ( defaultConfig != null && ( defaultConfig == config || defaultConfig.eql(config) ) ) {
            setConnectionFactory( defaultConnectionFactory );
            return defaultConfigJndi;
        }

        if ( isJndiConfig(context, config) ) {
            setDataSourceFactory(context); return true;
        }
        else {
            setDriverFactory(context); return false;
        }
    }

    @JRubyMethod(name = "jndi?", alias = "jndi_connection?")
    public RubyBoolean jndi_p(final ThreadContext context) {
        return context.runtime.newBoolean( isJndi() );
    }

    protected final boolean isJndi() { return this.jndi; }

    @JRubyMethod(name = "config")
    public final IRubyObject config() { return getConfig(); }

    public final IRubyObject getConfig() { return this.config; }

    protected final IRubyObject getConfigValue(final ThreadContext context, final String key) {
        final IRubyObject config = getConfig();
        final RubySymbol keySym = context.runtime.newSymbol(key);
        if ( config instanceof RubyHash ) {
            return ((RubyHash) config).op_aref(context, keySym);
        }
        return config.callMethod(context, "[]", keySym);
    }

    protected final IRubyObject setConfigValue(final ThreadContext context,
                                               final String key, final IRubyObject value) {
        final IRubyObject config = getConfig();
        final RubySymbol keySym = context.runtime.newSymbol(key);
        if ( config instanceof RubyHash ) {
            return ((RubyHash) config).op_aset(context, keySym, value);
        }
        return config.callMethod(context, "[]=", new IRubyObject[] { keySym, value });
    }

    protected final IRubyObject setConfigValueIfNotSet(final ThreadContext context,
                                                       final String key, final IRubyObject value) {
        final IRubyObject config = getConfig();
        final RubySymbol keySym = context.runtime.newSymbol(key);
        if ( config instanceof RubyHash ) {
            final IRubyObject setValue = ((RubyHash) config).fastARef(keySym);
            if ( setValue != null ) return setValue;
            return ((RubyHash) config).op_aset(context, keySym, value);
        }

        final IRubyObject setValue = config.callMethod(context, "[]", keySym);
        if ( setValue != context.nil ) return setValue;
        return config.callMethod(context, "[]=", new IRubyObject[] { keySym, value });
    }

    private static String toStringOrNull(final IRubyObject arg) {
        return arg.isNil() ? null : arg.toString();
    }

    protected final IRubyObject getAdapter() { return this.adapter; }

    protected final RubyClass getJdbcColumnClass(final ThreadContext context) {
        return (RubyClass) getAdapter().callMethod(context, "jdbc_column_class");
    }

    protected final ConnectionFactory getConnectionFactory() throws RaiseException {
        if ( connectionFactory == null ) {
            // NOTE: only for (backwards) compatibility (to be deleted) :
            IRubyObject connection_factory = getInstanceVariable("@connection_factory");
            if ( connection_factory == null ) {
                throw getRuntime().newRuntimeError("@connection_factory not set");
            }
            connectionFactory = (ConnectionFactory) connection_factory.toJava(ConnectionFactory.class);
        }
        return connectionFactory;
    }

    public void setConnectionFactory(ConnectionFactory connectionFactory) {
        this.connectionFactory = connectionFactory;
    }

    protected Connection newConnection() throws SQLException {
        return getConnectionFactory().newConnection();
    }

    private static String[] getTypes(final IRubyObject typeArg) {
        if ( typeArg instanceof RubyArray ) {
            IRubyObject[] rubyTypes = ((RubyArray) typeArg).toJavaArray();

            final String[] types = new String[rubyTypes.length];
            for ( int i = 0; i < types.length; i++ ) {
                types[i] = rubyTypes[i].toString();
            }
            return types;
        }
        return new String[] { typeArg.toString() }; // expect a RubyString
    }

    /**
     * @deprecated this method is no longer used, instead consider overriding
     * {@link #mapToResult(ThreadContext, Ruby, Connection, ResultSet, RubyJdbcConnection.ColumnData[])}
     */
    @Deprecated
    protected void populateFromResultSet(
            final ThreadContext context, final Ruby runtime,
            final List<IRubyObject> results, final ResultSet resultSet,
            final ColumnData[] columns) throws SQLException {
        while ( resultSet.next() ) {
            results.add(mapRawRow(context, runtime, columns, resultSet, this));
        }
    }

    /**
     * Maps a query result into a <code>ActiveRecord</code> result.
     * @param context
     * @param runtime
     * @param connection
     * @param resultSet
     * @param columns
     * @return since 3.1 expected to return a <code>ActiveRecord::Result</code>
     * @throws SQLException
     */
    protected IRubyObject mapToResult(final ThreadContext context, final Ruby runtime,
            final Connection connection, final ResultSet resultSet,
            final ColumnData[] columns) throws SQLException {

        final RubyArray resultRows = runtime.newArray();

        while (resultSet.next()) {
            resultRows.append(mapRow(context, runtime, columns, resultSet, this));
        }

        return newResult(context, columns, resultRows);
    }

    @Deprecated
    protected final IRubyObject jdbcToRuby(final Ruby runtime,
        final int column, final int type, final ResultSet resultSet)
        throws SQLException {
        return jdbcToRuby(runtime.getCurrentContext(), runtime, column, type, resultSet);
    }

    protected IRubyObject jdbcToRuby(
        final ThreadContext context, final Ruby runtime,
        final int column, final int type, final ResultSet resultSet)
        throws SQLException {

        try {
            switch (type) {
            case Types.BLOB:
            case Types.BINARY:
            case Types.VARBINARY:
            case Types.LONGVARBINARY:
                return streamToRuby(context, runtime, resultSet, column);
            case Types.CLOB:
            case Types.NCLOB: // JDBC 4.0
                return readerToRuby(context, runtime, resultSet, column);
            case Types.LONGVARCHAR:
            case Types.LONGNVARCHAR: // JDBC 4.0
                return readerToRuby(context, runtime, resultSet, column);
            case Types.TINYINT:
            case Types.SMALLINT:
            case Types.INTEGER:
                return integerToRuby(context, runtime, resultSet, column);
            case Types.REAL:
            case Types.FLOAT:
            case Types.DOUBLE:
                return doubleToRuby(context, runtime, resultSet, column);
            case Types.BIGINT:
                return bigIntegerToRuby(context, runtime, resultSet, column);
            case Types.NUMERIC:
            case Types.DECIMAL:
                return decimalToRuby(context, runtime, resultSet, column);
            case Types.DATE:
                return dateToRuby(context, runtime, resultSet, column);
            case Types.TIME:
                return timeToRuby(context, runtime, resultSet, column);
            case Types.TIMESTAMP:
                return timestampToRuby(context, runtime, resultSet, column);
            case Types.BIT:
            case Types.BOOLEAN:
                return booleanToRuby(context, runtime, resultSet, column);
            case Types.SQLXML: // JDBC 4.0
                return xmlToRuby(context, runtime, resultSet, column);
            case Types.ARRAY: // we handle JDBC Array into (Ruby) []
                return arrayToRuby(context, runtime, resultSet, column);
            case Types.NULL:
                return runtime.getNil();
            // NOTE: (JDBC) exotic stuff just cause it's so easy with JRuby :)
            case Types.JAVA_OBJECT:
            case Types.OTHER:
                return objectToRuby(context, runtime, resultSet, column);
            // (default) String
            case Types.CHAR:
            case Types.VARCHAR:
            case Types.NCHAR: // JDBC 4.0
            case Types.NVARCHAR: // JDBC 4.0
            default:
                return stringToRuby(context, runtime, resultSet, column);
            }
            // NOTE: not mapped types :
            //case Types.DISTINCT:
            //case Types.STRUCT:
            //case Types.REF:
            //case Types.DATALINK:
        }
        catch (IOException e) {
            throw new SQLException(e.getMessage(), e);
        }
    }

    protected IRubyObject integerToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        final long value = resultSet.getLong(column);
        if ( value == 0 && resultSet.wasNull() ) return runtime.getNil();
        return runtime.newFixnum(value);
    }

    protected IRubyObject doubleToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        final double value = resultSet.getDouble(column);
        if ( value == 0 && resultSet.wasNull() ) return runtime.getNil();
        return runtime.newFloat(value);
    }

    protected static boolean useBytesForString = true;

    protected IRubyObject stringToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column) throws SQLException {
        if ( useBytesForString ) { // optimized String -> byte[]
            return bytesToRubyString(context, runtime, resultSet, column);
        }
        else {
            final String value = resultSet.getString(column);
            if ( value == null && resultSet.wasNull() ) return runtime.getNil();
            return RubyString.newInternalFromJavaExternal(runtime, value);
        }
    }

    protected static IRubyObject bytesToRubyString(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException { // optimized String -> byte[]

        final byte[] value = resultSet.getBytes(column);
        if ( value == null && resultSet.wasNull() ) return runtime.getNil();
        return newDefaultInternalString(runtime, value);
    }

    protected IRubyObject bigIntegerToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column) throws SQLException {
        final String value = resultSet.getString(column);
        if ( value == null && resultSet.wasNull() ) return runtime.getNil();
        return RubyBignum.bignorm(runtime, new BigInteger(value));
    }

    protected IRubyObject decimalToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column) throws SQLException {
        final BigDecimal value = resultSet.getBigDecimal(column);
        if ( value == null && resultSet.wasNull() ) return runtime.getNil();
        return new org.jruby.ext.bigdecimal.RubyBigDecimal(runtime, value);
    }

    protected static Boolean rawDateTime;
    static {
        final String dateTimeRaw = System.getProperty("arjdbc.datetime.raw");
        if ( dateTimeRaw != null ) {
            rawDateTime = Boolean.parseBoolean(dateTimeRaw);
        }
        // NOTE: we do this since it will have a different value depending on
        // AR version - since 4.0 false by default otherwise will be true ...
    }

    @JRubyMethod(name = "raw_date_time?", meta = true)
    public static IRubyObject useRawDateTime(final ThreadContext context, final IRubyObject self) {
        if ( rawDateTime == null ) return context.nil;
        return context.runtime.newBoolean( rawDateTime.booleanValue() );
    }

    @JRubyMethod(name = "raw_date_time=", meta = true)
    public static IRubyObject setRawDateTime(final IRubyObject self, final IRubyObject value) {
        if ( value instanceof RubyBoolean ) {
            rawDateTime = ((RubyBoolean) value).isTrue();
        }
        else {
            rawDateTime = value.isNil() ? null : Boolean.TRUE;
        }
        return value;
    }

    /**
     * @return AR::Type-casted value
     * @since 1.3.18
     */
    protected static IRubyObject typeCastFromDatabase(final ThreadContext context,
        final IRubyObject adapter, final RubySymbol typeName, final RubyString value) {
        final IRubyObject type = adapter.callMethod(context, "lookup_cast_type", typeName);
        return type.callMethod(context, "deserialize", value);
    }

    protected IRubyObject dateToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {

        final Date value = resultSet.getDate(column);
        if ( value == null ) {
            if ( resultSet.wasNull() ) return runtime.getNil();
            return runtime.newString(); // ""
        }

        final RubyString strValue = RubyString.newString(runtime, DateTimeUtils.dateToString(value));
        if ( rawDateTime != null && rawDateTime.booleanValue() ) return strValue;

        final IRubyObject adapter = callMethod(context, "adapter"); // self.adapter
        if ( adapter.isNil() ) return strValue; // NOTE: we warn on init_connection

        // NOTE: this CAN NOT be 100% correct - as :date is just a type guess!
        return typeCastFromDatabase(context, adapter, runtime.newSymbol("date"), strValue);
    }

    protected IRubyObject timeToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {

        final Time value = resultSet.getTime(column);
        if ( value == null ) {
            if ( resultSet.wasNull() ) return runtime.getNil();
            return runtime.newString(); // ""
        }

        if ( rawDateTime != null && rawDateTime.booleanValue() ) {
            return RubyString.newString(runtime, DateTimeUtils.timeToString(value));
        }

        return DateTimeUtils.newTime(context, value);
    }

    protected IRubyObject timestampToRuby(final ThreadContext context, // TODO
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {

        final Timestamp value = resultSet.getTimestamp(column);
        if ( value == null ) {
            if ( resultSet.wasNull() ) return runtime.getNil();
            return runtime.newString(); // ""
        }

        if ( rawDateTime != null && rawDateTime.booleanValue() ) {
            return RubyString.newString(runtime, DateTimeUtils.timestampToString(value));
        }

        return DateTimeUtils.newTime(context, value);
    }

    @Deprecated
    protected static RubyString timestampToRubyString(final Ruby runtime, String value) {
        // Timestamp's format: yyyy-mm-dd hh:mm:ss.fffffffff
        String suffix; // assumes java.sql.Timestamp internals :
        if ( value.endsWith( suffix = " 00:00:00.0" ) ) {
            value = value.substring( 0, value.length() - suffix.length() );
        }
        else if ( value.endsWith( suffix = ".0" ) ) {
            value = value.substring( 0, value.length() - suffix.length() );
        }
        return RubyString.newUnicodeString(runtime, value);
    }

    protected static Boolean rawBoolean;
    static {
        final String booleanRaw = System.getProperty("arjdbc.boolean.raw");
        if ( booleanRaw != null ) {
            rawBoolean = Boolean.parseBoolean(booleanRaw);
        }
    }

    @JRubyMethod(name = "raw_boolean?", meta = true)
    public static IRubyObject useRawBoolean(final ThreadContext context, final IRubyObject self) {
        if ( rawBoolean == null ) return context.nil;
        return context.runtime.newBoolean( rawBoolean.booleanValue() );
    }

    @JRubyMethod(name = "raw_boolean=", meta = true)
    public static IRubyObject setRawBoolean(final IRubyObject self, final IRubyObject value) {
        if ( value instanceof RubyBoolean ) {
            rawBoolean = ((RubyBoolean) value).isTrue();
        }
        else {
            rawBoolean = value.isNil() ? null : Boolean.TRUE;
        }
        return value;
    }

    protected IRubyObject booleanToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        if ( rawBoolean != null && rawBoolean.booleanValue() ) {
            final String value = resultSet.getString(column);
            if ( resultSet.wasNull() ) return runtime.getNil();
            return RubyString.newUnicodeString(runtime, value);
        }
        final boolean value = resultSet.getBoolean(column);
        if ( resultSet.wasNull() ) return runtime.getNil();
        return booleanToRuby(runtime, resultSet, value);
    }

    @Deprecated
    protected IRubyObject booleanToRuby(
        final Ruby runtime, final ResultSet resultSet, final boolean value)
        throws SQLException {
        if ( value == false && resultSet.wasNull() ) return runtime.getNil();
        return runtime.newBoolean(value);
    }

    protected static final int streamBufferSize = 2048;

    protected IRubyObject streamToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException, IOException {
        final InputStream stream = resultSet.getBinaryStream(column);
        try {
            if ( resultSet.wasNull() ) return runtime.getNil();

            final int buffSize = streamBufferSize;
            final ByteList bytes = new ByteList(buffSize);

            readBytes(bytes, stream, buffSize);

            return runtime.newString(bytes);
        }
        finally { if ( stream != null ) stream.close(); }
    }

    @Deprecated
    protected IRubyObject streamToRuby(
        final Ruby runtime, final ResultSet resultSet, final InputStream stream)
        throws SQLException, IOException {
        if ( stream == null && resultSet.wasNull() ) return runtime.getNil();

        final int bufSize = streamBufferSize;
        final ByteList string = new ByteList(bufSize);

        final byte[] buf = new byte[bufSize];
        for (int len = stream.read(buf); len != -1; len = stream.read(buf)) {
            string.append(buf, 0, len);
        }

        return runtime.newString(string);
    }

    protected IRubyObject readerToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException, IOException {
        if ( useBytesForString ) { // optimized CLOBs
            return bytesToRubyString(context, runtime, resultSet, column);
        }
        else {
            final Reader reader = resultSet.getCharacterStream(column);
            try {
                if ( reader == null && resultSet.wasNull() ) return runtime.getNil();

                final int bufSize = streamBufferSize;
                final StringBuilder string = new StringBuilder(bufSize);

                final char[] buf = new char[bufSize];
                for (int len = reader.read(buf); len != -1; len = reader.read(buf)) {
                    string.append(buf, 0, len);
                }

                return RubyString.newInternalFromJavaExternal(runtime, string.toString());
            }
            finally { if ( reader != null ) reader.close(); }
        }
    }

    protected IRubyObject objectToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        final Object value = resultSet.getObject(column);

        if ( value == null && resultSet.wasNull() ) return runtime.getNil();

        return JavaUtil.convertJavaToRuby(runtime, value);
    }

    protected IRubyObject arrayToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        final Array value = resultSet.getArray(column);
        try {
            if ( value == null && resultSet.wasNull() ) return runtime.getNil();

            final RubyArray array = runtime.newArray();

            final ResultSet arrayResult = value.getResultSet(); // 1: index, 2: value
            final int baseType = value.getBaseType();
            while ( arrayResult.next() ) {
                array.append( jdbcToRuby(context, runtime, 2, baseType, arrayResult) );
            }
            return array;
        }
        finally { if ( value != null ) value.free(); }
    }

    protected IRubyObject xmlToRuby(final ThreadContext context,
        final Ruby runtime, final ResultSet resultSet, final int column)
        throws SQLException {
        final SQLXML xml = resultSet.getSQLXML(column);
        try {
            if ( xml == null || resultSet.wasNull() ) return runtime.getNil();

            return RubyString.newInternalFromJavaExternal(runtime, xml.getString());
        }
        finally { if ( xml != null ) xml.free(); }
    }

    protected void setStatementParameters(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final RubyArray binds) throws SQLException {

        for ( int i = 0; i < binds.getLength(); i++ ) {
            setStatementParameter(context, connection, statement, i + 1, binds.eltInternal(i));
        }
    }

    // Set the prepared statement attributes based on the passed in Attribute object
    protected void setStatementParameter(final ThreadContext context,
            final Connection connection, final PreparedStatement statement,
            final int index, IRubyObject attribute) throws SQLException {

        //debugMessage(context, attribute);
        int type = jdbcTypeForAttribute(context, attribute);
        IRubyObject value = valueForDatabase(context, attribute);

        // All the set methods were calling this first so save a method call in the nil case
        if ( value.isNil() ) {
            statement.setNull(index, type);
            return;
        }

        switch (type) {
            case Types.TINYINT:
            case Types.SMALLINT:
            case Types.INTEGER:
                setIntegerParameter(context, connection, statement, index, value, attribute, type);
                break;
            case Types.BIGINT:
                setBigIntegerParameter(context, connection, statement, index, value, attribute, type);
                break;
            case Types.REAL:
            case Types.FLOAT:
            case Types.DOUBLE:
                setDoubleParameter(context, connection, statement, index, value, attribute, type);
                break;
            case Types.NUMERIC:
            case Types.DECIMAL:
                setDecimalParameter(context, connection, statement, index, value, attribute, type);
                break;
            case Types.DATE:
                setDateParameter(context, connection, statement, index, value, attribute, type);
                break;
            case Types.TIME:
                setTimeParameter(context, connection, statement, index, value, attribute, type);
                break;
            case Types.TIMESTAMP:
                setTimestampParameter(context, connection, statement, index, value, attribute, type);
                break;
            case Types.BIT:
            case Types.BOOLEAN:
                setBooleanParameter(context, connection, statement, index, value, attribute, type);
                break;
            case Types.SQLXML:
                setXmlParameter(context, connection, statement, index, value, attribute, type);
                break;
            case Types.ARRAY:
                setArrayParameter(context, connection, statement, index, value, attribute, type);
                break;
            case Types.JAVA_OBJECT:
            case Types.OTHER:
                setObjectParameter(context, connection, statement, index, value, attribute, type);
                break;
            case Types.BINARY:
            case Types.VARBINARY:
            case Types.LONGVARBINARY:
            case Types.BLOB:
                setBlobParameter(context, connection, statement, index, value, attribute, type);
                break;
            case Types.CLOB:
            case Types.NCLOB: // JDBC 4.0
                setClobParameter(context, connection, statement, index, value, attribute, type);
                break;
            case Types.CHAR:
            case Types.VARCHAR:
            case Types.NCHAR: // JDBC 4.0
            case Types.NVARCHAR: // JDBC 4.0
            default:
                setStringParameter(context, connection, statement, index, value, attribute, type);
        }
    }
    
    protected static final Map<String, Integer> JDBC_TYPE_FOR = new HashMap<String, Integer>(32, 1);
    static {
        JDBC_TYPE_FOR.put("string", Types.VARCHAR);
        JDBC_TYPE_FOR.put("text", Types.CLOB);
        JDBC_TYPE_FOR.put("integer", Types.INTEGER);
        JDBC_TYPE_FOR.put("float", Types.FLOAT);
        JDBC_TYPE_FOR.put("real", Types.REAL);
        JDBC_TYPE_FOR.put("decimal", Types.DECIMAL);
        JDBC_TYPE_FOR.put("date", Types.DATE);
        JDBC_TYPE_FOR.put("time", Types.TIME);
        JDBC_TYPE_FOR.put("datetime", Types.TIMESTAMP);
        JDBC_TYPE_FOR.put("timestamp", Types.TIMESTAMP);
        JDBC_TYPE_FOR.put("boolean", Types.BOOLEAN);
        JDBC_TYPE_FOR.put("array", Types.ARRAY);
        JDBC_TYPE_FOR.put("xml", Types.SQLXML);

        // also mapping standard SQL names :
        JDBC_TYPE_FOR.put("bit", Types.BIT);
        JDBC_TYPE_FOR.put("tinyint", Types.TINYINT);
        JDBC_TYPE_FOR.put("smallint", Types.SMALLINT);
        JDBC_TYPE_FOR.put("bigint", Types.BIGINT);
        JDBC_TYPE_FOR.put("int", Types.INTEGER);
        JDBC_TYPE_FOR.put("double", Types.DOUBLE);
        JDBC_TYPE_FOR.put("numeric", Types.NUMERIC);
        JDBC_TYPE_FOR.put("char", Types.CHAR);
        JDBC_TYPE_FOR.put("varchar", Types.VARCHAR);
        JDBC_TYPE_FOR.put("binary", Types.BINARY);
        JDBC_TYPE_FOR.put("varbinary", Types.VARBINARY);
        //JDBC_TYPE_FOR.put("struct", Types.STRUCT);
        JDBC_TYPE_FOR.put("blob", Types.BLOB);
        JDBC_TYPE_FOR.put("clob", Types.CLOB);
        JDBC_TYPE_FOR.put("nchar", Types.NCHAR);
        JDBC_TYPE_FOR.put("nvarchar", Types.NVARCHAR);
        JDBC_TYPE_FOR.put("nclob", Types.NCLOB);
    }

    protected int jdbcTypeForAttribute(final ThreadContext context,
        final IRubyObject attribute) throws SQLException {

        final String internedType = internedTypeFor(context, attribute);
        final Integer sqlType = jdbcTypeFor(internedType);
        if ( sqlType != null ) {
            return sqlType.intValue();
        }

        return Types.OTHER; // -1 as well as 0 are used in Types
    }

    protected Integer jdbcTypeFor(final String type) {
        return JDBC_TYPE_FOR.get(type);
    }

    protected IRubyObject attributeType(final ThreadContext context, final IRubyObject attribute) {
        return attribute.callMethod(context, "type");
    }

    protected IRubyObject attributeSQLType(final ThreadContext context, final IRubyObject attribute) {
        return attributeType(context, attribute).callMethod(context, "type");
    }

    protected String internedTypeFor(final ThreadContext context, final IRubyObject attribute) throws SQLException {

        final IRubyObject type = attributeSQLType(context, attribute);

        if ( !type.isNil() ) {
            return type.asJavaString();
        }

        final IRubyObject value = attribute.callMethod(context, "value");

        if ( value instanceof RubyInteger ) {
            return "integer";
        }

        if ( value instanceof RubyNumeric ) {
            return "float";
        }

        if ( value instanceof RubyTime ) {
            return "timestamp";
        }

        return "string";
    }

    protected void setIntegerParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        if ( value instanceof RubyBignum ) { // e.g. HSQLDB / H2 report JDBC type 4
            setBigIntegerParameter(context, connection, statement, index, (RubyBignum) value, attribute, type);
        }
        else if ( value instanceof RubyFixnum ) {
            statement.setLong(index, ((RubyFixnum) value).getLongValue());
        }
        else if ( value instanceof RubyNumeric ) {
            // NOTE: fix2int will call value.convertToInteger for non-numeric
            // types which won't work for Strings since it uses `to_int` ...
            statement.setInt(index, RubyNumeric.fix2int(value));
        }
        else {
            statement.setLong(index, value.convertToInteger("to_i").getLongValue());
        }
    }

    protected void setBigIntegerParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        if ( value instanceof RubyBignum ) {
            setLongOrDecimalParameter(statement, index, ((RubyBignum) value).getValue());
        }
        else if ( value instanceof RubyInteger ) {
            statement.setLong(index, ((RubyInteger) value).getLongValue());
        }
        else {
            setLongOrDecimalParameter(statement, index, value.convertToInteger("to_i").getBigIntegerValue());
        }
    }

    private static final BigInteger MAX_LONG = BigInteger.valueOf(Long.MAX_VALUE);
    private static final BigInteger MIN_LONG = BigInteger.valueOf(Long.MIN_VALUE);

    protected static void setLongOrDecimalParameter(final PreparedStatement statement,
        final int index, final BigInteger value) throws SQLException {
        if ( value.compareTo(MAX_LONG) <= 0 // -1 intValue < MAX_VALUE
                && value.compareTo(MIN_LONG) >= 0 ) {
            statement.setLong(index, value.longValue());
        }
        else {
            statement.setBigDecimal(index, new BigDecimal(value));
        }
    }

    protected void setDoubleParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        if ( value instanceof RubyNumeric ) {
            statement.setDouble(index, ((RubyNumeric) value).getDoubleValue());
        }
        else {
            statement.setDouble(index, value.convertToFloat().getDoubleValue());
        }
    }

    protected void setDecimalParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        if (value instanceof RubyBigDecimal) {
            statement.setBigDecimal(index, ((RubyBigDecimal) value).getValue());
        }
        else if ( value instanceof RubyInteger ) {
            statement.setBigDecimal(index, new BigDecimal(((RubyInteger) value).getBigIntegerValue()));
        }
        else if ( value instanceof RubyNumeric ) {
            statement.setDouble(index, ((RubyNumeric) value).getDoubleValue());
        }
        else { // e.g. `BigDecimal '42.00000000000000000001'`
            statement.setBigDecimal(index,
                    RubyBigDecimal.newInstance(context, context.runtime.getModule("BigDecimal"), value).getValue());
        }
    }

    protected void setTimestampParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        value = callMethod(context, "time_in_default_timezone", value);

        if (value instanceof RubyTime) {
            final RubyTime timeValue = (RubyTime) value;
            final DateTime dateTime = timeValue.getDateTime();
            final Timestamp timestamp = new Timestamp(dateTime.getMillis());

            // 1942-11-30T01:02:03.123_456
            if (type != Types.DATE && timeValue.getNSec() >= 0) timestamp.setNanos((int) (timestamp.getNanos() + timeValue.getNSec()));

            statement.setTimestamp(index, timestamp, getTimeZoneCalendar(dateTime.getZone().getID()));
        } else if ( value instanceof RubyString ) { // yyyy-[m]m-[d]d hh:mm:ss[.f...]
            statement.setString(index, value.toString()); // assume local time-zone
        } else { // DateTime ( ActiveSupport::TimeWithZone.to_time )
            final RubyFloat timeValue = value.convertToFloat(); // to_f
            final Timestamp timestamp = convertToTimestamp(timeValue);

            statement.setTimestamp( index, timestamp, getTimeZoneCalendar("GMT") );
        }
    }

    @Deprecated
    protected static Timestamp convertToTimestamp(final RubyFloat value) {
        return DateTimeUtils.convertToTimestamp(value);
    }

    @Deprecated
    protected static IRubyObject getTimeInDefaultTimeZone(final ThreadContext context, IRubyObject value) {
        return DateTimeUtils.getTimeInDefaultTimeZone(context, value);
    }

    private static Calendar getTimeZoneCalendar(final String ID) {
        return Calendar.getInstance( TimeZone.getTimeZone(ID) );
    }

    protected void setTimeParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        value = callMethod(context, "time_in_default_timezone", value);

        if ( value instanceof RubyTime ) {
            final DateTime dateTime = ((RubyTime) value).getDateTime();
            final Time time = new Time(dateTime.getMillis());

            statement.setTime(index, time, getTimeZoneCalendar(dateTime.getZone().getID()));
        }
        else if ( value instanceof RubyString ) {
            statement.setString(index, value.toString()); // assume local time-zone
        }
        else { // DateTime ( ActiveSupport::TimeWithZone.to_time )
            final RubyFloat timeValue = value.convertToFloat(); // to_f
            final Time time = new Time(timeValue.getLongValue() * 1000); // millis
            // java.sql.Time is expected to be only up to second precision
            statement.setTime(index, time, getTimeZoneCalendar("GMT"));
        }
    }

    protected void setDateParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        if ( ! "Date".equals(value.getMetaClass().getName()) && value.respondsTo("to_date") ) {
            value = value.callMethod(context, "to_date");
        }
        statement.setString(index, value.asString().toString());
    }

    protected void setBooleanParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {
        statement.setBoolean(index, value.isTrue());
    }

    protected void setStringParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        statement.setString(index, value.asString().toString());
    }

    protected void setArrayParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        final String typeName = resolveArrayBaseTypeName(context, attribute);
        final IRubyObject valueForDB = value.callMethod(context, "values");
        Array array = connection.createArrayOf(typeName, ((RubyArray) valueForDB).toArray());
        statement.setArray(index, array);
    }

    protected String resolveArrayBaseTypeName(final ThreadContext context, final IRubyObject attribute) throws SQLException {

        // This shouldn't return nil at this point because we know we have an array typed attribute
        final RubySymbol type = (RubySymbol) attributeSQLType(context, attribute);

        // For some reason the driver doesn't like "character varying" as a type
        if ( type.eql(context.runtime.newSymbol("string")) ){
            return "text";
        }

        final IRubyObject adapter = callMethod("adapter");
        final RubyHash nativeTypes = (RubyHash) adapter.callMethod(context, "native_database_types");
        final RubyHash typeInfo = (RubyHash) nativeTypes.op_aref(context, type);

        return typeInfo.op_aref(context, context.runtime.newSymbol("name")).asString().toString();
    }

    protected void setXmlParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        SQLXML xml = connection.createSQLXML();
        xml.setString(value.asString().toString());
        statement.setSQLXML(index, xml);
    }

    protected void setBlobParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        if ( value instanceof RubyIO ) { // IO/File
            // JDBC 4.0: statement.setBlob(index, ((RubyIO) value).getInStream());
            statement.setBinaryStream(index, ((RubyIO) value).getInStream());
        }
        else { // should be a RubyString
            final ByteList blob = value.asString().getByteList();
            statement.setBytes(index, blob.bytes());

            // JDBC 4.0 :
            //statement.setBlob(index,
            //    new ByteArrayInputStream(bytes.unsafeBytes(), bytes.getBegin(), bytes.getRealSize())
            //);
        }
    }

    protected void setClobParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, final IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {
        if ( value.isNil() ) statement.setNull(index, Types.CLOB);
        else {
            if ( value instanceof RubyIO ) { // IO/File
                statement.setClob(index, new InputStreamReader(((RubyIO) value).getInStream()));
            }
            else { // should be a RubyString
                final String clob = value.asString().decodeString();
                statement.setCharacterStream(index, new StringReader(clob), clob.length());
                // JDBC 4.0 :
                //statement.setClob(index, new StringReader(clob));
            }
        }
    }

    protected void setObjectParameter(final ThreadContext context,
        final Connection connection, final PreparedStatement statement,
        final int index, IRubyObject value,
        final IRubyObject attribute, final int type) throws SQLException {

        statement.setObject(index, value.toJava(Object.class));
    }

    /**
     * Always returns a connection (might cause a reconnect if there's none).
     * @return connection
     * @throws ActiveRecord::ConnectionNotEstablished, ActiveRecord::JDBCError
     */
    protected final Connection getConnection() throws RaiseException {
        return getConnection(false);
    }

    /**
     * @see #getConnection()
     * @param required set to true if a connection is required to exists (e.g. on commit)
     * @return connection
     * @throws ActiveRecord::ConnectionNotEstablished if disconnected
     * @throws ActiveRecord::JDBCError if not connected and connecting fails with a SQL exception
     */
    protected final Connection getConnection(final boolean required) throws RaiseException {
        try {
            return getConnectionInternal(required);
        }
        catch (SQLException e) {
            throw wrapException(getRuntime().getCurrentContext(), e);
        }
    }

    private Connection getConnectionInternal(final boolean required) throws SQLException {
        Connection connection = getConnectionImpl();
        if ( connection == null ) {
            if ( required && ! connected ) {
                final Ruby runtime = getRuntime();
                final RubyClass errorClass = getConnectionNotEstablished( runtime );
                throw new RaiseException(runtime, errorClass, "no connection available", false);
            }
            synchronized (this) {
                connection = getConnectionImpl();
                if ( connection == null ) {
                    connectImpl( true ); // throws SQLException
                    connection = getConnectionImpl();
                }
            }
        }
        return connection;
    }

    /**
     * @note might return null if connection is lazy
     * @return current JDBC connection
     */
    protected final Connection getConnectionImpl() {
        return (Connection) dataGetStruct(); // synchronized
    }

    private void setConnection(final Connection connection) {
        close( getConnectionImpl() ); // close previously open connection if there is one
        //final IRubyObject rubyConnectionObject =
        //    connection != null ? convertJavaToRuby(connection) : getRuntime().getNil();
        //setInstanceVariable( "@connection", rubyConnectionObject );
        dataWrapStruct(connection);
        //return rubyConnectionObject;
        if ( connection != null ) logDriverUsed(connection);
    }

    protected boolean isConnectionValid(final ThreadContext context, final Connection connection) {
        if ( connection == null ) return false;
        Statement statement = null;
        try {
            final String aliveSQL = getAliveSQL(context);
            final RubyInteger aliveTimeout = getAliveTimeout(context);
            if ( aliveSQL != null ) { // expect a SELECT/CALL SQL statement
                statement = createStatement(context, connection);
                if (aliveTimeout != null) {
                    statement.setQueryTimeout((int) aliveTimeout.getLongValue()); // 0 - no timeout
                }
                statement.execute( aliveSQL.toString() );
                return true; // connection alive
            }
            else { // alive_sql nil (or not a statement we can execute)
                return connection.isValid(aliveTimeout == null ? 0 : (int) aliveTimeout.getLongValue()); // since JDBC 4.0
                // ... isValid(0) (default) means no timeout applied
            }
        }
        catch (Exception e) {
            debugMessage(context, "connection considered broken due: " + e.toString());
            return false;
        }
        catch (AbstractMethodError e) { // non-JDBC 4.0 driver
            warn( context,
                "driver does not support checking if connection isValid()" +
                " please make sure you're using a JDBC 4.0 compilant driver or" +
                " set `connection_alive_sql: ...` in your database configuration" );
            debugStackTrace(context, e);
            throw e;
        }
        finally { close(statement); }
    }

    private static final String NIL_ALIVE_SQL = new String(); // no set value marker

    private transient String aliveSQL = null;

    private String getAliveSQL(final ThreadContext context) {
        if ( aliveSQL == null ) {
            final IRubyObject alive_sql = getConfigValue(context, "connection_alive_sql");
            aliveSQL = alive_sql.isNil() ? NIL_ALIVE_SQL : alive_sql.asString().toString();
        }
        return aliveSQL == NIL_ALIVE_SQL ? null : aliveSQL;
    }

    /**
     * internal API do not depend on it
     */
    protected final RubyInteger getAliveTimeout(final ThreadContext context) {
        final IRubyObject timeout = getConfigValue(context, "connection_alive_timeout");
        return timeout.isNil() ? null : timeout.convertToInteger("to_i");
    }

    private boolean tableExists(final Ruby runtime,
        final Connection connection, final TableName tableName) throws SQLException {
        final IRubyObject matchedTables =
            matchTables(runtime, connection, tableName.catalog, tableName.schema, tableName.name, getTableTypes(), true);
        // NOTE: allow implementers to ignore checkExistsOnly paramater - empty array means does not exists
        return matchedTables != null && ! matchedTables.isNil() &&
            ( ! (matchedTables instanceof RubyArray) || ! ((RubyArray) matchedTables).isEmpty() );
    }

    @Override
    @JRubyMethod
    @SuppressWarnings("unchecked")
    public IRubyObject inspect() {
        final ArrayList<Variable<String>> varList = new ArrayList<Variable<String>>(2);
        varList.add(new VariableEntry<String>( "connection", getConnection() == null ? "null" : getConnection().toString() ));
        //varList.add(new VariableEntry<String>( "connectionFactory", connectionFactory == null ? "null" : connectionFactory.toString() ));

        return ObjectSupport.inspect(this, (List) varList);
    }

    /**
     * Match table names for given table name (pattern).
     * @param runtime
     * @param connection
     * @param catalog
     * @param schemaPattern
     * @param tablePattern
     * @param types table types
     * @param checkExistsOnly an optimization flag (that might be ignored by sub-classes)
     * whether the result really matters if true no need to map table names and a truth-y
     * value is sufficient (except for an empty array which is considered that the table
     * did not exists).
     * @return matched (and Ruby mapped) table names
     * @see #mapTables(Ruby, DatabaseMetaData, String, String, String, ResultSet)
     * @throws SQLException
     */
    protected IRubyObject matchTables(final Ruby runtime,
            final Connection connection,
            final String catalog, final String schemaPattern,
            final String tablePattern, final String[] types,
            final boolean checkExistsOnly) throws SQLException {

        final String _tablePattern = caseConvertIdentifierForJdbc(connection, tablePattern);
        final String _schemaPattern = caseConvertIdentifierForJdbc(connection, schemaPattern);
        final DatabaseMetaData metaData = connection.getMetaData();

        ResultSet tablesSet = null;
        try {
            tablesSet = metaData.getTables(catalog, _schemaPattern, _tablePattern, types);
            if ( checkExistsOnly ) { // only check if given table exists
                return tablesSet.next() ? runtime.getTrue() : null;
            }
            else {
                return mapTables(runtime, metaData, catalog, _schemaPattern, _tablePattern, tablesSet);
            }
        }
        finally { close(tablesSet); }
    }

    // NOTE java.sql.DatabaseMetaData.getTables :
    protected final static int TABLES_TABLE_CAT = 1;
    protected final static int TABLES_TABLE_SCHEM = 2;
    protected final static int TABLES_TABLE_NAME = 3;
    protected final static int TABLES_TABLE_TYPE = 4;

    /**
     * @param runtime
     * @param metaData
     * @param catalog
     * @param schemaPattern
     * @param tablePattern
     * @param tablesSet
     * @return List<RubyString>
     * @throws SQLException
     */
    // NOTE: change to accept a connection instead of meta-data
    protected RubyArray mapTables(final Ruby runtime, final DatabaseMetaData metaData,
            final String catalog, final String schemaPattern, final String tablePattern,
            final ResultSet tablesSet) throws SQLException {
        final RubyArray tables = runtime.newArray();
        while ( tablesSet.next() ) {
            String name = tablesSet.getString(TABLES_TABLE_NAME);

            name = caseConvertIdentifierForRails(metaData, name);

            tables.add(RubyString.newUnicodeString(runtime, name));
        }
        return tables;
    }

    protected static final int COLUMN_NAME = 4;
    protected static final int DATA_TYPE = 5;
    protected static final int TYPE_NAME = 6;
    protected static final int COLUMN_SIZE = 7;
    protected static final int DECIMAL_DIGITS = 9;
    protected static final int COLUMN_DEF = 13;
    protected static final int IS_NULLABLE = 18;

    /**
     * Create a string which represents a SQL type usable by Rails from the
     * resultSet column meta-data
     * @param resultSet
     */
    protected String typeFromResultSet(final ResultSet resultSet) throws SQLException {
        final int precision = intFromResultSet(resultSet, COLUMN_SIZE);
        final int scale = intFromResultSet(resultSet, DECIMAL_DIGITS);

        final String type = resultSet.getString(TYPE_NAME);
        return formatTypeWithPrecisionAndScale(type, precision, scale);
    }

    protected static int intFromResultSet(
        final ResultSet resultSet, final int column) throws SQLException {
        final int precision = resultSet.getInt(column);
        return precision == 0 && resultSet.wasNull() ? -1 : precision;
    }

    protected static String formatTypeWithPrecisionAndScale(
        final String type, final int precision, final int scale) {

        if ( precision <= 0 ) return type;

        final StringBuilder typeStr = new StringBuilder().append(type);
        typeStr.append('(').append(precision); // type += "(" + precision;
        if ( scale > 0 ) typeStr.append(',').append(scale); // type += "," + scale;
        return typeStr.append(')').toString(); // type += ")";
    }

    private static IRubyObject defaultValueFromResultSet(final Ruby runtime, final ResultSet resultSet)
        throws SQLException {
        final String defaultValue = resultSet.getString(COLUMN_DEF);
        return defaultValue == null ? runtime.getNil() : RubyString.newInternalFromJavaExternal(runtime, defaultValue);
    }

    protected RubyArray mapColumnsResult(final ThreadContext context,
        final DatabaseMetaData metaData, final TableName components, final ResultSet results)
        throws SQLException {

        final RubyClass Column = getJdbcColumnClass(context);
        final boolean lookupCastType = Column.isMethodBound("cast_type", false);
        // NOTE: primary/primary= methods were removed from Column in AR 4.2
        // setPrimary = ! lookupCastType by default ... it's better than checking
        // whether primary= is bound since it might be a left over in AR-JDBC ext
        return mapColumnsResult(context, metaData, components, results, Column, lookupCastType, ! lookupCastType);
    }

    protected final RubyArray mapColumnsResult(final ThreadContext context,
        final DatabaseMetaData metaData, final TableName components, final ResultSet results,
        final RubyClass Column, final boolean lookupCastType, final boolean setPrimary)
        throws SQLException {

        final Ruby runtime = context.runtime;

        final Collection<String> primaryKeyNames =
            setPrimary ? getPrimaryKeyNames(metaData, components) : null;

        final RubyArray columns = runtime.newArray();
        final IRubyObject config = getConfig();
        while ( results.next() ) {
            final String colName = results.getString(COLUMN_NAME);
            final RubyString railsColumnName = RubyString.newInternalFromJavaExternal(runtime, caseConvertIdentifierForRails(metaData, colName));
            final IRubyObject defaultValue = defaultValueFromResultSet( runtime, results );
            final RubyString sqlType = RubyString.newInternalFromJavaExternal( runtime, typeFromResultSet(results) );
            final RubyBoolean nullable = runtime.newBoolean( ! results.getString(IS_NULLABLE).trim().equals("NO") );
            final IRubyObject[] args;
            if ( lookupCastType ) {
                final IRubyObject castType = getAdapter().callMethod(context, "lookup_cast_type", sqlType);
                args = new IRubyObject[] {config, railsColumnName, defaultValue, castType, sqlType, nullable};
            } else {
                args = new IRubyObject[] {config, railsColumnName, defaultValue, sqlType, nullable};
            }

            IRubyObject column = Column.callMethod(context, "new", args);
            columns.append(column);

            if ( primaryKeyNames != null ) {
                final RubyBoolean primary = runtime.newBoolean( primaryKeyNames.contains(colName) );
                column.getInstanceVariables().setInstanceVariable("@primary", primary);
            }
        }
        return columns;
    }

    private static Collection<String> getPrimaryKeyNames(final DatabaseMetaData metaData,
        final TableName components) throws SQLException {
        ResultSet primaryKeys = null;
        try {
            primaryKeys = metaData.getPrimaryKeys(components.catalog, components.schema, components.name);
            final List<String> primaryKeyNames = new ArrayList<String>(4);
            while ( primaryKeys.next() ) {
                primaryKeyNames.add( primaryKeys.getString(COLUMN_NAME) );
            }
            return primaryKeyNames;
        }
        finally {
            close(primaryKeys);
        }
    }

    protected IRubyObject mapGeneratedKeys(
        final Ruby runtime, final Connection connection,
        final Statement statement) throws SQLException {
        return mapGeneratedKeys(runtime, connection, statement, null);
    }

    protected IRubyObject mapGeneratedKeys(
        final Ruby runtime, final Connection connection,
        final Statement statement, final Boolean singleResult)
        throws SQLException {
        if ( supportsGeneratedKeys(connection) ) {
            ResultSet genKeys = null;
            try {
                genKeys = statement.getGeneratedKeys();
                // drivers might report a non-result statement without keys
                // e.g. on derby with SQL: 'SET ISOLATION = SERIALIZABLE'
                if ( genKeys == null ) return runtime.getNil();
                return doMapGeneratedKeys(runtime, genKeys, singleResult);
            }
            catch (SQLFeatureNotSupportedException e) {
                return null; // statement.getGeneratedKeys()
            }
            finally { close(genKeys); }
        }
        return null; // not supported
    }

    protected final IRubyObject doMapGeneratedKeys(final Ruby runtime,
        final ResultSet genKeys, final Boolean singleResult)
        throws SQLException {

        IRubyObject firstKey = null;
        // no generated keys - e.g. INSERT statement for a table that does
        // not have and auto-generated ID column :
        boolean next = genKeys.next() && genKeys.getMetaData().getColumnCount() > 0;
        // singleResult == null - guess if only single key returned
        if ( singleResult == null || singleResult.booleanValue() ) {
            if ( next ) {
                firstKey = mapGeneratedKey(runtime, genKeys);
                if ( singleResult != null || ! genKeys.next() ) {
                    return firstKey;
                }
                next = true; // 2nd genKeys.next() returned true
            }
            else {
                /* if ( singleResult != null ) */ return runtime.getNil();
            }
        }

        final RubyArray keys = runtime.newArray();
        if ( firstKey != null ) keys.append(firstKey); // singleResult == null
        while ( next ) {
            keys.append( mapGeneratedKey(runtime, genKeys) );
            next = genKeys.next();
        }
        return keys;
    }

    protected IRubyObject mapGeneratedKey(final Ruby runtime, final ResultSet genKeys) throws SQLException {
        return runtime.newFixnum(genKeys.getLong(1));
    }

    private Boolean supportsGeneratedKeys;

    protected boolean supportsGeneratedKeys(final Connection connection) throws SQLException {
        if (supportsGeneratedKeys == null) {
            synchronized(this) {
                if (supportsGeneratedKeys == null) {
                    supportsGeneratedKeys = connection.getMetaData().supportsGetGeneratedKeys();
                }
            }
        }
        return supportsGeneratedKeys.booleanValue();
    }

    /**
     * Converts a JDBC result set into an array (rows) of hashes (row).
     *
     * @param downCase should column names only be in lower case?
     */
    @SuppressWarnings("unchecked")
    private IRubyObject mapToRawResult(final ThreadContext context,
            final Connection connection, final ResultSet resultSet,
            final boolean downCase) throws SQLException {

        final ColumnData[] columns = extractColumns(context, connection, resultSet, downCase);

        final RubyArray results = context.runtime.newArray();
        // [ { 'col1': 1, 'col2': 2 }, { 'col1': 3, 'col2': 4 } ]
        populateFromResultSet(context, context.runtime, (List<IRubyObject>) results, resultSet, columns);
        return results;
    }

    private IRubyObject yieldResultRows(final ThreadContext context,
            final Connection connection, final ResultSet resultSet,
            final Block block) throws SQLException {

        final ColumnData[] columns = extractColumns(context, connection, resultSet, false);

        final Ruby runtime = context.runtime;
        final IRubyObject[] blockArgs = new IRubyObject[columns.length];
        while ( resultSet.next() ) {
            for ( int i = 0; i < columns.length; i++ ) {
                final ColumnData column = columns[i];
                blockArgs[i] = jdbcToRuby(context, runtime, column.index, column.type, resultSet);
            }
            block.call( context, blockArgs );
        }

        return runtime.getNil(); // yielded result rows
    }

    /**
     * Extract columns from result set.
     * @param runtime
     * @param connection
     * @param resultSet
     * @param downCase
     * @return columns data
     * @throws SQLException
     */
    protected ColumnData[] extractColumns(final ThreadContext context,
        final Connection connection, final ResultSet resultSet,
        final boolean downCase) throws SQLException {
        return setupColumns(context, connection, resultSet.getMetaData(), downCase);
    }

    /**
     * @deprecated use {@link #extractColumns(ThreadContext, Connection, ResultSet, boolean)}
     */
    @Deprecated
    protected ColumnData[] extractColumns(final Ruby runtime,
        final Connection connection, final ResultSet resultSet,
        final boolean downCase) throws SQLException {
        return extractColumns(runtime.getCurrentContext(), connection, resultSet, downCase);
    }

    protected <T> T withConnection(final ThreadContext context, final Callable<T> block)
        throws RaiseException {
        try {
            return withConnection(context, true, block);
        }
        catch (final SQLException e) {
            return handleException(context, e); // should never happen
        }
    }

    private <T> T withConnection(final ThreadContext context, final boolean handleException, final Callable<T> block)
        throws RaiseException, RuntimeException, SQLException {

        Throwable exception = null; int retry = 0; int i = 0;

        do {
            if ( retry > 0 ) reconnect(context); // we're retrying running block

            final Connection connection = getConnection(true);
            boolean autoCommit = true; // retry in-case getAutoCommit throws
            try {
                autoCommit = connection.getAutoCommit();
                return block.call(connection);
            }
            catch (final Exception e) { // SQLException or RuntimeException
                exception = e;

                if ( autoCommit ) { // do not retry if (inside) transactions
                    if ( i == 0 ) {
                        IRubyObject retryCount = getConfigValue(context, "retry_count");
                        if ( ! retryCount.isNil() ) {
                            retry = (int) retryCount.convertToInteger().getLongValue();
                        }
                    }
                    if ( isConnectionValid(context, connection) ) {
                        break; // connection not broken yet failed (do not retry)
                    }
                    // we'll reconnect and retry calling block again
                }
                else break;
            }
        } while ( i++ < retry ); // i == 0, retry == 1 means we should retry once

        // (retry) loop ended and we did not return ... exception != null
        if ( handleException ) {
            return handleException(context, getCause(exception)); // throws
        }
        else {
            if ( exception instanceof SQLException ) {
                throw (SQLException) exception;
            }
            if ( exception instanceof RuntimeException ) {
                throw (RuntimeException) exception;
            }
            // won't happen - our try block only throws SQL or Runtime exceptions
            throw new RuntimeException(exception);
        }
    }

    private static Throwable getCause(Throwable exception) {
        Throwable cause = exception.getCause();
        while (cause != null && cause != exception) {
            // SQLException's cause might be DB specific (checked/unchecked) :
            if ( exception instanceof SQLException ) break;
            exception = cause; cause = exception.getCause();
        }
        return exception;
    }

    protected <T> T handleException(final ThreadContext context, Throwable exception) throws RaiseException {
        // NOTE: we shall not wrap unchecked (runtime) exceptions into AR::Error
        // if it's really a misbehavior of the driver throwing a RuntimeExcepion
        // instead of SQLException than this should be overriden for the adapter
        if ( exception instanceof RuntimeException ) {
            throw (RuntimeException) exception;
        }
        debugStackTrace(context, exception);
        throw wrapException(context, exception);
    }

    protected RaiseException wrapException(final ThreadContext context, final Throwable exception) {
        final Ruby runtime = context.runtime;
        if ( exception instanceof SQLException ) {
            return wrapException(context, (SQLException) exception, null);
        }
        if ( exception instanceof RaiseException ) {
            return (RaiseException) exception;
        }
        if ( exception instanceof RuntimeException ) {
            return RaiseException.createNativeRaiseException(runtime, exception);
        }
        // NOTE: compat - maybe makes sense or maybe not (e.g. IOException) :
        return wrapException(context, getJDBCError(runtime), exception);
    }

    public static RaiseException wrapException(final ThreadContext context,
                                               final RubyClass errorClass, final Throwable exception) {
        return wrapException(context, errorClass, exception, exception.toString());
    }

    public static RaiseException wrapException(final ThreadContext context,
                                               final RubyClass errorClass, final Throwable exception, final String message) {
        final RaiseException error = new RaiseException(context.runtime, errorClass, message, true);
        error.initCause(exception);
        return error;
    }

    protected RaiseException wrapException(final ThreadContext context, final SQLException exception, String message) {
        return wrapSQLException(context, exception, message);
    }

    private static RaiseException wrapSQLException(final ThreadContext context,
                                                   final SQLException exception, String message) {
        final Ruby runtime = context.runtime;
        if ( message == null ) {
            message = SQLException.class == exception.getClass() ?
                    exception.getMessage() : exception.toString(); // useful to easily see type on Ruby side
        }
        final RaiseException raise = wrapException(context, getJDBCError(runtime), exception, message);
        final RubyException error = raise.getException(); // assuming JDBCError internals :
        error.setInstanceVariable("@jdbc_exception", JavaEmbedUtils.javaToRuby(runtime, exception));
        return raise;
    }

    private IRubyObject convertJavaToRuby(final Object object) {
        return JavaUtil.convertJavaToRuby( getRuntime(), object );
    }

    /**
     * Some databases support schemas and others do not.
     * For ones which do this method should return true, aiding in decisions regarding schema vs database determination.
     */
    protected boolean databaseSupportsSchemas() {
        return false;
    }

    private static final byte[] SELECT = new byte[] { 's','e','l','e','c','t' };
    private static final byte[] WITH = new byte[] { 'w','i','t','h' };
    private static final byte[] SHOW = new byte[] { 's','h','o','w' };
    private static final byte[] CALL = new byte[]{ 'c','a','l','l' };

    @JRubyMethod(name = "select?", required = 1, meta = true, frame = false)
    public static IRubyObject select_p(final ThreadContext context,
        final IRubyObject self, final IRubyObject sql) {
        return context.runtime.newBoolean( isSelect(sql.convertToString()) );
    }

    private static boolean isSelect(final RubyString sql) {
        final ByteList sqlBytes = sql.getByteList();
        return StringHelper.startsWithIgnoreCase(sqlBytes, SELECT) ||
               StringHelper.startsWithIgnoreCase(sqlBytes, WITH) ||
               StringHelper.startsWithIgnoreCase(sqlBytes, SHOW) ||
               StringHelper.startsWithIgnoreCase(sqlBytes, CALL);
    }

    private static final byte[] INSERT = new byte[] { 'i','n','s','e','r','t' };

    @JRubyMethod(name = "insert?", required = 1, meta = true, frame = false)
    public static IRubyObject insert_p(final ThreadContext context,
        final IRubyObject self, final IRubyObject sql) {
        final ByteList sqlBytes = sql.convertToString().getByteList();
        return context.runtime.newBoolean( StringHelper.startsWithIgnoreCase(sqlBytes, INSERT) );
    }

    protected static boolean startsWithIgnoreCase(final ByteList bytes, final byte[] start) {
        return StringHelper.startsWithIgnoreCase(bytes, start);
    }

    // maps a AR::Result row
    protected static IRubyObject mapRow(final ThreadContext context, final Ruby runtime,
        final ColumnData[] columns, final ResultSet resultSet,
        final RubyJdbcConnection connection) throws SQLException {

        final IRubyObject[] row = new IRubyObject[columns.length];

        for (int i = 0; i < columns.length; i++) {
            final ColumnData column = columns[i];
            row[i] = connection.jdbcToRuby(context, runtime, column.index, column.type, resultSet);
        }

        return RubyArray.newArrayNoCopy(context.runtime, row);
    }

    private static IRubyObject mapRawRow(final ThreadContext context, final Ruby runtime,
        final ColumnData[] columns, final ResultSet resultSet,
        final RubyJdbcConnection connection) throws SQLException {

        final RubyHash row = new RubyHash(runtime, columns.length);

        for ( int i = 0; i < columns.length; i++ ) {
            final ColumnData column = columns[i];
            // NOTE: we know keys are always String so maybe we could take it even further ?!
            row.fastASetCheckString(runtime, column.getName(context),
                connection.jdbcToRuby(context, runtime, column.index, column.type, resultSet)
            );
        }

        return row;
    }

    protected static IRubyObject newResult(final ThreadContext context, ColumnData[] columns, IRubyObject rows) {
        final RubyClass Result = getResult(context.runtime);
        return Result.newInstance(context, columnsToArray(context, columns), rows, Block.NULL_BLOCK); // Result.new
    }

    private static RubyArray columnsToArray(ThreadContext context, ColumnData[] columns) {
        final IRubyObject[] cols = new IRubyObject[columns.length];

        for ( int i = 0; i < columns.length; i++ ) cols[i] = columns[i].getName(context);

        return RubyArray.newArrayNoCopy(context.runtime, cols);
    }

    protected static final class TableName {

        public final String catalog, schema, name;

        public TableName(String catalog, String schema, String table) {
            this.catalog = catalog;
            this.schema = schema;
            this.name = table;
        }

        @Override
        public String toString() {
            return getClass().getName() + "{catalog=" + catalog + ",schema=" + schema + ",name=" + name + "}";
        }

    }

    /**
     * Extract the table name components for the given name e.g. "mycat.sys.entries"
     *
     * @param connection
     * @param catalog (optional) catalog to use if table name does not contain
     *                 the catalog prefix
     * @param schema (optional) schema to use if table name does not have one
     * @param tableName the table name
     * @return (parsed) table name
     *
     * @throws IllegalArgumentException for invalid table name format
     * @throws SQLException
     */
    protected TableName extractTableName(
            final Connection connection, String catalog, String schema,
            final String tableName) throws IllegalArgumentException, SQLException {

        final String[] nameParts = tableName.split("\\.");
        if ( nameParts.length > 3 ) {
            throw new IllegalArgumentException("table name: " + tableName + " should not contain more than 2 '.'");
        }

        String name = tableName;

        if ( nameParts.length == 2 ) {
            schema = nameParts[0]; name = nameParts[1];
        }
        else if ( nameParts.length == 3 ) {
            catalog = nameParts[0]; schema = nameParts[1]; name = nameParts[2];
        }

        if ( schema != null ) {
            schema = caseConvertIdentifierForJdbc(connection, schema);
        }
        name = caseConvertIdentifierForJdbc(connection, name);

        if ( schema != null && ! databaseSupportsSchemas() ) {
            catalog = schema;
        }
        if ( catalog == null ) catalog = connection.getCatalog();

        return new TableName(catalog, schema, name);
    }

    protected final TableName extractTableName(
            final Connection connection, final String schema,
            final String tableName) throws IllegalArgumentException, SQLException {
        return extractTableName(connection, null, schema, tableName);
    }

    protected IRubyObject valueForDatabase(final ThreadContext context, final IRubyObject attribute) {
        return attribute.callMethod(context, "value_for_database");
    }

    private static final StringCache STRING_CACHE = new StringCache();

    protected static RubyString cachedString(final ThreadContext context, final String str) {
        return STRING_CACHE.get(context, str);
    }

    protected static final class ColumnData {

        @Deprecated
        public RubyString name;
        public final int index;
        public final int type;

        private final String label;

        @Deprecated
        public ColumnData(RubyString name, int type, int idx) {
            this.name = name;
            this.type = type;
            this.index = idx;

            this.label = name.toString();
        }

        public ColumnData(String label, int type, int idx) {
            this.label = label;
            this.type = type;
            this.index = idx;
        }

        // NOTE: meant temporary for others to update from accesing name
        ColumnData(ThreadContext context, String label, int type, int idx) {
            this(label, type, idx);
            name = cachedString(context, label);
        }

        public String getName() {
            return label;
        }

        RubyString getName(final ThreadContext context) {
            if ( name != null ) return name;
            return name = cachedString(context, label);
        }

        @Override
        public String toString() {
            return "'" + label + "'i" + index + "t" + type + "";
        }

    }

    private ColumnData[] setupColumns(
            final ThreadContext context,
            final Connection connection,
            final ResultSetMetaData resultMetaData,
            final boolean downCase) throws SQLException {

        final int columnCount = resultMetaData.getColumnCount();
        final ColumnData[] columns = new ColumnData[columnCount];

        for ( int i = 1; i <= columnCount; i++ ) { // metadata is one-based
            String name = resultMetaData.getColumnLabel(i);
            if ( downCase ) {
                name = name.toLowerCase();
            } else {
                name = caseConvertIdentifierForRails(connection, name);
            }

            final int columnType = resultMetaData.getColumnType(i);
            columns[i - 1] = new ColumnData(context, name, columnType, i);
        }

        return columns;
    }

    // JDBC API Helpers :

    protected static void close(final Connection connection) {
        if ( connection != null ) {
            try { connection.close(); }
            catch (final Exception e) { /* NOOP */ }
        }
    }

    public static void close(final ResultSet resultSet) {
        if (resultSet != null) {
            try { resultSet.close(); }
            catch (final Exception e) { /* NOOP */ }
        }
    }

    public static void close(final Statement statement) {
        if (statement != null) {
            try { statement.close(); }
            catch (final Exception e) { /* NOOP */ }
        }
    }

    // DEBUG-ing helpers :

    private static boolean debug = Boolean.parseBoolean( SafePropertyAccessor.getProperty("arjdbc.debug") );

    public static boolean isDebug() { return debug; }

    public static boolean isDebug(final Ruby runtime) {
        return debug || ( runtime != null && runtime.isDebug() );
    }

    public static void setDebug(boolean debug) {
        RubyJdbcConnection.debug = debug;
    }

    public static void debugMessage(final String msg) {
        if ( isDebug() ) System.out.println(msg);
    }

    public static void debugMessage(final ThreadContext context, final String msg) {
        if ( debug || ( context != null && context.runtime.isDebug() ) ) {
            final PrintStream out = context != null ? context.runtime.getOut() : System.out;
            out.println(msg);
        }
    }

    public static void debugMessage(final Ruby runtime, final Object msg) {
        if ( isDebug(runtime) ) {
            final PrintStream out = runtime != null ? runtime.getOut() : System.out;
            out.print("ArJdbc: "); out.println(msg);
        }
    }

    public static void debugMessage(final Ruby runtime, final String msg, final Object e) {
        if ( isDebug(runtime) ) {
            final PrintStream out = runtime != null ? runtime.getOut() : System.out;
            out.print("ArJdbc: "); out.print(msg); out.println(e);
        }
    }

    protected static void debugErrorSQL(final ThreadContext context, final String sql) {
        if ( debug || ( context != null && context.runtime.isDebug() ) ) {
            final PrintStream out = context != null ? context.runtime.getOut() : System.out;
            out.print("ArJdbc: (error) SQL = "); out.println(sql);
        }
    }

    // disables full (Java) traces to be printed while DEBUG is on
    private static final Boolean debugStackTrace;
    static {
        String debugTrace = SafePropertyAccessor.getProperty("arjdbc.debug.trace");
        debugStackTrace = debugTrace == null ? null : Boolean.parseBoolean(debugTrace);
    }

    public static void debugStackTrace(final ThreadContext context, final Throwable e) {
        if ( debug || ( context != null && context.runtime.isDebug() ) ) {
            final PrintStream out = context != null ? context.runtime.getOut() : System.out;
            if ( debugStackTrace == null || debugStackTrace.booleanValue() ) {
                e.printStackTrace(out);
            }
            else {
                out.println(e);
            }
        }
    }

    protected void warn(final ThreadContext context, final String message) {
        arjdbc.ArJdbcModule.warn(context, message);
    }

    private static boolean driverUsedLogged;

    private void logDriverUsed(final Connection connection) {
        if ( isDebug() ) {
            if ( driverUsedLogged ) return;
            driverUsedLogged = true;
            try {
                final DatabaseMetaData meta = connection.getMetaData();
                debugMessage(getRuntime(), "using driver " + meta.getDriverVersion());
            }
            catch (Exception e) {
                debugMessage(getRuntime(), "failed to log driver ", e);
            }
        }
    }

}
