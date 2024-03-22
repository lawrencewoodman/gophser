# Helper functions for the tests
package require Thread

namespace eval TestHelpers {
  variable getStoreData {}
  variable swarmSocks [list]
  variable swarmDone false
  variable swarmResults
}

proc TestHelpers::gopherGet {host port selector} {
    set s [socket $host $port]
    fconfigure $s -buffering none -translation binary
    puts $s $selector
    set res [read $s]
    catch {close $s}
    return $res
}


proc TestHelpers::gopherSwarmGet {num host port selector} {
  variable swarmSocks
  variable swarmDone
  variable swarmLastRead
  variable swarmResults
  variable swarmSelector
  set swarmSocks [list]
  set swarmDone false
  set swarmLastRead [clock milliseconds]
  set swarmResults [dict create]
  set swarmSelector $selector

  for {set i 0} {$i < $num} {incr i} {
    if {[catch {set sock [socket $host $port]}]} {
      puts stderr "$::errorInfo: $host:$port"
      exit 1
    }
    lappend swarmSocks $sock
    chan configure $sock -buffering line -blocking 0 -translation binary
    puts $sock $selector
    chan event $sock readable [list TestHelpers::gopherSwarmGetReader $sock]
  }
  after 5 TestHelpers::gopherSwarmGetReadMonitor
  vwait TestHelpers::swarmDone
}


proc TestHelpers::gopherSwarmGetReader {sock} {
  variable swarmLastRead
  variable swarmResults
  if {[catch {read $sock} res] || [eof $sock]} {
      catch {close $sock}
  }

  dict append swarmResults $sock $res
  set swarmLastRead [clock milliseconds]
}


proc TestHelpers::gopherSwarmGetReadMonitor {} {
  variable swarmLastRead
  variable swarmSocks
  # If > 10 milliseconds since anything was last read, close all and finish
  if {[clock milliseconds]-$swarmLastRead > 10} {
    foreach sock $swarmSocks {
      catch {close $sock}
    }
    set TestHelpers::swarmDone true
  } else {
    after 5 TestHelpers::gopherSwarmGetReadMonitor
  }
}


proc TestHelpers::gopherSwarmGetVerifyResults {} {
  variable swarmResults
  variable swarmSocks
  variable swarmSelector
  if {[llength $swarmSocks] != [dict size $swarmResults]} {
    error "number of results != number of connections"
  }
  set wantResult [TestHelpers::gopherGet localhost 7070 $swarmSelector]
  # If error received.  This is only sufficient for test nothing more
  if {[string index $wantResult 0] eq "3"} {
    error "received error: $wantResult"
  }
  dict for {- res} $swarmResults {
    if {$res ne $wantResult} {
      error "unexpected result:\n got:$res\n want: $wantResult"
    }
  }
}


proc TestHelpers::startServer {configScript} {
  global RepoRootDir
  set t [thread::create -joinable {
    vwait configScript
    vwait repoRootDir
    source [file join $repoRootDir gophers.tcl]
    eval $configScript
    set port 7070
    gophers::init $port
    vwait isRunning
    vwait forever
    gophers::shutdown
  }]
  thread::send -async $t [list set configScript $configScript]
  thread::send -async $t [list set repoRootDir $RepoRootDir]
  # Make sure gopher server is running before exiting function
  # so that nothing tries to get from it until it is ready
  thread::send $t [list set isRunning 1]
  return $t
}


proc TestHelpers::shutdownServer {serverThread} {
  thread::send -async $serverThread [list set forever done]
  thread::join $serverThread
}
