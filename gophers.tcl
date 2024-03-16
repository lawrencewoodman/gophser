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
  variable sendPos [dict creat]
}

set RepoRootDir [file dirname [info script]]
source [file join $RepoRootDir router.tcl]
source [file join $RepoRootDir config.tcl]
source [file join $RepoRootDir menu.tcl]
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
  chan configure $sock -buffering line -blocking 0 -translation {auto binary}
  chan event $sock readable [list gophers::readSelector $sock]
  if {[dict get $configOptions logger suppress] ne "all"} {
    puts "Connection from $host:$port"
  }
}


# TODO: Handle client sending too much data
proc gophers::readSelector {sock} {
  if {[catch {gets $sock selector} len] || [eof $sock]} {
      catch {close $sock}
  } elseif {$len >= 0} {
      if {![gophers::handleSelector $sock $selector]} {
        gophers::sendText $sock "3Error: file not found\tFAKE\t(NULL)\t0"
        catch {close $sock}
      }
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
  variable sendPos

  set msg [dict get $sendMsgs $sock]
  set pos [dict get $sendPos $sock]
  set str [string range $msg $pos $pos+10000]
  incr pos 10001

  if {[string length $str] == 0} {
    dict unset sendMsgs $sock
    catch {close $sock}
    return
  }
  dict set sendPos $sock $pos

  if {[catch {puts -nonewline $sock $str} error]} {
    puts stderr "Error writing to socket: $error"
    catch {close $sock}
  }
}


# TODO: Have another one for sendBinary?
proc gophers::sendText {sock msg} {
  variable sendMsgs
  variable sendPos

  # TODO: Make sendMsgs a list so can send multiple messages?
  dict set sendMsgs $sock $msg
  dict set sendPos $sock 0
  chan event $sock writable [list ::gophers::sendTextWhenWritable $sock]
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
    set menu [menu create localhost 7070]
    listDir menu $localDir [file join {*}$args]
    return [list text [menu render $menu]]
  }
  error "TODO: what is this?"
}



# listDir ?switches? menuVar localDir selectorPath
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
      --      {set args [lrange $args 1 end] ; break}
      -*      {return -code error "listDir: unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] != 3} {
    return -code error "listDir: invalid number of arguments"
  }
  lassign $args menuVar localDir selectorPath
  upvar $menuVar menuVal


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
    gophermap::process menuVal $files $localDir $selectorPath
    return
  }

  # List the directory without using a gophermap if not present or it fails
  foreach file $files {
    if {$file eq "gophermap"} {
      # Don't display the gophermap
      continue
    }
    set selector "/[file join $selectorPath $file]"
    set nativeFile [file join $selectorLocalDir $file]
    if {[file isfile $nativeFile]} {
      menu addFile menuVal text $file $selector
    } elseif {[file isdirectory $nativeFile]} {
      menu addMenu menuVal $file $selector
    }
  }
}
