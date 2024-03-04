# Handle Gopher Server Configuration
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

namespace eval config {
  namespace export {[a-z]*}
  variable interp
  variable options
  variable routes {}
}

# TODO: Find a cleaner way of referring to gophers::
# TODO: for sendText and serveDir

proc config::load {filename} {
  variable interp
  variable options [dict create logger [dict create suppress none]]
  set interp [interp create -safe]
  $interp eval {unset {*}[info vars]}

  $interp alias log config::log
  $interp alias mount config::mount
  $interp alias route config::route
  $interp alias sendText gophers::sendText

  $interp invokehidden source $filename
  return $options
}

# TODO:need to define command so it is clear which are run as slave or master

# Logging command for safe interpreter
# TODO: Consider basing off log tcllib package
proc config::log {command args} {
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
proc config::route {pattern handlerName} {
  variable interp
  # TODO: make numRoutes cleaner
  set numRoutes [llength $router::routes]
  proc ::config::handleRoute$numRoutes {interp handlerName selector args} {
    set res [interp eval $interp [list $handlerName] $selector $args]
    return [list text $res]
  }
  router::route $pattern [list ::config::handleRoute$numRoutes $interp $handlerName]
}


# TODO: Ensure localDir isn't relative
proc config::mount {localDir selectorPath} {
  set selectorPath "[router::safeSelector $selectorPath]*"

  if {![file exists $localDir]} {
    error "local directory doesn't exist: $localDir"
  }

  if {![file isdirectory $localDir]} {
    error "local directory isn't a directory: $localDir"
  }

  router::route $selectorPath [list gophers::serveDir $localDir]
}
