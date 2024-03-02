# Gopher Server Handling Code
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#


namespace eval gophers {
  namespace export {[a-z]*}
  namespace ensemble create

  variable rootDir {}
  # TODO: Rename listen
  variable listen
  variable configOptions
}

set RepoRootDir [file dirname [info script]]
source [file join $RepoRootDir router.tcl]
source [file join $RepoRootDir config.tcl]
source [file join $RepoRootDir menu.tcl]

proc gophers::init {configFilename} {
  variable listen
  variable configOptions
  set configOptions [config::load $configFilename]
  # TODO: Add port to config that can't be changed once run
  set listen [socket -server gophers::clientConnect 7070]
}

proc gophers::shutdown {} {
  variable listen
  catch {close $listen}
}


proc gophers::clientConnect {sock host port} {
  variable configOptions
  chan configure $sock -buffering line -blocking 0
  chan event $sock readable [list gophers::readSelector $sock]
  if {[dict get $configOptions logger suppress] ne "all"} {
    puts "Connection from $host:$port"
  }
}


# TODO: Handle client sending too much data
proc gophers::readSelector {sock} {
  if {[catch {gets $sock line} len] || [eof $sock]} {
      catch {close $sock}
  } elseif {$len >= 0} {
      if {![gophers::handleSelector $sock $line]} {
        gophers::sendText $sock "3Error: file not found\tFAKE\t(NULL)\t0"
      }
      catch {close $sock}
  }
}


# TODO: report better errors in case handler returns an error
proc gophers::handleSelector {sock selector} {
  variable interp
  set selector [router::safeSelector $selector]
  set handlerInfo [router::getHandlerInfo $selector]
  if {$handlerInfo ne {}} {
    lassign $handlerInfo handlerScript params
    # TODO: Better safer way of doing this?
    {*}$handlerScript $sock {*}$params
    return true
  } else {
    return false
  }
}


# TODO: Be careful file isn't too big and reduce transmission rate if big and under heavy load
# TODO: Catch errors
proc gophers::readFile {filename} {
  # TODO: put filename handling code into a separate function
  set filename [string trimleft $filename "."]
  set nativeFilename [file normalize $filename]
  set nativeFilename [file join $gophers::rootDir $nativeFilename]
  set fd [open $nativeFilename]
  set data [read $fd]
  close $fd
  return $data
}


# TODO: Change to sendText and have another one for sendBinary?
proc gophers::sendText {sock msg} {
  if {[catch {puts -nonewline $sock $msg} error]} {
    puts stderr "Error writing to socket: $error"
    catch {close $sock}
  }
}


# TODO: Rename
# TODO: Do we need selectorPath?
proc gophers::serveDir {localDir sock selectorPath args} {
  # TODO: Should we use file join args or safeSelector for args?
  set path [file join $localDir [file join {*}$args]]
  set pathPermissions [file attributes $path -permissions]
  if {($pathPermissions & 4) != 4} {
    error "local path isn't world readable: $path"
  }

  # TODO: make path joining safe and check world readable
  if {[file isfile $path]} {
    sendText $sock [readFile $path]
  } elseif {[file isdirectory $path]} {
    listDir $sock $localDir [file join {*}$args]
  }
}


# TODO: Make this safer and suitable for running as master command from interpreter
# TODO: Restrict directories and look at permissions (world readable?)
proc gophers::listDir {sock localDir selectorPath} {
  set localDir [string trimleft $localDir "."]
  set localDir [file normalize $localDir]
  set localDir [file join $localDir $selectorPath]
  set files [glob -tails -directory $localDir *]
  set menu [menu create localhost 7070]

  foreach file $files {
    set selector "/[file join $selectorPath $file]"
    set nativeFile [file join $localDir $file]
    if {[file isfile $nativeFile]} {
      menu addFile menu text $file $selector
    } elseif {[file isdirectory $nativeFile]} {
      menu addMenu menu $file $selector
    }
  }
  # TODO: send a . to mark end?
  sendText $sock [menu render $menu]
}
