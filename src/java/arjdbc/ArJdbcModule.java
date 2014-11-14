/*
 * The MIT License
 *
 * Copyright 2013-2014 Karol Bucek.
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
package arjdbc;

import java.lang.reflect.InvocationTargetException;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.WeakHashMap;

import org.jruby.NativeException;
import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

import static arjdbc.jdbc.RubyJdbcConnection.getJdbcConnection;

/**
 * ::ArJdbc
 *
 * @author kares
 */
public class ArJdbcModule {

    public static RubyModule load(final Ruby runtime) {
        final RubyModule arJdbc = runtime.getOrCreateModule("ArJdbc");
        arJdbc.defineAnnotatedMethods( ArJdbcModule.class );
        return arJdbc;
    }

    public static RubyModule get(final Ruby runtime) {
        return runtime.getModule("ArJdbc");
    }

    public static void warn(final ThreadContext context, final String message) {
        final Ruby runtime = context.runtime;
        get(runtime).callMethod(context, "warn", runtime.newString(message));
    }

    /**
     * Load the Java parts for the given adapter spec module, e.g. to load
     * ArJdbc::MySQL's Java part: <code>ArJdbc.load_java_part :MySQL</code>
     *
     * NOTE: this method is not intended to be called twice for a given adapter !
     * @param context
     * @param self
     * @param args ( moduleName, [ connectionClass, moduleClass ] )
     * @return true
     */
    @JRubyMethod(name = "load_java_part", meta = true, required = 1, optional = 2)
    public static IRubyObject load_java_part(final ThreadContext context,
        final IRubyObject self, final IRubyObject[] args) {
        final Ruby runtime = context.getRuntime();

        String connectionClass = args.length > 1 ? args[1].toString() : null;
        String moduleClass = args.length > 2 ? args[2].toString() : null;

        final String moduleName = args[0].toString(); // e.g. 'MySQL'
        final String packagePrefix = "arjdbc." + moduleName.toLowerCase() + "."; // arjdbc.mysql

        // NOTE: due previous (backwards compatible) conventions there are
        // 2 things we load, the adapter spec module's Java implemented methods
        // and a custom JdbcConnection class (both are actually optional) e.g. :
        //
        //   MySQLModule.load(RubyModule); // 'arjdbc.mysql' package is assumed
        //   MySQLRubyJdbcConnection.createMySQLJdbcConnectionClass(Ruby, RubyClass);
        //

        if (moduleClass == null) {
             // 'arjdbc.mysql.' + 'MySQL' + 'Module'
            moduleClass = packagePrefix + moduleName + "Module";
        }

        final Class<?> module;
        try {
            module = Class.forName(moduleClass);
            // new convention MySQLModule.load( Ruby runtime ) :
            try {
                invokeStatic(runtime, module, "load", Ruby.class, runtime);
            }
            catch (NoSuchMethodException e) {
                // old convention MySQLModule.load( RubyModule arJdbc ) :
                invokeStatic(runtime, module, "load", RubyModule.class, get(runtime));
            }
        }
        catch (ClassNotFoundException e) { /* ignored */ }
        catch (NoSuchMethodException e) {
            throw newNativeException(runtime, e);
        }

        String connectionClass2 = null;
        if (connectionClass == null) {
             // 'arjdbc.mysql.' + 'MySQL' + 'RubyJdbcConnection'
            connectionClass = packagePrefix + moduleName + "RubyJdbcConnection";
            connectionClass2 = packagePrefix + moduleName + "JdbcConnection";
        }

        try {
            Class<?> connection = null;
            try {
                connection = Class.forName(connectionClass);
            }
            catch (ClassNotFoundException e) {
                if ( connectionClass2 != null ) {
                    connection = Class.forName(connectionClass2);
                }
            }
            if ( connection != null ) {
                // convention e.g. MySQLRubyJdbcConnection.load( Ruby runtime ) :
                try {
                    invokeStatic(runtime, connection, "load", Ruby.class, runtime);
                }
                catch (NoSuchMethodException e) {
                    // "old" e.g. MySQLRubyJdbcConnection.createMySQLJdbcConnectionClass(runtime, jdbcConnection)
                    connection.getMethod("create" + moduleName + "JdbcConnectionClass", Ruby.class, RubyClass.class).
                        invoke(null, runtime, getJdbcConnection(runtime));
                }
            }
        }
        catch (ClassNotFoundException e) { /* ignored */ }
        catch (NoSuchMethodException e) {
            throw newNativeException(runtime, e);
        }
        catch (IllegalAccessException e) {
            throw newNativeException(runtime, e);
        }
        catch (InvocationTargetException e) {
            throw newNativeException(runtime, e);
        }

        return runtime.getTrue();
    }

