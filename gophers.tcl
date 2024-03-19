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
  variable sendMsgs [dict create]
  # TODO: improve statuses
  # Status of a send:
  #  waiting: waiting for something to send
  #  ready:   something is ready to send
  #  done:    nothing left to send, close
  variable sendStatus [dict create]
}

set RepoRootDir [file dirname [info script]]
source [file join $RepoRootDir router.tcl]
source [file join $RepoRootDir config.tcl]
source [file join $RepoRootDir menu.tcl]
source [file join $RepoRootDir cache.tcl]
source [file join $RepoRootDir gophermap.tcl]

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
  variable sendStatus
  chan configure $sock -buffering line -blocking 0 -translation {auto binary}
  dict set sendStatus $sock "waiting"
  chan event $sock readable [list gophers::readSelector $sock]
  chan event $sock writable [list ::gophers::sendTextWhenWritable $sock]
  if {[dict get $configOptions logger suppress] ne "all"} {
    puts "Connection from $host:$port"
  }
}


# TODO: Handle client sending too much data
proc gophers::readSelector {sock} {
  variable sendStatus
  if {[catch {gets $sock selector} len] || [eof $sock]} {
      catch {close $sock}
  } elseif {$len >= 0} {
    if {![gophers::handleSelector $sock $selector]} {
      gophers::sendText $sock "3Error: file not found\tFAKE\t(NULL)\t0"
      # TODO: Close send variables for sock
      catch {close $sock}
    }
    dict set sendStatus $sock "done"
    # TODO: set routine to tidy up sendDones, etc that have been around for
    # TODO: a while
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
    lassign [{*}$handlerScript {*}$params] type value
    switch -- $type {
      text {
        sendText $sock $value
      }
      default {
        error "unknown type: $type"
      }
    }
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


# To be called by writable event to send text when sock is writable
# This will break the text into 10k chunks to help if we have multiple
# slow connections.
proc gophers::sendTextWhenWritable {sock} {
  variable sendMsgs
  variable sendStatus
  if {[dict get $sendStatus $sock] eq "waiting"} {
    return
  }
  
  set msg [dict get $sendMsgs $sock]
  if {[string length $msg] == 0} {
    if {[dict get $sendStatus $sock] eq "done"} {
      dict unset sendMsgs $sock
      dict unset sendStatus $sock
      catch {close $sock}
      return
    } else {
      dict set sendStatus $sock "waiting"
    }
  }

  set str [string range $msg 0 10000]
  dict set sendMsgs $sock [string range $msg 10001 end]

  if {[catch {puts -nonewline $sock $str} error]} {
    puts stderr "Error writing to socket: $error"
    catch {close $sock}
  }
}


# TODO: Have another one for sendBinary?
proc gophers::sendText {sock msg} {
  variable sendMsgs
  variable sendStatus

  # TODO: Make sendMsgs a list so can send multiple messages?
  dict set sendMsgs $sock $msg
  dict set sendStatus $sock ready
}


# TODO: Rename
# TODO: Do we need selectorPath?
proc gophers::serveDir {localDir selectorPath args} {
  # TODO: Should we use file join args or safeSelector for args?
  set path [file join $localDir [file join {*}$args]]
  set pathPermissions [file attributes $path -permissions]
  if {($pathPermissions & 4) != 4} {
    error "local path isn't world readable: $path"
  }

  # TODO: make path joining safe and check world readable
  if {[file isfile $path]} {
    # TODO: Don't allow gophermap to be downloaded
    return [list text [readFile $path]]
  } elseif {[file isdirectory $path]} {
    lassign [gophers::cache get $selectorPath] inCache menuText
    if {!$inCache} {
      set menu [menu create localhost 7070]
      set menu [listDir $menu $localDir [file join {*}$args]]
      set menuText [menu render $menu]
      gophers::cache put $selectorPath $menuText
    }
    return [list text $menuText]
  }
  error "TODO: what is this?"
}



# listDir ?switches? menu localDir selectorPath
# switches:
#  -nogophermap      Don't process any gophermaps found
#  -files files      Pass a list of filenames rather than glob them
#
# TODO: Rename -files to -filenames?
# TODO: Make this safer and suitable for running as master command from interpreter
# TODO: Restrict directories and look at permissions (world readable?)
proc gophers::listDir {args} {
  array set options {}
  while {[llength $args]} {
    switch -glob -- [lindex $args 0] {
      -nogophermap {set args [lassign $args options(nogophermap)]}
      -files {set args [lassign $args - options(files)]}
      -descriptions {set args [lassign $args - options(descriptions)]}
      --      {set args [lrange $args 1 end] ; break}
      -*      {return -code error "listDir: unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] != 3} {
    return -code error "listDir: invalid number of arguments"
  }
  lassign $args menu localDir selectorPath

  set localDir [string trimleft $localDir "."]
  set localDir [file normalize $localDir]
  set selectorLocalDir [file join $localDir $selectorPath]
  if {[info exists options(files)]} {
    set files $options(files)
  } else {
    set files [glob -tails -directory $selectorLocalDir *]
    set files [lsort $files]
  }

  # TODO: Rename gophermap
  if {![info exists options(nogophermap)] &&
       [file exists [file join $selectorLocalDir gophermap]]} {
    # TODO: Handle exceptions
    return [gophermap::process $menu $files $localDir $selectorPath]
  }

  if {[info exists options(descriptions)]} {
    set descriptions $options(descriptions)
  } else {
    set descriptions [dict create]
  }

  # List the directory without using a gophermap if not present or it fails
  set prevFileDescribed false   ; # This prevents a double proceeding new line
  foreach file $files {
    if {$file eq "gophermap"} {
      # Don't display the gophermap
      continue
    }

    # If a description exists then put a blank line before file
    if {!$prevFileDescribed && [dict exists $descriptions $file]} {
      set menu [menu info $menu ""]
      set prevFileDescribed true
    } else {
      set prevFileDescribed false
    }

    set selector "/[file join $selectorPath $file]"
    set nativeFile [file join $selectorLocalDir $file]
    if {[file isfile $nativeFile]} {
      set menu [menu item $menu text $file $selector]
    } elseif {[file isdirectory $nativeFile]} {
      set menu [menu item $menu menu $file $selector]
    }

    # If a description exists then put it after the file
    if {[dict exists $descriptions $file]} {
      set menu [menu info $menu [dict get $descriptions $file]]
      set menu [menu info $menu ""]
    }
  }
  return $menu
}
