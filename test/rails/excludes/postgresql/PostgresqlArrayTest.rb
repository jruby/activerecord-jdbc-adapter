# Associated tracker: https://github.com/jruby/activerecord-jdbc-adapter/issues/830
exclude :test_multi_dimensional_with_strings, 'Multidimensional arrays not supported'
exclude :test_multi_dimensional_with_integers, 'Multidimensional arrays not supported'
exclude :test_with_arbitrary_whitespace, 'Multidimensional arrays not supported'
exclude :test_with_multi_dimensional_empty_strings, 'Multidimensional arrays not supported'

exclude :test_quoting_non_standard_delimiters, 'Same issue as multidimensional arrays, need new method of turning them into strings'
