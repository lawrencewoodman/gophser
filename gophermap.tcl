# Handle directory gophermap creation
# TODO: This is only a temporary name because it uses a very different
# TODO: format to standard gophermap files and therefore needs renaming
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

# TODO: Move this under gophers::
namespace eval gophermap {
  namespace export {[a-z]*}

  variable menu  
  # Sorted list of files found in the same directory as the gophermap
  variable files
  variable localDir
  variable selectorPath
  variable descriptions
}


proc gophermap::process {menuVar _files _localDir _selectorPath} {
  variable menu
  variable files
  variable localDir
  variable selectorPath
  variable descriptions

  upvar $menuVar menuVal
  set menu $menuVal
  set files $_files
  set localDir $_localDir
  set selectorPath $_selectorPath
  
  set descriptions [dict create]

  set interp [interp create -safe]
  $interp eval {unset {*}[info vars]}
  $interp alias menu gophermap::Menu
  $interp alias describe gophermap::Describe
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


# TODO: Be able to add extra info next to filename such as size and date
proc gophermap::Describe {filename description} {
  variable descriptions
  dict set descriptions $filename $description
}


proc gophermap::ListFiles {args} {
  variable menu
  variable files
  variable localDir
  variable selectorPath
  variable descriptions
  
  if {[llength $args]} {
    return -code error "listFiles: doesn't currently take any arguments"
  }
  ::gophers::listDir -nogophermap -files $files -descriptions $descriptions \
                     menu $localDir $selectorPath
}
