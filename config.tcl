# Handle Gopher Server Configuration
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

namespace eval gophers::config {
  namespace export {[a-z]*}
  variable interp
  variable options
  variable routes {}
}

# TODO: Find a cleaner way of referring to gophers::
# TODO: for sendText and serveDir

proc gophers::config::load {filename} {
  variable interp
  variable options [dict create logger [dict create suppress none]]
  set interp [interp create -safe]
  $interp eval {unset {*}[info vars]}

  $interp alias log ::gophers::config::Log
  $interp alias mount ::gophers::config::Mount
  $interp alias route ::gophers::config::Route
  $interp alias sendText ::gophers::sendText

  $interp invokehidden source $filename
  return $options
}

# TODO:need to define command so it is clear which are run as slave or master

# Logging command for safe interpreter
# TODO: Consider basing off log tcllib package
proc gophers::config::Log {command args} {
  variable options
  # TODO: Think about what to use for reporting (info?)
  # TODO: Pay attention to suppress in info
  switch -- $command {
    info {
      puts [lindex $args 0]
    }
    suppress {
      # TODO: Improve error handling
      dict set options logger suppress [lindex $args 0]
    }
    default {
      return -code error "invalid command for log: $command"
    }
  }
}


# TODO: make pattern safe
proc gophers::config::Route {pattern handlerName} {
  variable interp
  # TODO: make numRoutes cleaner
  set numRoutes [llength $::gophers::router::routes]
  proc ::gophers::config::handleRoute$numRoutes {interp handlerName selector args} {
    set res [interp eval $interp [list $handlerName] $selector $args]
    return [list text $res]
  }
  ::gophers::router::route $pattern [list ::gophers::config::handleRoute$numRoutes $interp $handlerName]
}


# TODO: Ensure localDir isn't relative
proc gophers::config::Mount {localDir selectorPath} {
  set selectorPath "[::gophers::router::safeSelector $selectorPath]*"

  if {![file exists $localDir]} {
    error "local directory doesn't exist: $localDir"
  }

  if {![file isdirectory $localDir]} {
    error "local directory isn't a directory: $localDir"
  }

  ::gophers::router::route $selectorPath [list gophers::serveDir $localDir]
}
