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
package arjdbc.postgresql;

import static arjdbc.util.QuotingUtils.quoteCharAndDecorateWith;

import org.jruby.Ruby;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

/**
 * ArJdbc::PostgreSQL
 *
 * @author kares
 */
public class PostgreSQLModule {

    public static RubyModule load(final RubyModule arJdbc) {
        RubyModule postgreSQL = arJdbc.defineModuleUnder("PostgreSQL");
        postgreSQL.defineAnnotatedMethods( PostgreSQLModule.class );
        return postgreSQL;
    }

    public static RubyModule load(final Ruby runtime) {
        return load( arjdbc.ArJdbcModule.get(runtime) );
    }

    @JRubyMethod(name = "quote_column_name", required = 1, frame = false)
    public static IRubyObject quote_column_name(
            final ThreadContext context,
            final IRubyObject self,
            final IRubyObject string) { // %("#{name.to_s.gsub("\"", "\"\"")}")
        return quoteCharAndDecorateWith(context, string.asString(), '"', '"', (byte) '"', (byte) '"');
    }

    @JRubyMethod(name = "unescape_bytea", meta = true)
    public static RubyString unescape_bytea(final ThreadContext context, final IRubyObject self, final IRubyObject escaped) {
        final ByteList bytes = ((RubyString) escaped).getByteList();
        final byte[] rawBytes = ByteaUtils.toBytes(bytes.unsafeBytes(), bytes.getBegin(), bytes.getRealSize());
        return RubyString.newString(context.runtime, new ByteList(rawBytes, false));
    }

}
