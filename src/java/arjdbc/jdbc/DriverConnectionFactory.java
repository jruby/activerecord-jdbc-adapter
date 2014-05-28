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
import java.sql.SQLException;

/**
 *
 * @author kares
 */
final class DriverConnectionFactory implements ConnectionFactory {

    private final DriverWrapper driverWrapper;
    final String url;
    final String username;
    final String password; // null allowed

    public DriverConnectionFactory(final DriverWrapper driver, final String url) {
        this.driverWrapper = driver;
        this.url = url;
        this.username = null;
        this.password = null;
    }

    public DriverConnectionFactory(final DriverWrapper driver, final String url, final String username, final String password) {
        this.driverWrapper = driver;
        this.url = url;
        this.username = username;
        this.password = password;
    }

    @Override
    public Connection newConnection() throws SQLException {
        return driverWrapper.connect(url, username, password);
    }

    DriverWrapper getDriverWrapper() {
        return driverWrapper;
    } /* for tests */

}
