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

# TODO: Restrict pattern
# TODO: Sort routes after adding from most specific to most general
proc urlrouter::route {pattern handlerName} {
  variable routes
  set route [NewRoute $pattern]
  lappend routes [list {*}$route $handlerName]
}


# TODO: rename
# Assumes url is safe at this point
# Perhaps use namespace to determine whether input has been checked
proc urlrouter::getHandlerInfo {url} {
  variable routes
  set url [SafeURL $url]
  foreach route $routes {
    # TODO: Rename handlerName?
    lassign $route pattern regex keys handlerName
    set matches [regexp -all -inline -- $regex $url]
    if {$matches ne {}} {
      return [list $handlerName $matches]
    }
  }
  return {}
}


proc urlrouter::NewRoute {pattern} {
  lassign [PathToRegex $pattern] regex keys
  return [list $pattern $regex $keys]
}


# Returns a safe URL
# TODO: Only allow absolute urlPaths
# TODO: Convert tabs to % notation?
# Convert spaces to % notation
# Resolves .. without going past root of url
# Removes . directory element
# Supports directory elements beginning with ~
proc urlrouter::SafeURL {urlPath} {
  set urlPath [string map {" " "%20"} $urlPath]
  set elements [file split $urlPath]
  set newURLPath [list]
  foreach e $elements {
    if {$e eq ".."} {
      set newURLPath [lreplace $newURLPath end end]
    } elseif {$e ne "." && $e ne "/"} {
      if {[string match {./*} $e]} {
        set e [string range $e 2 end]
      }
      lappend newURLPath $e
    }
  }
  return "\/[join $newURLPath "/"]"
}


# TODO: Should * only be allowed at the end?
# TODO: Test
# Returns: {regex keys}
proc urlrouter::PathToRegex {path} {
  set keys [regexp -all -inline -- "\{.*?\}" $path]
  set regex "^$path\/?$"
  # Escape / and . in path for regex
  set regex [string map {"*" "(.*)" "/" "\\/" "." "\\."} $regex]
  set regex [regsub -all "\{.*?\}" $regex {([^\\/]+)}]
  return [list $regex $keys]
}
