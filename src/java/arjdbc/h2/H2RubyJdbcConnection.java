/***** BEGIN LICENSE BLOCK *****
 * Copyright (c) 2006-2010 Nick Sieger <nick@nicksieger.com>
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

package arjdbc.h2;

import java.sql.Connection;
import java.sql.SQLException;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author nicksieger
 */
@org.jruby.anno.JRubyClass(name = "ActiveRecord::ConnectionAdapters::H2JdbcConnection")
public class H2RubyJdbcConnection extends arjdbc.jdbc.RubyJdbcConnection {
    private static final long serialVersionUID = -2652911264521657428L;

    public H2RubyJdbcConnection(Ruby runtime, RubyClass metaClass) {
        super(runtime, metaClass);
    }

    public static RubyClass createH2JdbcConnectionClass(Ruby runtime, RubyClass jdbcConnection) {
        RubyClass clazz = getConnectionAdapters(runtime).
            defineClassUnder("H2JdbcConnection", jdbcConnection, ALLOCATOR);
        clazz.defineAnnotatedMethods(H2RubyJdbcConnection.class);
        return clazz;
    }

    public static RubyClass load(final Ruby runtime) {
        RubyClass jdbcConnection = getJdbcConnection(runtime);
        return createH2JdbcConnectionClass(runtime, jdbcConnection);
    }

    protected static ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new H2RubyJdbcConnection(runtime, klass);
        }
    };

    /**
     * H2 supports schemas.
     */
    @Override
    protected boolean databaseSupportsSchemas() {
        return true;
    }

    @Override
    protected String caseConvertIdentifierForJdbc(final Connection connection, final String value) {
        if ( value == null ) return null;
        return value.toUpperCase();
    }

    // NOTE: not supported
    // org.h2.jdbc.JdbcSQLException: Hexadecimal string contains non-hex character: "PUBLIC" [90004-178]
    //@Override
    //protected boolean useByteStrings() { return false; }

}
