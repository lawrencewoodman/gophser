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
}

set RepoRootDir [file dirname [info script]]
source [file join $RepoRootDir routing.tcl]
source [file join $RepoRootDir config.tcl]
source [file join $RepoRootDir menu.tcl]

proc gophers::init {configFilename} {
  variable listen
  gophers::loadConfig $configFilename
  # TODO: Add port to config that can't be changed once run
  set listen [socket -server gophers::clientConnect 7070]
}

proc gophers::shutdown {} {
  variable listen
  catch {close $listen}
}


proc gophers::clientConnect {sock host port} {
  chan configure $sock -buffering line -blocking 0
  chan event $sock readable [list gophers::readLine $sock]
  puts "Connection from $host:$port"
}


# TODO: rename
# TODO: Handle client sending too much data
proc gophers::readLine {sock} {
  if {[catch {gets $sock line} len] || [eof $sock]} {
      catch {close $sock}
  } elseif {$len >= 0} {
      if {![gophers::handleURL $sock $line]} {
        gophers::sendText $sock "3Error: file not found\tFAKE\t(NULL)\t0"
      }
      catch {close $sock}
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
  if {[catch {puts $sock $msg} error]} {
    puts stderr "Error writing to socket: $error"
    catch {close $sock}
  }
}


# TODO: Rename
# TODO: Do we need url?
proc gophers::serveDir {localDir sock urlPath args} {
  # TODO: Should we use file join args or safeURL for args?
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
proc gophers::listDir {sock localDir urlPath} {
  set localDir [string trimleft $localDir "."]
  set localDir [file normalize $localDir]
  set localDir [file join $localDir $urlPath]
  set files [glob -tails -directory $localDir *]
  set menu [menu create localhost 7070]

  foreach file $files {
    set selector "/[file join $urlPath $file]"
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


# TODO: report better errors incase handler returns and error
proc gophers::handleURL {sock urlPath} {
  variable interp
  set urlPath [urlrouter::SafeURL $urlPath]
  set handlerInfo [urlrouter::getHandlerInfo $urlPath]
  if {$handlerInfo ne {}} {
    lassign $handlerInfo handlerScript params
    {*}$handlerScript $sock {*}$params
    return true
  } else {
    return false
  }
}
