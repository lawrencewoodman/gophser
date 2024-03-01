package require Thread
package require tcltest
namespace import tcltest::*

set ThisScriptDir [file dirname [info script]]
set RepoRootDir [file join $ThisScriptDir ..]

source [file join $RepoRootDir gophers.tcl]
source [file join $ThisScriptDir test_helpers.tcl]


test init-1 {Check can read menu from server} \
-setup {
  set configContent "mount \"[file normalize $RepoRootDir]\" \"/\""
  set serverThread [TestHelpers::startServer $configContent]
} -body {
  lsort [split [TestHelpers::gopherGet localhost 7070 "/tests/"] "\n"]
} -cleanup {
  TestHelpers::shutdownServer $serverThread
} -result [list {} \
                "0gophers.test.tcl\t/tests/gophers.test.tcl\tlocalhost\t7070" \
                "0routing.test.tcl\t/tests/routing.test.tcl\tlocalhost\t7070" \
                "0test_helpers.tcl\t/tests/test_helpers.tcl\tlocalhost\t7070" \
                "1stress\t/tests/stress\tlocalhost\t7070"]
