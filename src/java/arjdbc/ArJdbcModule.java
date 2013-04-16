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

import java.util.Collection;
import java.util.Map;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyModule;
import org.jruby.anno.JRubyMethod;
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
        
        for ( String name : constants ) {
           IRubyObject value = arJdbc.getConstant(name, false);
           // isModule: return false for Ruby Classes
           if ( value != null && value.isModule() ) {
               modules.append(value);
           }
        }
        return modules;
    }
    
}
