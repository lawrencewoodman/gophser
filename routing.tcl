# Routes to Define and Handle URL Routes
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

# TODO: add Middleware? for logging, doubledot path protection
# TODO: Enforce only being able to load world readable files that aren't executable?
# TODO: Handle trailing slashes


# TODO: Think about name format and rename file?
namespace eval urlrouter {
  namespace export {[a-z]*}
  namespace ensemble create
  # The normal number of safe interpreters ready for use
  variable routes {}
}

# TOOD: Restrict pattern
proc urlrouter::route {pattern handlerName} {
  variable routes
  set route [NewRoute $pattern]
  lappend routes [list {*}$route $handlerName]
}


proc urlrouter::handleURL {interp sock url} {
  variable routes
  set url [NormalizeURL $url]
  foreach route $routes {
    lassign $route pattern regex keys handlerName
    set matches [regexp -all -inline -- $regex $url]
    if {$matches ne {}} {
      # TODO: Find a cleaner way of doing this
      $interp eval [list $handlerName $sock {*}$matches]
      return true
    }
  }
  return false
}


proc urlrouter::NewRoute {pattern} {
  lassign [PathToRegex $pattern] regex keys
  return [list $pattern $regex $keys]
}


# Returns safe URL by resolving . and .. no further than the root of the given URL
# TODO: Test thoroughly
# TODO: Perhaps rename to show that it is making the url safe
proc urlrouter::NormalizeURL {url} {
  set url [file normalize [string trimleft $url "."]]
}


# TODO: Should * only be allowed at the end?
# Returns: {regex keys}
proc urlrouter::PathToRegex {path} {
  set keys [regexp -all -inline -- "\{.*?\}" $path]
  set regex "^$path\/?$"
  # Escape / and . in path for regex
  set regex [string map {"*" "(.*)" "/" "\\/" . "\\."} $regex]
  set regex [regsub -all "\{.*?\}" $regex {([^\\/]+)}]
  return [list $regex $keys]
}
