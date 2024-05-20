# Define routes and route selectors to handlers
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

# TODO: add Middleware? for logging, doubledot path protection
# TODO: Enforce only being able to load world readable files that aren't executable?
# TODO: Handle trailing slashes


# TODO: Think about name format and rename file?
namespace eval gophser::router {
  namespace export {[a-z]*}
  variable routes {}
}

# TODO: Restrict pattern and make safe
# TODO: Sort routes after adding from most specific to most general
proc gophser::router::route {pattern handlerName} {
  variable routes
  lappend routes [list $pattern $handlerName]
  Sort
}


# TODO: rename
# TODO: Assumes selector is safe at this point?
# Perhaps use namespace to determine whether input has been checked
proc gophser::router::getHandler {selector} {
  variable routes
  set selector [safeSelector $selector]
  foreach route $routes {
    # TODO: Rename handlerName?
    lassign $route pattern handlerName
    if {[string match $pattern $selector]} {
      return $handlerName
    }
  }
  return {}
}


# Returns a safer version of the selector path
# TODO: Only allow absolute paths
# TODO: Convert tabs to % notation?
# Convert spaces to % notation
# Resolves .. without going past root of path
# Removes . directory element
# Supports directory elements beginning with ~
# TODO: Should probably change this to safeFilePath and move it somewhere else
proc gophser::router::safeSelector {selectorPath} {
  # TODO: Work out how safe this selector really is
  # TODO: and whether this should be done at this
  # TODO: point or when actually handling file
  # TODO: path
  if {[string match {URL:*} $selectorPath]} {
    return [string trim $selectorPath]
  }
  set selectorPath [string map {" " "%20"} $selectorPath]
  set elements [file split $selectorPath]
  set newSelectorPath [list]
  foreach e $elements {
    if {$e eq ".."} {
      set newSelectorPath [lreplace $newSelectorPath end end]
    } elseif {$e ne "." && $e ne "/"} {
      if {[string match {./*} $e]} {
        set e [string range $e 2 end]
      }
      lappend newSelectorPath $e
    }
  }
  return "\/[join $newSelectorPath "/"]"
}


# Sort the routes from most specific to least specific
proc gophser::router::Sort {} {
  variable routes
  set routes [lsort -command CompareRoutes $routes]
}


# Compare the routes for lsort to determine which is most specific
proc gophser::router::CompareRoutes {a b} {
  set patternPartsA [file split [lindex $a 0]]
  set patternPartsB [file split [lindex $b 0]]
  foreach partA $patternPartsA partB $patternPartsB {
    if {$partA ne $partB} {
      if {$partA eq "*"} { return 1 }
      if {$partB eq "*"} { return -1 }
      if {$partA eq ""}  { return 1 }
      if {$partB eq ""}  { return -1 }
    }
  }
  return 0
}
