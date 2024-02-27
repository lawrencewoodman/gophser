# Handle Gopher Server Configuration
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#



proc gophers::loadConfig {filename} {
  variable interp
  set interp [interp create -safe]
  $interp eval {unset {*}[info vars]}

  $interp alias log gophers::log
  $interp alias mount gophers::mount
  $interp alias route gophers::safeRoute
  $interp alias sendText gophers::sendText

  $interp invokehidden source $filename

}

# TODO:need to define command so it is clear which are run as slave or master

# Logging command for safe interpreter
proc gophers::log {msg} {
  puts $msg
}


# TODO: make pattern safe
proc gophers::safeRoute {pattern handlerName} {
  variable interp
  urlrouter::route $pattern [list interp eval $interp [list $handlerName]]
}


# TODO: Ensure localDir isn't relative
proc gophers::mount {localDir urlPath} {
  set urlPath "[urlrouter::SafeURL $urlPath]*"

  if {![file exists $localDir]} {
    error "local directory doesn't exist: $localDir"
  }

  if {![file isdirectory $localDir]} {
    error "local directory isn't a directory: $localDir"
  }

  urlrouter::route $urlPath [list gophers::serveDir $localDir]
}
