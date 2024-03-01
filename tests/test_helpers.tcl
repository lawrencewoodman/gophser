# Helper functions for the tests

namespace eval TestHelpers {
  variable getStoreData {}
}


# TODO: Make more robust
proc TestHelpers::gopherGet {host port url} {
  set s [socket $host $port]
  fconfigure $s -buffering none
  puts $s $url
  set res [read $s]
  catch {close $s}
  return $res
}
