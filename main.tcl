# A Gopher Server
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

source "gophers.tcl"

proc main {params} {
  if {[llength $params] != 1} {
    error "must supply config filename"
  }
  set configFilename [lindex $params 0]
  gophers::init $configFilename
  vwait forever
  gophers::shutdown
}

main $argv
