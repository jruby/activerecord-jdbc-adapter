/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */

package jdbc_adapter;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import org.jruby.runtime.builtin.IRubyObject;

/**
 *
 * @author nicksieger
 */
public abstract class SQLBlock {
    abstract IRubyObject call(Connection c) throws SQLException;

    public void close(Statement p) {
        if (p != null) {
            try {
                p.close();
            } catch (Exception e) {
            }
        }
    }

    public void close(ResultSet p) {
        if (p != null) {
            try {
                p.close();
            } catch (Exception e) {
            }
        }
    }
}
