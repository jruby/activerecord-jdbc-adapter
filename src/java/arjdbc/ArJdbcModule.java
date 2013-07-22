/*
 * The MIT License
 *
 * Copyright 2013 Karol Bucek.
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

import arjdbc.jdbc.RubyJdbcConnection;

import java.lang.reflect.InvocationTargetException;
import java.util.Collection;

import org.jruby.NativeException;
import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

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

        String connectionClass2 = null;
        if (connectionClass == null) {
             // 'arjdbc.mysql.' + 'MySQL' + 'RubyJdbcConnection'
            connectionClass = packagePrefix + moduleName + "RubyJdbcConnection";
            connectionClass2 = packagePrefix + moduleName + "JdbcConnection";
        }
        if (moduleClass == null) {
             // 'arjdbc.mysql.' + 'MySQL' + 'Module'
            moduleClass = packagePrefix + moduleName + "Module";
        }

        final Ruby runtime = context.getRuntime();
        final RubyModule arJdbc = runtime.getModule("ArJdbc");

        try {
            final Class<?> module = Class.forName(moduleClass);
             // MySQLModule.load( arJdbc ) :
            module.getMethod("load", RubyModule.class).invoke(null, arJdbc);
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
                final String method = "create" + moduleName + "JdbcConnectionClass";
                // MySQLRubyJdbcConnection.createMySQLJdbcConnectionClass(runtime, jdbcConnection)
                connection.getMethod(method, Ruby.class, RubyClass.class).
                    invoke(null, runtime, RubyJdbcConnection.getJdbcConnectionClass(runtime));
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
           IRubyObject value = arJdbc.getConstant(name, false);
           // isModule: return false for Ruby Classes
           if ( value != null && value.isModule() ) {
               if ( "MissingFunctionalityHelper".equals(name) ) continue;
               if ( "SerializedAttributesHelper".equals(name) ) continue;
               if ( "QuotedPrimaryKeyExtension".equals(name) ) continue;
               if ( "Util".equals(name) ) continue;
               if ( "Version".equals(name) ) continue;
               modules.append(value);
           }
        }
        return modules;
    }

    private static RaiseException newNativeException(final Ruby runtime, final Throwable cause) {
        RubyClass nativeClass = runtime.getClass(NativeException.CLASS_NAME);
        NativeException nativeException = new NativeException(runtime, nativeClass, cause);
        throw new RaiseException(cause, nativeException);
    }

}
