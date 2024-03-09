package require tcltest
namespace import tcltest::*

set ThisScriptDir [file dirname [info script]]
set RepoRootDir [file join $ThisScriptDir ..]

source [file join $RepoRootDir gophers.tcl]
source [file join $ThisScriptDir test_helpers.tcl]


#TODO: Test thoroughly selector input using different line endings
#TODO: to make sure correct translation options are being used



test init-1 {Check can read menu from server} \
-setup {
  set configContent "mount \"[file normalize $RepoRootDir]\" \"/\""
  set serverThread [TestHelpers::startServer $configContent]
} -body {
  TestHelpers::gopherGet localhost 7070 "/tests/"
} -cleanup {
  TestHelpers::shutdownServer $serverThread]
} -result [string cat \
  "0gophers.test.tcl\t/tests/gophers.test.tcl\tlocalhost\t7070\r\n" \
  "0menu.test.tcl\t/tests/menu.test.tcl\tlocalhost\t7070\r\n" \
  "0router.test.tcl\t/tests/router.test.tcl\tlocalhost\t7070\r\n" \
  "1stress\t/tests/stress\tlocalhost\t7070\r\n" \
  "0test_helpers.tcl\t/tests/test_helpers.tcl\tlocalhost\t7070\r\n" \
  ".\r\n"]
