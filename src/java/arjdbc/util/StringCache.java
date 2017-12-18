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

import java.lang.ref.SoftReference;
import java.util.concurrent.ConcurrentHashMap;

import org.jruby.Ruby;
import org.jruby.RubyString;
import org.jruby.runtime.ThreadContext;
import org.jruby.util.ByteList;

/**
 * Cache of _unicode_ strings.
 *
 * @author kares
 */
public final class StringCache {

    final ConcurrentHashMap<String, SoftReference<ByteList>> cache = new ConcurrentHashMap<>(64);

    public RubyString get(final ThreadContext context, final String key) {
        final ByteList bytes;
        final SoftReference<ByteList> ref = cache.get(key);
        if ( ref == null || (bytes = ref.get()) == null ) return store(context, key);
        return (RubyString) RubyString.newUnicodeString(context.runtime, bytes).freeze(context);
    }

    private RubyString store(final ThreadContext context, final String key) {
        final Ruby runtime = context.runtime;
        final RubyString str = RubyString.newUnicodeString(runtime, key);
        cache.putIfAbsent(key, new SoftReference<>(str.getByteList()));
        // not clearing up orphans - but since its to be used for column/table names ...
        // should be fine - DB drivers tend do also cache some meta-data information
        return (RubyString) str.freeze(context);
    }

    public void clear() {
        cache.clear();
    }

}
