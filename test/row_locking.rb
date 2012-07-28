#! /usr/bin/env jruby

require 'thread'

module RowLockingTestMethods

  # Simple SELECT ... FOR UPDATE test
  def test_select_all_for_update
    @row1_id = Entry.create!(:title => "row1").id
    assert Entry.lock(true).all.map{|row| row.id}.include?(@row1_id)
  end

  def test_row_locking
    row_locking_test_template
  end

  def test_row_locking_with_limit
    row_locking_test_template(:limit => 1)
  end

  private

    def row_locking_test_template(options={})
      # Create two rows that we will work with
      @row1_id = Entry.create!(:title => "row1").id
      @row2_id = Entry.create!(:title => "row2").id

      @result_queue = Queue.new
      signal_queue = Queue.new
      t1 = Thread.new { thread_helper { thread1_main(signal_queue, options) } }
      t2 = Thread.new { thread_helper { thread2_main(signal_queue, options) } }
      t1.join
      t2.join

      result = []
      result << @result_queue.shift until @result_queue.empty?    # Convert the queue into an array

      expected = [
        :t1_locking_row2,
        :t1_locked_row2,

        :t2_locking_row1,
        :t2_locked_row1,

        :t2_locking_row2,     # thread 2 tries to lock row2 ...
        :t1_committed,
        :t2_locked_row2,      # ... but it doesn't succeed until after thread 1 commits its transaction

        :t2_committed,
      ]

      assert_equal expected, result, "thread2 should lock row1 immediately but wait for thread1 to commit before getting the lock on row2"
    end

    def thread1_main(signal_queue, options={})
      Entry.transaction do
        @result_queue << :t1_locking_row2
        Entry.find(@row2_id, {:lock=>true}.merge(options))   # acquire a row lock on r2
        @result_queue << :t1_locked_row2
        signal_queue << :go               # signal thread2 to start
        sleep 2.0                         # Wait for a few seconds, to allow the other thread to race with this thread.
        @result_queue << :t1_committed
      end
    end

    def thread2_main(signal_queue, options={})
      Entry.transaction do
        signal_queue.shift   # wait until we get the signal from thread1
        @result_queue << :t2_locking_row1
        Entry.find(@row1_id, {:lock=>true}.merge(options))   # should return immediately
        @result_queue << :t2_locked_row1
        @result_queue << :t2_locking_row2
        Entry.find(@row2_id, {:lock=>true}.merge(options))   # should block until thread1 commits its transaction
        @result_queue << :t2_locked_row2
        @result_queue << :t2_committed
      end
    end

    def thread_helper
      yield
    rescue Exception => exc
      # Output backtrace, since otherwise we won't see anything until the main thread joins this thread.
      display_exception(exc)
      raise
    ensure
      # This is needed.  Otherwise, the database connections aren't returned to the pool and things break.
      ActiveRecord::Base.connection_handler.clear_active_connections!
    end

    def display_exception(exception)
      lines = []
      lines << "#{exception.class.name}: #{exception.message}\n"
      lines += exception.backtrace.map{|line| "\tfrom #{line}"}
      $stderr.puts lines.join("\n")
    end
end
