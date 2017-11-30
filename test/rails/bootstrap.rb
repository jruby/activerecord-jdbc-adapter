raise ArgumentError "This is really called"
gem 'minitest'
$stderr.puts "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
require 'minitest/autorun'
$stderr.puts "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA.2"
require 'minitest/excludes'
$stderr.puts "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA.3"
