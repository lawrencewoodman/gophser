package require Tcl 8.5
package require tcltest

apply {{argv} {
  set thisScriptDir [file dirname [info script]]
  tcltest::configure -testdir $thisScriptDir
  tcltest::configure {*}$argv
  tcltest::runAllTests
}} $argv
