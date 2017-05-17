/*
 * The MIT License
 *
 * Copyright 2016-2017 Karol Bucek.
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

import org.jruby.RubyClass;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.callsite.CacheEntry;
import org.jruby.runtime.callsite.CachingCallSite;
import org.jruby.runtime.callsite.FunctionalCachingCallSite;
import org.jruby.runtime.callsite.RespondToCallSite;
import org.jruby.util.SafePropertyAccessor;

import static arjdbc.jdbc.RubyJdbcConnection.debugMessage;

/**
 * INTERNAL API - subject to change!
 */
public abstract class CallSites {

    public static final RespondToCallSite adapter_respond_to_init_connection = respondCallSite("init_connection", "adapter.");

    public static final CachingCallSite adapter_configure_connection = new FunctionalCachingCallSite("configure_connection");
    public static final RespondToCallSite adapter_respond_to_configure_connection = respondCallSite("configure_connection", "adapter.");

    public static final CachingCallSite adapter_jdbc_column_class = monoCallSite("jdbc_column_class", "adapter.");

    public static final CachingCallSite adapter_lookup_cast_type = monoCallSite("lookup_cast_type", "adapter.");

    // column.type_cast_for_database
    public static final CachingCallSite column_type_cast_for_database = monoCallSite("type_cast_for_database", "column.");

    // column.type
    public static final CachingCallSite column_type = monoCallSite("type", "column.");

    public static final CachingCallSite column_sql_type = monoCallSite("sql_type", "column.");

    // column.array?
    public static final CachingCallSite column_array_p = monoCallSite("array?", "column.");
    public static final RespondToCallSite column_respond_to_array_p = respondCallSite("array?", "column.");

    public static final CachingCallSite time_to_date = monoCallSite("to_date", "time.");

    public static final CachingCallSite IndexDefinition_new = monoCallSite("new", "IndexDefinition.");

    public static final CachingCallSite indexDefinition_columns = monoCallSite("columns", "index_definition.");

    public static final CachingCallSite ForeignKeyDefinition_new = monoCallSite("new", "FKDefinition.");

    // AR::Column (of some type) new
    public static final CachingCallSite Column_new = monoCallSite("new", "Column.");

    // AR::Result.new
    public static final CachingCallSite Result_new = monoCallSite("new", "Result.");

    public static CachingCallSite monoCallSite(final String method, final String debugPrefix) {
        if (DEBUG) return new DebugCachingCallSite(method, debugPrefix + method);
        return new FunctionalCachingCallSite(method);
    }

    public static RespondToCallSite respondCallSite(final String method, final String debugPrefix) {
        if (DEBUG) return new DebugRespondToCallSite(debugPrefix + "respond_to?(:" + method + ')');
        return new RespondToCallSite();
    }

    private static final boolean DEBUG; // = false;

    static {
        String debugSites = SafePropertyAccessor.getProperty("arjdbc.debug.sites");
        DEBUG = debugSites == null ? false : Boolean.parseBoolean(debugSites);
    }

    private static class DebugCachingCallSite extends FunctionalCachingCallSite {

        private final String debugId;

        DebugCachingCallSite(String methodName, final String debugId) {
            super(methodName); this.debugId = debugId;
        }

        protected void updateCache(CacheEntry newEntry) {
            debugMessage(debugId + " updateCache: " + newEntry.method);
            super.updateCache(newEntry);
        }

    }

    private static class DebugRespondToCallSite extends RespondToCallSite {

        private final String debugId;

        DebugRespondToCallSite(final String debugId) {
            this.debugId = debugId;
        }

        /*
        protected void updateCache(CacheEntry newEntry) {
            super.updateCache(newEntry);
            debugMessage(debugId + " updated cache: " + newEntry.method);
        } */

        @Override
        protected IRubyObject cacheAndCall(IRubyObject caller, RubyClass selfType, ThreadContext context, IRubyObject self, IRubyObject arg) {
            debugMessage(debugId + " cacheAndCall: " + self + " arg = " + arg);
            return super.cacheAndCall(caller, selfType, context, self, arg);
        }

        @Override
        protected IRubyObject cacheAndCall(IRubyObject caller, RubyClass selfType, ThreadContext context, IRubyObject self, IRubyObject arg0, IRubyObject arg1) {
            debugMessage(debugId + " cacheAndCall: " + self + " arg0 = " + arg0 + " arg1 = " + arg1);
            return super.cacheAndCall(caller, selfType, context, self, arg0, arg1);
        }

    }

}
