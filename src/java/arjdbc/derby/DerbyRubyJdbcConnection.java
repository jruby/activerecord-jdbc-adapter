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
package arjdbc.derby;

import arjdbc.jdbc.RubyJdbcConnection;
import arjdbc.jdbc.SQLBlock;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * ArJdbc::DerbyJdbcConnection
 * 
 * @author kares
 */
public class DerbyRubyJdbcConnection extends RubyJdbcConnection {
    
    protected DerbyRubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createDerbyJdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        final RubyClass clazz = getConnectionAdapters(runtime). // ActiveRecord::ConnectionAdapters
            defineClassUnder("DerbyJdbcConnection", jdbcConnection, DERBY_JDBCCONNECTION_ALLOCATOR);
        clazz.defineAnnotatedMethods(DerbyRubyJdbcConnection.class);
        return clazz;
    }

    private static ObjectAllocator DERBY_JDBCCONNECTION_ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new DerbyRubyJdbcConnection(runtime, klass);
        }
    };
    
    @Override
    protected SQLBlock tableLookupBlock(final Ruby runtime,
            final String catalog, String schemaPattern,
            final String tablePattern, final String[] types) {
        if (schemaPattern != null && schemaPattern.equals("")) { 
            schemaPattern = null; // Derby doesn't like empty-string schema name
        }
        return super.tableLookupBlock(runtime, catalog, schemaPattern, tablePattern, types);
    }
    
}
