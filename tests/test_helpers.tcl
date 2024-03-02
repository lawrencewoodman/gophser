# Helper functions for the tests
package require Thread

namespace eval TestHelpers {
  variable getStoreData {}
}


# TODO: Make more robust
proc TestHelpers::gopherGet {host port selector} {
  set s [socket $host $port]
  fconfigure $s -buffering none
  puts $s $selector
  set res [read $s]
  catch {close $s}
  return $res
}


proc TestHelpers::startServer {configContent} {
  global RepoRootDir
  set t [thread::create -joinable {
    vwait configContent
    vwait repoRootDir
    source [file join $repoRootDir gophers.tcl]
    set fd [file tempfile tmpConfigFilename "gopher_config.test"]
    puts $fd $configContent
    close $fd
    gophers::init $tmpConfigFilename
    vwait isRunning
    vwait forever
    gophers::shutdown
    # TODO: Delete the configFile
  }]
  thread::send -async $t [list set configContent $configContent]
  thread::send -async $t [list set repoRootDir $RepoRootDir]
  thread::send $t [list set isRunning 1]
  return $t
}


proc TestHelpers::shutdownServer {serverThread} {
  thread::send -async $serverThread [list set forever done]
  thread::join $serverThread
}
