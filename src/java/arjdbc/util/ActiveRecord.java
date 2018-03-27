package arjdbc.util;

import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.runtime.ThreadContext;

/**
 * Provide a standard place to get references to ActiveRecord classes and modules
 */
public class ActiveRecord {

    /**
     * @param context the current thread context
     * @return <code>ActiveRecord::Base</code>
     */
    public static RubyClass Base(final ThreadContext context) {
        return Module(context).getClass("Base");
    }

    /**
     * @param context the current thread context
     * @return <code>ActiveRecord</code> module
     */
    public static RubyModule Module(final ThreadContext context) {
        return context.runtime.getModule("ActiveRecord");
    }

    /**
     * @param context the current thread context
     * @return <code>ActiveRecord::Result</code>
     */
    public static RubyClass Result(final ThreadContext context) {
        return Module(context).getClass("Result");
    }

}