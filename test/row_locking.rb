require 'thread'

require 'test_helper'
require 'models/entry'

module RowLockingTestMethods

  # Simple SELECT ... FOR UPDATE test
  def test_select_all_for_update
    @row1_id = Entry.create!(:title => "row1").id
    all_locked = Entry.lock(true)
    all_locked_ids = all_locked.all.map { |row| row.id }
    assert all_locked_ids.include?(@row1_id)
  end if Test::Unit::TestCase.ar_version('3.0')

  def test_row_locking
    do_test_row_locking
  end

  def test_row_locking_with_limit
    do_test_row_locking :limit => 1
  end

  protected

  def do_test_row_locking(options = {})
    # Create two rows that we will work with
    @row1_id = Entry.create!(:title => "row1").id
    @row2_id = Entry.create!(:title => "row2").id

    @result_queue = Queue.new; signal_queue = Queue.new
    t1 = Thread.new { thread_helper { thread1_main(signal_queue, options) } }
    t2 = Thread.new { thread_helper { thread2_main(signal_queue, options) } }
    t1.join
    t2.join

    result = []
    result << @result_queue.shift until @result_queue.empty? # queue 2 array

    expected = [
      :t1_locking_row2,
      :t1_locked_row2,

      :t2_locking_row1,
      :t2_locked_row1,

      :t2_locking_row2, # thread 2 tries to lock row2 ...
      :t1_committed,
      :t2_locked_row2,  # ... but it doesn't succeed until after thread 1 commits its transaction

      :t2_committed,
    ]

    assert_equal expected, result, "thread2 should lock row1 immediately but wait for thread1 to commit before getting the lock on row2"
  end

  private

  def thread1_main(signal_queue, options)
    limit = options[:limit]
    Entry.transaction do
      @result_queue << :t1_locking_row2
      find_entry(@row2_id, true, limit) # acquire a row lock on r2
      @result_queue << :t1_locked_row2
      signal_queue << :go # signal thread2 to start
      sleep 1.5 # wait for a few seconds, to allow the other thread to race with this thread.
      @result_queue << :t1_committed
    end
  end

  def thread2_main(signal_queue, options)
    limit = options[:limit]
    Entry.transaction do
      signal_queue.shift   # wait until we get the signal from thread1
      @result_queue << :t2_locking_row1
      find_entry(@row1_id, true, limit) # should return immediately
      @result_queue << :t2_locked_row1
      @result_queue << :t2_locking_row2
      find_entry(@row2_id, true, limit) # should block until thread1 commits its transaction
      @result_queue << :t2_locked_row2
      @result_queue << :t2_committed
    end
  end

  def find_entry(id, lock = true, limit = nil)
    if ar_version('4.0')
      arel = Entry
      arel = arel.lock(true) if lock
      arel = arel.limit(limit) if limit
      arel.find(id)
    else
      options = { :lock => lock }
      options[:limit] = limit if limit
      Entry.find(id, options)
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
    lines += exception.backtrace.map { |line| "\tfrom #{line}" }
    $stderr.puts lines.join("\n")
  end

end