    /**
     * <code>ArJdbc.modules</code>
     * @param context
     * @param self
     * @return nested constant values that are modules
     */
    @JRubyMethod(name = "modules", meta = true)
    public static IRubyObject modules(final ThreadContext context, final IRubyObject self) {
        final Ruby runtime = context.getRuntime();
        final RubyModule arJdbc = (RubyModule) self;

        final Collection<String> constants = arJdbc.getConstantNames();
        final RubyArray modules = runtime.newArray( constants.size() );

        for ( final String name : constants ) {
           final IRubyObject constant = arJdbc.getConstant(name, false);
           // isModule: return false for Ruby Classes
           if ( constant != null && constant.isModule() ) {
               if ( "Util".equals(name) ) continue;
               if ( "SerializedAttributesHelper".equals(name) ) continue; // deprecated
               if ( "Version".equals(name) ) continue; // deprecated
               modules.append( constant );
           }
        }
        return modules;
    }

    // JDBC "driver" gem helper(s) :

    @JRubyMethod(name = "load_driver", meta = true)
    public static IRubyObject load_driver(final ThreadContext context, final IRubyObject self,
        final IRubyObject const_name) { // e.g. load_driver(:MySQL)
        IRubyObject loaded = loadDriver(context, self, const_name.toString());
        return loaded == null ? context.nil : loaded;
    }

    // NOTE: probably useless - only to be useful for the pooled runtime mode when jar at WEB-INF/lib
    static final Map<Ruby, Map<String, Boolean>> loadedDrivers = new WeakHashMap<Ruby, Map<String, Boolean>>(8);

    private static IRubyObject loadDriver(final ThreadContext context, final IRubyObject self,
        final String constName) {
        final Ruby runtime = context.runtime;
        // look for "cached" loading result :
        Map<String, Boolean> loadedMap = loadedDrivers.get(runtime);
        if ( loadedMap == null ) {
            synchronized (ArJdbcModule.class) {
                loadedMap = loadedDrivers.get(runtime);
                if ( loadedMap == null ) {
                    loadedMap = new HashMap<String, Boolean>(4);
                    loadedDrivers.put(runtime, loadedMap);
                }
            }
        }

        final Boolean driverLoaded = loadedMap.get(constName);
        if ( driverLoaded != null ) {
            if ( driverLoaded.booleanValue() ) return runtime.getFalse();
            return runtime.getNil();
        }

        try { // require 'jdbc/mysql'
            final byte[] name = new byte[5 + constName.length()]; // 'j','d','b','c','/'
            name[0] = 'j'; name[1] = 'd'; name[2] = 'b'; name[3] = 'c'; name[4] = '/';
            for ( int i = 0; i < constName.length(); i++ ) {
                name[ 5 + i ] = (byte) Character.toLowerCase( constName.charAt(i) );
            }
            final RubyString strName = RubyString.newString(runtime, new ByteList(name, false));
            self.callMethod(context, "require", strName); // require 'jdbc/mysql'
        }
        catch (RaiseException e) { // LoadError
            synchronized (loadedMap) {
                loadedMap.put(constName, Boolean.FALSE);
            }
            return null;
        }

        final RubyModule jdbc = runtime.getModule("Jdbc");
        if ( jdbc != null ) { // Jdbc::MySQL
            final RubyModule constant = (RubyModule) jdbc.getConstantAt(constName);
            if ( constant != null ) { // ::Jdbc::MySQL.load_driver :
                if ( constant.respondsTo("load_driver") ) {
                    IRubyObject result = constant.callMethod("load_driver");
                    synchronized (loadedMap) {
                        loadedMap.put(constName, Boolean.TRUE);
                    }
                    return result;
                }
            }
        }

        synchronized (loadedMap) {
            loadedMap.put(constName, Boolean.FALSE);
        }
        return null;
    }

    private static Object invokeStatic(final Ruby runtime,
        final Class<?> klass, final String name, final Class<?> argType, final Object arg)
        throws NoSuchMethodException {
        try {
            return klass.getMethod(name, argType).invoke(null, arg);
        }
        catch (IllegalAccessException e) {
            throw newNativeException(runtime, e);
        }
        catch (InvocationTargetException e) {
            throw newNativeException(runtime, e);
        }
    }

    private static RaiseException newNativeException(final Ruby runtime, final Throwable cause) {
        RubyClass nativeClass = runtime.getClass(NativeException.CLASS_NAME);
        NativeException nativeException = new NativeException(runtime, nativeClass, cause);
        return new RaiseException(cause, nativeException);
    }

}
