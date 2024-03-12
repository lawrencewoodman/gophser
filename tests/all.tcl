package require Tcl 8.5
package require tcltest

set ThisScriptDir [file dirname [info script]]
set RepoRootDir [file join $ThisScriptDir ..]

tcltest::configure -testdir $ThisScriptDir
tcltest::configure {*}$argv
tcltest::runAllTests
