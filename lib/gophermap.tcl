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
  variable includeDir [list]
}


# TODO: This or pass config to process?
proc gophser::gophermap::setIncludeDir {_includeDir} {
  variable includeDir
  set includeDir $_includeDir
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
  $interp alias header ::gophser::gophermap::Header
  $interp alias source ::gophser::gophermap::Source $interp

  set gophermapPath [file join $selectorLocalDir gophermap]
  if {[catch {$interp invokehidden source $gophermapPath} err]} {
    return -code error "error processing: $gophermapPath, for selector: [file join $selectorMountPath $selectorSubPath], $err"
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
proc gophser::gophermap::Describe {filename userName {description {}}} {
  variable descriptions
  if {$userName eq ""} {set userName $filename}
  dict set descriptions $filename [list $userName $description]
}


proc gophser::gophermap::Header {level text} {
  set textlen [string length $text]
  if {$level == 1} {
    if {$textlen > 65} {
      # TODO: Generate a warning
    }
    Menu info [string repeat "=" [expr {$textlen+4}]]
    Menu info "= $text ="
    Menu info [string repeat "=" [expr {$textlen+4}]]
    Menu info ""
    return
  } elseif {$level == 2} {
    set underlineCh "="
  } elseif {$level == 3} {
    set underlineCh "-"
  } else {
    return -code "invalid header level"
  }

  if {$textlen > 69} {
    # TODO: Generate a warning
  }
  Menu info $text
  Menu info [string repeat $underlineCh $textlen]
  Menu info ""
}


# Display the files in the current directory
proc gophser::gophermap::Dir {localDir selectorMountPath selectorSubPath} {
  variable menu
  variable descriptions

  set menu [::gophser::ListDir -descriptions $descriptions \
                               $menu $localDir \
                               $selectorMountPath $selectorSubPath]
}


proc gophser::gophermap::Source {interp filename} {
  variable includeDir
  # TODO: Make sure filename doesn't include .. to allow moving outside of include path
  set fullFilename [file join $includeDir $filename]
  set isErr [catch {
    set fd [open $fullFilename r]
    set src [::read $fd]
    close $fd
  } err]
  if {$isErr} {
    # TODO: Could this reveal the whole path to filename and do we want this?
    # TODO: Log this error
    return -code error $err
  }
  # TODO: Test what this returns and return errors properly
  return [$interp eval $src]
}

