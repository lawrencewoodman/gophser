# Helper commands
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#
# TODO: Put these somewhere else, only here to help cleanup and organize
# TODO: the code - also have tests for this file in helpers.test

# mount localDir selectorMountPath
#
# localDir: The local absolute directory path
# selectorMountPath: The path for the selector which must not contain wildcards
#  TODO: Strip trailing slash on selectorMountPath and test
proc gophser::mount {localDir selectorMountPath} {
  set localDir [string trim $localDir]
  set selectorMountPath [selectorToSafeFilePath $selectorMountPath]

  if {$localDir eq ""} {
    return -code error "local dir blank"
  }
  if {[string index $localDir 0] ne "/"} {
    return -code error "can not mount relative directories: $localDir"
  }

  set localDir [file normalize $localDir]

  if {![file exists $localDir]} {
    return -code error "local directory doesn't exist: $localDir"
  }

  if {![file isdirectory $localDir]} {
    return -code error "local directory isn't a directory: $localDir"
  }

  if {[string match {*[*?]*} $selectorMountPath] ||
      [string match {*\[*} $selectorMountPath] ||
      [string match {*\]*} $selectorMountPath]} {
    return -code error "selector can not contain wildcards"
  }

  # TODO: relook at whether safeSelector use is appropriate here
  if {$selectorMountPath eq "/"} {
    set selectorMountPathGlob "*"
  } else {
    set selectorMountPathGlob "$selectorMountPath/*"
  }

  # Match with and without trailing slash
  set routeArgs [list $localDir $selectorMountPath]
  route $selectorMountPath $routeArgs {{request localDir selectorMountPath} {
    gophser::ServePath $request $localDir $selectorMountPath
  }}
  route $selectorMountPathGlob $routeArgs {{request localDir selectorMountPath} {
    gophser::ServePath $request $localDir $selectorMountPath
  }}
}


proc gophser::provideLinkDir {directoryDB selectorMountPath} {
  if {[string match {*[*?]*} $selectorMountPath] ||
      [string match {*\[*} $selectorMountPath] ||
      [string match {*\]*} $selectorMountPath]} {
    return -code error "selector can not contain wildcards"
  }

  # TODO: relook at whether safeSelector use is appropriate here
  if {$selectorMountPath eq "/"} {
    set selectorMountPathGlob "*"
  } else {
    set selectorMountPathGlob "$selectorMountPath/*"
  }
  # TODO: Find a better way of doing this
  set routeArgs [list $directoryDB $selectorMountPath]
  route $selectorMountPath $routeArgs {{request directoryDB selectorMountPath} {
    gophser::ServeLinkDirectory $request $directoryDB $selectorMountPath
  }}
  route $selectorMountPathGlob $routeArgs {{request directoryDB selectorMountPath} {
    gophser::ServeLinkDirectory $request $directoryDB $selectorMountPath
  }}
}


# Turns a selector into a safe file path
# It is important that selectors are passed through this before being used
# as a file path.
# TODO: Only allow absolute paths
# TODO: Strip out anything including and past a tab
# Convert spaces to % notation
# Resolves .. without going past root of path
# Removes . directory element
# Supports directory elements beginning with ~
# This ensures there is a leading "/"
# TODO: Put this in a collection of safety functions
proc gophser::selectorToSafeFilePath {selector} {
  set selector [string map {" " "%20"} $selector]
  set elements [file split $selector]
  set path [list]
  foreach e $elements {
    if {$e eq ".."} {
      set path [lreplace $path end end]
    } elseif {$e ne "." && $e ne "/"} {
      if {[string match {./*} $e]} {
        set e [string range $e 2 end]
      }
      lappend path $e
    }
  }

  if {[llength $path] == 0} {
    return {/}
  }

  return "/[file join {*}$path]"
}


# Remove the prefix from the selector
# This is useful to remove mount points and to access variables
# passed in the selector path.
# TODO: Should this be exported?
proc gophser::stripSelectorPrefix {prefix selector} {
  if {![regexp "^${prefix}(.*)$" $selector - subSelector]} {
    return -code error "selector: $selector does not contain prefix: $prefix"
  }
  return $subSelector
}


# TODO: Work out at what point the sub path is safe
proc gophser::MakeSelectorLocalPath {localDir selectorSubPath} {
  set localDir [string trimleft $localDir "."]
  set localDir [file normalize $localDir]
  return [file join $localDir $selectorSubPath]
}


# TODO: define using dict getdef if present
proc gophser::DictGetDef {dictionaryValue args} {
  if {[llength $args] < 2} {
    return -code "wrong # args: should be \"DictGetDef dictionaryValue ?key ...? key default\""
  }
  set default [lindex $args end]
  set keys [lrange $args 0 end-1]
  if {[dict exists $dictionaryValue {*}$keys]} {
    return [dict get $dictionaryValue {*}$keys]
  }
  return $default
}


# listDir ?switches? menu localDir selectorMountPath selectorSubPath
# switches:
#  -descriptions descriptions  Dictionary of descriptions for each filename
#
# arguments:
#   selectorSubPath  must be a relative math
#
# Creates menu items for each file/dir in directory
# Entries are sorted alphabetically with directories proceeding files
#
# TODO: Make this safer and suitable for running as master command from interpreter
# TODO: Restrict directories and look at permissions (world readable?)
proc gophser::ListDir {args} {
  array set options {}
  while {[llength $args]} {
    switch -glob -- [lindex $args 0] {
      -descriptions {set args [lassign $args - options(descriptions)]}
      --      {set args [lrange $args 1 end] ; break}
      -*      {return -code error "unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] != 4} {
    return -code error "invalid number of arguments"
  }
  if {[info exists options(descriptions)]} {
    set descriptions $options(descriptions)
  } else {
    set descriptions [dict create]
  }

  lassign $args menu localDir selectorMountPath selectorSubPath
  set selectorLocalDir [MakeSelectorLocalPath $localDir $selectorSubPath]
  set dirs [glob -tails -type d -nocomplain -directory $selectorLocalDir *]
  set dirs [lsort -nocase $dirs]
  set files [glob -tails -type f -nocomplain -directory $selectorLocalDir *]
  set files [lsort -nocase $files]

  set prevFileDescribed false   ; # This prevents a double proceeding new line
  foreach entriesDF [list [list d $dirs] [list f $files]] {
    lassign $entriesDF type entries
    foreach localName $entries {
      # TODO: Rename gophermap?
      if {$localName eq "gophermap"} {
        continue
      }
      set description [DictGetDef $descriptions $localName description ""]
      set username [DictGetDef $descriptions $localName username $localName]

      # If a description exists then put a blank line before file
      if {!$prevFileDescribed && $description ne ""} {
        set menu [menu info $menu ""]
        set prevFileDescribed true
      } else {
        set prevFileDescribed false
      }

      set selector [MakeSelectorPath $selectorMountPath $selectorSubPath $localName]
      if {$type eq "f"} {
        set menu [menu item $menu text $username $selector]
      } else {
        # Directory
        set menu [menu item $menu menu $username $selector]
      }

      # If a description exists then put it after the file
      if {$description ne ""} {
        set menu [menu info $menu $description]
        set menu [menu info $menu ""]
      }
    }
  }
  return $menu
}


# Join path components to make a selector path beginning with "/" and with
# each component joined with "/"
# TODO: rename and test
proc gophser::MakeSelectorPath {args} {
  return "/[string trimleft [join [concat {*}$args] "/"] "/"]"
}

