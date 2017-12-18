
package arjdbc.util;

import java.util.List;
import org.jruby.Ruby;
import org.jruby.RubyBasicObject;
import org.jruby.RubyString;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.builtin.Variable;

public abstract class ObjectSupport {

    @SuppressWarnings("unchecked")
    public static RubyString inspect(final RubyBasicObject self) {
        return inspect(self, (List) self.getInstanceVariableList());
    }

    public static RubyString inspect(final RubyBasicObject self, final List<Variable> variableList) {
        final Ruby runtime = self.getRuntime();
        return RubyString.newString(runtime, inspect(runtime, self, variableList));
    }

    private static StringBuilder inspect(final Ruby runtime, final RubyBasicObject self,
        final List<Variable> variableList) {
        final StringBuilder part = new StringBuilder();
        String cname = self.getMetaClass().getRealClass().getName();
        part.append("#<").append(cname).append(":0x");
        part.append(Integer.toHexString(System.identityHashCode(self)));

        if (runtime.isInspecting(self)) {
            /* 6:tags 16:addr 1:eos */
            part.append(" ...>");
            return part;
        }
        try {
            runtime.registerInspecting(self);
            final ThreadContext context = runtime.getCurrentContext();
            return inspectObj(context, variableList, part);
        } finally {
            runtime.unregisterInspecting(self);
        }
    }

    private static StringBuilder inspectObj(final ThreadContext context,
        final List<Variable> variableList,
        final StringBuilder part) {
        String sep = "";

        for ( final Variable ivar : variableList ) {
            part.append(sep).append(' ').append( ivar.getName() ).append('=');
            final Object ival = ivar.getValue();
            if ( ival instanceof IRubyObject ) {
                part.append( ((IRubyObject) ival).callMethod(context, "inspect") );
            }
            else { // allow the variable to come formatted (as is) already :
                part.append( ival ); // ival == null ? "nil" : ival.toString()
            }
            sep = ",";
        }
        part.append('>');
        return part;
    }

}
