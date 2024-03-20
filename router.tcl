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
  set route [NewRoute $pattern]
  lappend routes [list {*}$route $handlerName]
}


# TODO: rename
# TODO: Assumes selector is safe at this point?
# Perhaps use namespace to determine whether input has been checked
proc gophers::router::getHandlerInfo {selector} {
  variable routes
  set selector [safeSelector $selector]
  foreach route $routes {
    # TODO: Rename handlerName?
    lassign $route pattern regex keys handlerName
    set matches [regexp -all -inline -- $regex $selector]
    if {$matches ne {}} {
      return [list $handlerName $matches]
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


proc gophers::router::NewRoute {pattern} {
  lassign [PathToRegex $pattern] regex keys
  return [list $pattern $regex $keys]
}


# TODO: Should * only be allowed at the end?
# TODO: Test
# Returns: {regex keys}
proc gophers::router::PathToRegex {path} {
  set keys [regexp -all -inline -- "\{.*?\}" $path]
  set regex "^$path\/?$"
  # Escape / and . in path for regex
  set regex [string map {"*" "(.*)" "/" "\\/" "." "\\."} $regex]
  set regex [regsub -all "\{.*?\}" $regex {([^\\/]+)}]
  return [list $regex $keys]
}
