# Handle directory gophermap creation
# TODO: This is only a temporary name because it uses a very different
# TODO: format to standard gophermap files and therefore needs renaming
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#


namespace eval gophser::gophermap {
  namespace export {[a-z]*}

  variable menu
  variable descriptions
}


proc gophser::gophermap::process {_menu localDir selectorMountPath selectorSubPath} {
  variable menu
  variable descriptions

  set menu $_menu
  set selectorLocalDir [::gophser::MakeSelectorLocalPath $localDir $selectorSubPath]
  set descriptions [dict create]

  set interp [interp create -safe]
  $interp eval {unset {*}[info vars]}
  $interp alias menu ::gophser::gophermap::Menu
  $interp alias describe ::gophser::gophermap::Describe
  $interp alias dir ::gophser::gophermap::Dir $localDir $selectorMountPath $selectorSubPath
  set gophermapPath [file join $selectorLocalDir gophermap]
  if {[catch {$interp invokehidden source $gophermapPath}]} {
    return -code error "error processing: $gophermapPath, for selector: [file join $selectorMountPath $selectorSubPath], $::errorInfo"
  }
  return $menu
}


proc gophser::gophermap::Menu {command args} {
  variable menu
  switch -- $command {
    info {
      set menu [::gophser::menu::info $menu {*}$args]
    }
    text {
      # TODO: ensure can only include files in the current location?
      set menu [::gophser::menu::item $menu text {*}$args]
    }
    menu {
      # TODO: ensure can only include files in the current location?
      set menu [::gophser::menu::item $menu menu {*}$args]
    }
    default {
      return -code error "menu: invalid command: $command"
    }
  }
}


# TODO: Be able to add extra info next to filename such as size and date
proc gophser::gophermap::Describe {filename description} {
  variable descriptions
  dict set descriptions $filename $description
}


# Display the files in the current directory
proc gophser::gophermap::Dir {localDir selectorMountPath selectorSubPath} {
  variable menu
  variable descriptions

  set menu [::gophser::ListDir -descriptions $descriptions \
                               $menu $localDir \
                               $selectorMountPath $selectorSubPath]
}
