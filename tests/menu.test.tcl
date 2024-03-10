package require tcltest
namespace import tcltest::*

set ThisScriptDir [file dirname [info script]]
set RepoRootDir [file join $ThisScriptDir ..]

source [file join $RepoRootDir menu.tcl]
source [file join $ThisScriptDir test_helpers.tcl]


test render-1 {Check render adds correct .<cr><lf> ending to menu} \
-setup {
  set m [gophers::menu create]
  gophers::menu addMenu m "Somewhere interesting" "/interesting"
} -body {
  gophers::menu render $m
} -result [string cat \
  "1Somewhere interesting\t/interesting\tlocalhost\t70\r\n" \
  ".\r\n"]