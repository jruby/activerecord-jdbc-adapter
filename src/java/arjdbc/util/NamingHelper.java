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
package arjdbc.util;

import javax.naming.InitialContext;
import javax.naming.NameNotFoundException;
import javax.naming.NamingException;

/**
 * JNDI helper.
 *
 * @author kares
 */
public abstract class NamingHelper {

    private static final boolean contextCached = Boolean.getBoolean("arjdbc.jndi.context.cached");

    private static InitialContext initialContext;

    public static InitialContext getInitialContext() throws NamingException {
        if ( initialContext != null ) return initialContext;
        if ( contextCached ) return initialContext = new InitialContext();
        return new InitialContext();
    }

    /**
     * Currently, the only way to bypass <code>new InitialContext()</code>
     * without the environment being passed in.
     * @param context
     * @see #getInitialContext()
     */
    public static void setInitialContext(final InitialContext context) {
        NamingHelper.initialContext = context;
    }

    /**
     * Lookup a JNDI name, relative to the initial context.
     * @param name full name
     * @return bound resource
     * @throws NameNotFoundException
     * @throws NamingException
     */
    @SuppressWarnings("unchecked")
    public static <T> T lookup(final String name)
        throws NameNotFoundException, NamingException {
        return (T) getInitialContext().lookup(name);
    }

}
