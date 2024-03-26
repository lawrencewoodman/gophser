#!/usr/bin/env tclsh
#
# A Gopher Server Program
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

source "gophers.tcl"

proc main {params} {
  set port 7070
  set thisScriptDir [file dirname [info script]]
  set repoRootDir [file join $thisScriptDir ..]
  gophers::route "/say/{word}" sendWord
  gophers::mount [file normalize $repoRootDir] "/"
  gophers::init $port 
  vwait forever
  gophers::shutdown
}


proc sendWord {selector args} {
  return [list text [string map {"%20" " "} $args]]
}


main $argv
