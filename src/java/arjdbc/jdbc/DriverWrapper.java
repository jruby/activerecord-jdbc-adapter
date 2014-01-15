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
package arjdbc.jdbc;

import java.sql.Connection;
import java.sql.Driver;
import java.sql.SQLException;
import java.util.Map;
import java.util.Properties;

import org.jruby.Ruby;


/**
 * A driver wrapper (we're avoiding DriverManager due possible leaks).
 *
 * When the driver is not loaded we're load it using JRuby's class-loader.
 *
 * @author kares
 */
final class DriverWrapper {

    private final Driver driver;
    private final Properties properties;

    DriverWrapper(final Ruby runtime, final String name, final Properties properties)
        throws ClassCastException, InstantiationException, IllegalAccessException {
        this.driver = allocateDriver( loadDriver(runtime, name) );
        this.properties = properties == null ? new Properties() : properties;
    }

    public Properties getProperties() {
        return properties;
    }

    public Driver getDriverInstance() {
        return driver;
    }

    private Driver allocateDriver(final Class<? extends Driver> driverClass) throws InstantiationException, IllegalAccessException {
        try {
            return driverClass.newInstance();
        }
        catch (InstantiationException e) {
            throw e;
        }
        catch (IllegalAccessException e) {
            throw e;
        }
    }

    private static Class<? extends Driver> loadDriver(final Ruby runtime, final String name) throws ClassCastException {
        @SuppressWarnings("unchecked")
        Class<? extends Driver> klass = runtime.getJavaSupport().loadJavaClassVerbose(name);
        if ( ! Driver.class.isAssignableFrom(klass) ) {
            throw new ClassCastException(klass + " is not assignable from " + Driver.class);
        }
        return klass;
    }

    public Connection connect(final String url, final String user, final String pass)
        throws SQLException {

        final Properties properties = (Properties) this.properties.clone();
        if ( user != null ) properties.setProperty("user", user);
        if ( pass != null ) properties.setProperty("password", pass);

        return getDriverInstance().connect(url, properties);
    }

    public static String buildURL(final Object url, final Map<?, ?> options) {
        if ( options == null || options.isEmpty() ) {
            return url.toString();
        }

        final StringBuilder opts = new StringBuilder(); boolean first = true;
        for ( Map.Entry entry : options.entrySet() ) {
            if ( ! first ) opts.append('&');
            opts.append(entry.getKey()).append('=').append(entry.getValue());
            first = false;
        }

        final String urlStr = url.toString();
        if ( urlStr.indexOf('?') == -1 ) {
            return urlStr + '?' + opts;
        }
        else {
            return urlStr + '&' + opts;
        }
    }

}
