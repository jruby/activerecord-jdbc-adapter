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

import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.Ruby;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.exceptions.RaiseException;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

import arjdbc.jdbc.WithResultSet;
import static arjdbc.jdbc.RubyJdbcConnection.debugMessage;
import static arjdbc.jdbc.RubyJdbcConnection.executeImpl;
import static arjdbc.jdbc.RubyJdbcConnection.executeQueryImpl;
import static arjdbc.util.QuotingUtils.quoteCharAndDecorateWith;
import static arjdbc.util.QuotingUtils.quoteCharWith;

/**
 * ArJdbc::PostgreSQL
 *
 * @author kares
 */
@org.jruby.anno.JRubyModule(name = "ArJdbc::PostgreSQL")
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

    private static final ByteList BYTES_BACKSLASH = new ByteList(new byte[] { '\\' }, false);
    private static final ByteList BYTES_ANDAND = new ByteList(new byte[] { '\\', '&', '\\', '&' }, false);

    @JRubyMethod(name = "quote_string", required = 1, frame = false)
    public static IRubyObject quote_string(
            final ThreadContext context,
            final IRubyObject self,
            final IRubyObject string) {
        final RubyString str = string.asString();
        // quoted = string.gsub("'", "''")
        RubyString quoted = quoteCharWith(context, str, '\'', '\'');

        if ( ! standard_conforming_strings(context, self) ) { // minor branch
            // quoted.gsub!(/\\/, '\&\&')
            return quoted.callMethod(context, "gsub", new IRubyObject[] {
                context.runtime.newString(BYTES_BACKSLASH),
                context.runtime.newString(BYTES_ANDAND)
            });
        }
        return quoted;
    }

    @JRubyMethod(name = "standard_conforming_strings?")
    public static IRubyObject standard_conforming_strings_p(final ThreadContext context, final IRubyObject self) {
        return context.runtime.newBoolean( standard_conforming_strings(context, self) );
    }

    private static boolean standard_conforming_strings(final ThreadContext context, final IRubyObject self) {
        IRubyObject standard_conforming_strings =
            self.getInstanceVariables().getInstanceVariable("@standard_conforming_strings");

        if ( standard_conforming_strings == null ) {
            synchronized (self) {
                standard_conforming_strings = context.nil; // unsupported

                final IRubyObject client_min_messages = self.callMethod(context, "client_min_messages");
                final Ruby runtime = context.runtime;
                try {
                    self.callMethod(context, "client_min_messages=", runtime.newString("panic"));
                    // NOTE: we no longer log this query as before ... with :
                    // select_one('SHOW standard_conforming_strings', 'SCHEMA')['standard_conforming_strings']
                    standard_conforming_strings = executeQueryImpl(context, self,
                        "SHOW standard_conforming_strings", 1, false, new WithResultSet<IRubyObject>() {
                        public IRubyObject call(final ResultSet resultSet) throws SQLException {
                            if ( resultSet != null && resultSet.next() ) {
                                final String result = resultSet.getString(1);
                                return runtime.newBoolean( "on".equals(result) );
                            }
                            return context.nil;
                        }
                    });
                }
                catch (SQLException e) { // unsupported
                    debugMessage(context.runtime, "standard conforming strings not supported: ", e);
                }
                catch (RaiseException e) { // unsupported
                    debugMessage(context.runtime, "standard conforming strings raised: ", e);
                }
                finally {
                    self.callMethod(context, "client_min_messages=", client_min_messages);
                }

                self.getInstanceVariables().setInstanceVariable("@standard_conforming_strings", standard_conforming_strings);
            }
        }

        return standard_conforming_strings.isTrue();
    }

    @JRubyMethod(name = "standard_conforming_strings=")
    public static IRubyObject set_standard_conforming_strings(final ThreadContext context, final IRubyObject self,
        final IRubyObject enable) {
        //
        //  client_min_messages = self.client_min_messages
        //  begin
        //    self.client_min_messages = 'panic'
        //    value = enable ? "on" : "off"
        //    execute("SET standard_conforming_strings = #{value}", 'SCHEMA')
        //    @standard_conforming_strings = ( value == "on" )
        //  rescue
        //    @standard_conforming_strings = :unsupported
        //  ensure
        //    self.client_min_messages = client_min_messages
        //  end
        //
        IRubyObject standard_conforming_strings = context.nil; // unsupported
        final IRubyObject client_min_messages = self.callMethod(context, "client_min_messages");

        try {
            final Ruby runtime = context.runtime;
            self.callMethod(context, "client_min_messages=", runtime.newString("panic"));

            final String value;
            if ( enable.isNil() || enable == runtime.getFalse() ) value = "off";
            else value = "on";
            // NOTE: we no longer log this query as before ... with :
            // execute("SET standard_conforming_strings = #{value}", 'SCHEMA')
            executeImpl(context, self, "SET standard_conforming_strings = " + value);

            standard_conforming_strings = runtime.newBoolean( value == (Object) "on" );
        }
        catch (RaiseException e) {
            // unsupported
        }
        finally {
            self.callMethod(context, "client_min_messages=", client_min_messages);
        }

        return self.getInstanceVariables().setInstanceVariable("@standard_conforming_strings", standard_conforming_strings);
    }

    @JRubyMethod(name = "unescape_bytea", meta = true)
    public static RubyString unescape_bytea(final ThreadContext context, final IRubyObject self, final IRubyObject escaped) {
        final ByteList bytes = ((RubyString) escaped).getByteList();
        final byte[] rawBytes = ByteaUtils.toBytes(bytes.unsafeBytes(), bytes.getBegin(), bytes.getRealSize());
        return RubyString.newString(context.runtime, new ByteList(rawBytes, false));
    }

}
