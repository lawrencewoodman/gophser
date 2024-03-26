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
namespace eval gophers::router {
  namespace export {[a-z]*}
  variable routes {}
}

# TODO: Restrict pattern
# TODO: Sort routes after adding from most specific to most general
proc gophers::router::route {pattern handlerName} {
  variable routes
  lappend routes [list $pattern [PathToRegex $pattern] $handlerName]
  Sort
}


# TODO: rename
# TODO: Assumes selector is safe at this point?
# Perhaps use namespace to determine whether input has been checked
proc gophers::router::getHandler {selector} {
  variable routes
  set selector [safeSelector $selector]
  foreach route $routes {
    # TODO: Rename handlerName?
    lassign $route - regex handlerName
    if {[regexp -- $regex $selector]} {
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
proc gophers::router::safeSelector {selectorPath} {
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



# TODO: Test
# TODO: Should we just use string match wildcards instead?
# Returns: regex
proc gophers::router::PathToRegex {path} {
  set regex "^$path\/?$"
  # Escape / and . in path for regex
  return [string map {"*" "(.*)" "/" "\\/" "." "\\."} $regex]
}


# Sort the routes from most specific to least specific
proc gophers::router::Sort {} {
  variable routes
  set routes [lsort -command CompareRoutes $routes]
}


# Compare the routes for lsort to determine which is most specific
proc gophers::router::CompareRoutes {a b} {
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
