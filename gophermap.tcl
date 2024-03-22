# Handle directory gophermap creation
# TODO: This is only a temporary name because it uses a very different
# TODO: format to standard gophermap files and therefore needs renaming
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#


namespace eval gophers::gophermap {
  namespace export {[a-z]*}

  variable menu  
  # Sorted list of files found in the same directory as the gophermap
  variable files
  variable localDir
  variable selectorPath
  variable descriptions
}


proc gophers::gophermap::process {_menu _files _localDir _selectorPath} {
  variable menu
  variable files
  variable localDir
  variable selectorPath
  variable descriptions

  set menu $_menu
  set files $_files
  set localDir $_localDir
  set selectorPath $_selectorPath
  
  set descriptions [dict create]

  set interp [interp create -safe]
  $interp eval {unset {*}[info vars]}
  $interp alias menu ::gophers::gophermap::Menu
  $interp alias describe ::gophers::gophermap::Describe
  $interp alias listFiles ::gophers::gophermap::ListFiles
  $interp invokehidden source [file join $localDir $selectorPath gophermap]
  return $menu
}


proc gophers::gophermap::Menu {command args} {
  variable menu
  switch -- $command {
    item {
      # TODO: ensure can only include files in the current location?
      set menu [::gophers::menu::item $menu {*}$args]
    }
    default {
      return -code error "menu: invalid command: $command"
    }
  }
}


# TODO: Be able to add extra info next to filename such as size and date
proc gophers::gophermap::Describe {filename description} {
  variable descriptions
  dict set descriptions $filename $description
}


proc gophers::gophermap::ListFiles {} {
  variable menu
  variable files
  variable localDir
  variable selectorPath
  variable descriptions
  
  set menu [::gophers::ListDir -nogophermap -files $files \
                               -descriptions $descriptions \
                               $menu $localDir $selectorPath]
}
