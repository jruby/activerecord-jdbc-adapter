/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package arjdbc.sqlite3;

import static arjdbc.util.QuotingUtils.quoteCharWith;

import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;

/**
 *
 * @author kares
 */
public class SQLite3Module {
    
    public static void load(RubyModule arJdbc) {
        RubyModule sqlite3 = arJdbc.defineModuleUnder("SQLite3");
        sqlite3.defineAnnotatedMethods( SQLite3Module.class );
    }
    
    @JRubyMethod(name = "quote_string", required = 1, frame = false)
    public static IRubyObject quote_string(
            final ThreadContext context, 
            final IRubyObject self, 
            final IRubyObject string) { // string.gsub("'", "''") :
        final char single = '\'';
        final RubyString quoted = quoteCharWith(
            context, (RubyString) string, single, single
        );
        return quoted;
    }

    private static final ByteList Q_TRUE = new ByteList(new byte[] { '\'', 't', '\'' }, false);
    
    @JRubyMethod(name = "quoted_true", required = 0, frame = false)
    public static IRubyObject quoted_true(
            final ThreadContext context, 
            final IRubyObject self) {
        return RubyString.newString(context.getRuntime(), Q_TRUE);
    }

    private static final ByteList Q_FALSE = new ByteList(new byte[] { '\'', 'f', '\'' }, false);
    
    @JRubyMethod(name = "quoted_false", required = 0, frame = false)
    public static IRubyObject quoted_false(
            final ThreadContext context, 
            final IRubyObject self) {
        return RubyString.newString(context.getRuntime(), Q_FALSE);
    }
    
}
