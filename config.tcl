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

  $interp alias file gophers::safeFile
  $interp alias log gophers::log
  $interp alias listDir gophers::listDir
  $interp alias mount gophers::mount
  # TODO: Ensure this is wrapped so can only read world readable and with a specified path?
  $interp alias readFile gophers::readFile
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


proc gophers::safeFile {command args} {
  # TODO: Consider how safe isfile and isdirectory is to be used and whether we should check first that it is world
  # TODO: readable - also whether we should be using {*} before args
  # TODO: Try and restrict this as much as possible
  switch $command {
    dirname { return [::file dirname {*}$args] }
    isfile { return [::file isfile {*}$args] }
    isdirectory { return [::file isdirectory {*}$args] }
    join { return [::file join {*}$args] }
    tail { return [::file tail {*}$args] }
    default {
      return -code error "invalid command for file: $command"
    }
  }
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

  set localDirPermissions [file attributes $localDir -permissions]
  if {$localDirPermissions & 4 != 4} {
    error "local directory isn't world readable: $localDir"
  }

  urlrouter::route $urlPath [list gophers::serveDir $localDir]
}


# To run handleURL within the safe interpreter
# TODO: report better errors incase handler returns and error
proc gophers::handleURL {sock url} {
  variable interp
  set handlerInfo [urlrouter::getHandlerInfo $url]
  if {$handlerInfo ne {}} {
    lassign $handlerInfo handlerScript params
    {*}$handlerScript $sock {*}$params
    return true
  } else {
    return false
  }
}
