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
# funcArgs A list of arguments to use after the request when applying the func
# func     A function suitable for the apply command
proc gophser::router::route {pattern funcArgs func} {
  variable routes
  lappend routes [list $pattern $funcArgs $func]
  Sort
}


# TODO: rename
proc gophser::router::getHandler {selector} {
  variable routes
  foreach route $routes {
    lassign $route pattern funcArgs func
    if {[string match $pattern $selector]} {
      return [list $funcArgs $func]
    }
  }
  return {}
}


# Sort the routes from most specific to least specific
proc gophser::router::Sort {} {
  variable routes
  set routes [lsort -command CompareRoutes $routes]
}


# Compare the routes for lsort to determine which is most specific
# TODO: This compares assuming routes are based on paths whose components are
# TODO: joined with "/" - revisit this and test properly.
proc gophser::router::CompareRoutes {a b} {
  set patternPartsA [split [lindex $a 0] "/"]
  set patternPartsB [split [lindex $b 0] "/"]
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
