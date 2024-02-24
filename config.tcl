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

    # TODO: stop sourcing here, rather create a commmand route, make it
    # TODO: available to the safe interpreter and eval the handler in the
    # TODO: safe interpreter

    $interp alias file gophers::safeFile
    $interp alias log gophers::log
    $interp alias listDir gophers::listDir
    $interp alias root gophers::root
    # TODO: Ensure this is wrapped so can only read world readable and with a specified path?
    $interp alias readFile gophers::readFile
    $interp alias sendMessage gophers::sendMessage
    $interp alias route urlrouter::route

    $interp invokehidden source $filename

    # Later this may not be an issue but if it isn't set then need to
    # restrict other functionality
    if {$gophers::rootDir eq ""} {
        error "root directory hasn't been set"
    }

    if {![file exists $gophers::rootDir]} {
        error "root directory doesn't exist: $gophers::rootDir"
    }
    
    if {![file isdirectory $gophers::rootDir]} {
        error "root directory isn't a directory: $gophers::rootDir"
    }

    set rootDirPermissions [file attributes $gophers::rootDir -permissions]
    if {$rootDirPermissions & 4 != 4} {
        error "root directory isn't world readable: $gophers::rootDir"
    }
}

# TODO:need to define command so it is clear which are run as slave or master

# Logging command for safe interpreter
proc gophers::log {msg} {
    puts $msg
}

 proc gophers::safeFile {command args} {
    # TODO: Consider how safe isfile and isdirectory is to be used and whether we should check first that it is world
    # TODO: readable - also whether we should be using {*} before args
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


proc gophers::root {path} {
    variable rootDir
    set rootDir $path
}


# To run handleURL within the safe interpreter
proc gophers::handleURL {sock url} {
    variable interp
    return [urlrouter::handleURL $interp $sock $url]
}
