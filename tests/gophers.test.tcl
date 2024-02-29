package require Thread
package require tcltest
namespace import tcltest::*

set ThisScriptDir [file dirname [info script]]
set RepoRootDir [file join $ThisScriptDir ..]

source [file join $RepoRootDir gophers.tcl]


# TODO: Rename main
test init-1 {Check can read menu from server} \
-setup {
  # Create Gopher server
  set t1 [thread::create -joinable {
    vwait RepoRootDir
    source [file join $RepoRootDir gophers.tcl]
    set fd [file tempfile tmpConfigFilename "gopher_config.test"]
    puts $fd "mount \"[file normalize $RepoRootDir]\" \"/\""
    close $fd
    gophers::init $tmpConfigFilename
    vwait isRunning
    vwait forever
    gophers::shutdown
  }]
  # Use client to make a request
  set t2 [thread::create -joinable {
    vwait ThisScriptDir
    source [file join $ThisScriptDir test_helpers.tcl]
    vwait urlPath
    set gopherData [TestHelpers::gopherGet 7070 $urlPath]
    thread::wait
  }]

  proc startServer {} {
    global RepoRootDir
    global t1
    thread::send -async $t1 [list set RepoRootDir $RepoRootDir]
    thread::send $t1 [list set isRunning 1]
  }

  proc shutdownServer {} {
    global t1
    thread::send -async $t1 [list set forever done]
    thread::join $t1
  }

  proc getGopherSelector {urlPath} {
    global ThisScriptDir
    global t2
    thread::send -async $t2 [list set ThisScriptDir $ThisScriptDir]
    thread::send -async $t2 [list set urlPath $urlPath]
    thread::send $t2 [list set gopherData] gopherData
    thread::release $t2
    thread::join $t2
    return $gopherData
  }
  startServer
} -body {
  lsort [split [getGopherSelector "/tests/"] "\n"]
} -cleanup {
  shutdownServer
} -result [list {} \
                "0gophers.test.tcl\t/tests/gophers.test.tcl\tlocalhost\t7070" \
                "0routing.test.tcl\t/tests/routing.test.tcl\tlocalhost\t7070" \
                "0test_helpers.tcl\t/tests/test_helpers.tcl\tlocalhost\t7070" \
                "1stress\t/tests/stress\tlocalhost\t7070"]
