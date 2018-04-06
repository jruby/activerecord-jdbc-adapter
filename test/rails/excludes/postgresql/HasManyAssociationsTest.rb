unless ENV['TEST'] == 'test/cases/associations/has_many_associations_test.rb'
  # This test only fails when running the full suite, it passes when running just this test
  exclude :test_do_not_call_callbacks_for_delete_all, 'assumes the db is empty before test starts which it does not seem to be when running the full suite'
end
