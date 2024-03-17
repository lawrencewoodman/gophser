# Handle directory gophermap creation
# TODO: This is only a temporary name because it uses a very different
# TODO: format to standard gophermap files and therefore needs renaming
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

namespace eval gophermap {
  namespace export {[a-z]*}

  variable menu  
  # Sorted list of files found in the same directory as the gophermap
  variable files
  variable localDir
  variable selectorPath
}


proc gophermap::process {menuVar _files _localDir _selectorPath} {
  variable menu
  variable files
  variable localDir
  variable selectorPath

  upvar $menuVar menuVal
  set menu $menuVal
  set files $_files
  set localDir $_localDir
  set selectorPath $_selectorPath
  
  set interp [interp create -safe]
  $interp eval {unset {*}[info vars]}
  $interp alias menu gophermap::Menu
  # TODO: see if we can pass args to alias listFiles
  $interp alias listFiles gophermap::ListFiles
  $interp invokehidden source [file join $localDir $selectorPath gophermap]
  set menuVal $menu
}


proc gophermap::Menu {command args} {
  variable menu
  switch -- $command {
    item {
      # TODO: ensure can only include files in the current location?
      ::gophers::menu::item menu {*}$args
    }
    default {
      return -code error "menu: invalid command: $command"
    }
  }
}


proc gophermap::ListFiles {args} {
  variable menu
  variable files
  variable localDir
  variable selectorPath
  
  if {[llength $args]} {
    return -code error "listFiles: doesn't currently take any arguments"
  }
  ::gophers::listDir -nogophermap -files $files menu $localDir $selectorPath
}
