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
  variable databases [dict create]
}


proc gophser::gophermap::process {_menu localDir selector selectorMountPath selectorSubPath} {
  variable menu
  variable descriptions

  set menu $_menu
  set selectorLocalDir [::gophser::MakeSelectorLocalPath $localDir $selectorSubPath]
  set descriptions [dict create]

  set interp [interp create -safe]

  # Remove all the variables and commands from the interpreter
  $interp eval {unset {*}[info vars]}
  foreach command [$interp eval {info commands}] {
    $interp hide $command
  }

  $interp alias desc ::gophser::gophermap::Describe
  $interp alias dir ::gophser::gophermap::Dir $localDir $selectorMountPath $selectorSubPath
  $interp alias h1 ::gophser::gophermap::H1
  $interp alias h2 ::gophser::gophermap::H2
  $interp alias h3 ::gophser::gophermap::H3
  $interp alias info ::gophser::gophermap::Info
  $interp alias item ::gophser::gophermap::Item
  $interp alias log ::gophser::gophermap::Log
  $interp alias url ::gophser::gophermap::Url

  set gophermapPath [file join $selectorLocalDir gophermap]
  try {
    $interp invokehidden source $gophermapPath
  } on error err {
    return -code error "error processing: $gophermapPath, for selector: $selector, $err"
  }

  return $menu
}


# TODO: Rethink this
# TODO: Should probably turn the args into vars before passing to maintain interface
proc gophser::gophermap::Item {command args} {
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
proc gophser::gophermap::Describe {filename userName {description {}}} {
  variable descriptions
  if {$userName eq ""} {set userName $filename}
  dict set descriptions $filename [list $userName $description]
}


proc gophser::gophermap::H1 {text} {
  set textlen [string length $text]
  if {$textlen > 65} {
    # TODO: Generate a warning
  }
  # TODO: Should we call menu:: directory for H1, H2 and H3
  Item info [string repeat "=" [expr {$textlen+4}]]
  Item info "= $text ="
  Item info [string repeat "=" [expr {$textlen+4}]]
  Item info ""
}


proc gophser::gophermap::H2 {text} {
  set textlen [string length $text]
  if {$textlen > 69} {
    # TODO: Generate a warning
  }
  set underlineCh "="

  Item info $text
  Item info [string repeat $underlineCh $textlen]
  Item info ""
}


proc gophser::gophermap::H3 {text} {
  set textlen [string length $text]
  if {$textlen > 69} {
    # TODO: Generate a warning
  }
  set underlineCh "-"

  Item info $text
  Item info [string repeat $underlineCh $textlen]
  Item info ""
}


proc gophser::gophermap::Info {text} {
  variable menu
  set menu [::gophser::menu::info $menu $text]
}


# Display the files in the current directory
proc gophser::gophermap::Dir {localDir selectorMountPath selectorSubPath} {
  variable menu
  variable descriptions
  set menu [::gophser::ListDir -descriptions $descriptions \
                               $menu $localDir \
                               $selectorMountPath [string trimleft $selectorSubPath "/"]]
}


# TODO: Test this and check this is the form we would like to use in a gophermap
# TODO: Should probably turn the args into vars before passing to maintain interface
proc gophser::gophermap::Log {command args} {
  gophser::log $command {*}$args
}


proc gophser::gophermap::Url {userName url } {
  variable menu
  set menu [::gophser::menu::url $menu $userName $url]
}
