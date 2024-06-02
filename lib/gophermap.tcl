# Handle directory gophermap creation
# TODO: This is only a temporary name because it uses a very different
# TODO: format to standard gophermap files and therefore needs renaming
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

package require hetdb

namespace eval gophser::gophermap {
  namespace export {[a-z]*}

  variable menu
  variable descriptions
  variable includeDir [list]
  variable databases [dict create]
}


# TODO: This or pass config to process?
proc gophser::gophermap::setIncludeDir {_includeDir} {
  variable includeDir
  set includeDir $_includeDir
}


# TODO: This or pass config to process?
proc gophser::gophermap::addDatabase {filename nickname} {
  variable databases
  if {[catch {hetdb read $filename} db]} {
    return -code error $db
  }
  dict set databases $nickname $db
}


proc gophser::gophermap::process {_menu localDir selector selectorMountPath selectorSubPath} {
  variable menu
  variable descriptions

  set menu $_menu
  set selectorLocalDir [::gophser::MakeSelectorLocalPath $localDir $selectorSubPath]
  set descriptions [dict create]

  set interp [interp create -safe]
  $interp eval {unset {*}[info vars]}

  $interp alias menu ::gophser::gophermap::Menu
  $interp alias describe ::gophser::gophermap::Describe
  # TODO: Should dir be part of menu and there also be another dir for returning the directory entries?
  $interp alias dir ::gophser::gophermap::Dir $localDir $selectorMountPath $selectorSubPath
  $interp alias header ::gophser::gophermap::Header
  $interp alias source ::gophser::gophermap::Source $interp
  $interp alias db ::gophser::gophermap::Db $interp
  $interp alias log ::gophser::gophermap::Log

  set gophermapPath [file join $selectorLocalDir gophermap]
  if {[catch {$interp invokehidden source $gophermapPath} err]} {
    return -code error "error processing: $gophermapPath, for selector: $selector, $err"
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
    url {
      set menu [::gophser::menu::url $menu {*}$args]
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


# TODO: Test thoroughly
# TODO: Find way to not have to rely on hetdb, instead allow calling code to
# TODO: make that connection to a database
proc gophser::gophermap::Db {interp command args} {
  switch -- $command {
    for {
      switch [llength $args] {
        4 {
          lassign $args db tablename fields body
          set varname $tablename
        }
        5 {
          lassign $args db tablename fields varname body
        }
        default {
          return -code error "wrong # args: should be \"db for db tablename fields ?varname? body\""
        }
      }
      set retcode [catch {
        hetdb for $db $tablename $fields row {
          # TODO: do we need list here?
          $interp eval [list set $varname $row]
          $interp eval $body
        }
      } res options]
      # TODO: test this works in the gophermap
      # Codes: 0 Normal return, 1 Error, 2 return command invoked
      #        3 break command invoked, 4 continue command invoked
      switch -- $retcode {
        0 -
        4       {}
        3       {return}
        default {return -code $retcode $res}
      }
    }
    open {
      variable databases
      if {[llength $args] != 1} {
        return -code error "wrong # args: should be \"db read dbname\""

      }
      lassign $args dbname
      if {$dbname ni $databases} {
        return -code error "database \"$dbname\" doesn't exist"
      }
      return [dict get $databases $dbname]
    }
    default {
      return -code error "unknown or ambiguous subcommand \""$command\"": must be for or read"
    }
  }
}


# TODO: Test this and check this is the form we would like to use in a gophermap
proc gophser::gophermap::Log {command args} {
  gophser::log $command {*}$args
}
