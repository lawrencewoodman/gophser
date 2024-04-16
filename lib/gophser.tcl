# Gopher Server Handling Code
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#


proc gophser::init {port} {
  variable listen
  set listen [socket -server ::gophser::ClientConnect $port]
}

proc gophser::shutdown {} {
  variable listen
  catch {close $listen}
}


# localDir: The local absolute directory path
# selectorPath: The path for the selector which must not contain wildcards
proc gophser::mount {localDir selectorPath} {
  set localDir [string trim $localDir]

  if {$localDir eq ""} {
    return -code error "local dir blank"
  }
  if {[string index $localDir 0] ne "/"} {
    return -code error "can not mount relative directories: $localDir"
  }

  set localDir [file normalize $localDir]

  if {[string match {*[*?]*} $selectorPath] ||
      [string match {*\[*} $selectorPath] ||
      [string match {*\]*} $selectorPath]} {
    return -code error "selector can not contain wildcards"
  }

  set selectorPath [router::safeSelector $selectorPath]
  if {$selectorPath eq "/"} {
    set selectorPathGlob "/*"
  } else {
    set selectorPathGlob "$selectorPath/*"
  }

  if {![file exists $localDir]} {
    return -code error "local directory doesn't exist: $localDir"
  }

  if {![file isdirectory $localDir]} {
    return -code error "local directory isn't a directory: $localDir"
  }

  router::route $selectorPathGlob [list gophser::ServePath $localDir $selectorPath]
}


# TODO: Rename
# TODO: make pattern safe
proc gophser::route {pattern handlerName} {
  router::route $pattern $handlerName
}


# TODO: Consider basing off log tcllib package
proc gophser::log {command args} {
  variable configOptions
  # TODO: Think about what to use for reporting (info?)
  switch -- $command {
    error {
      if {[dict get $configOptions logger suppress] ne "all"} {
        puts "Error:    [lindex $args 0]"
      }
    }
    info {
      if {[dict get $configOptions logger suppress] ne "all"} {
        puts "Info:    [lindex $args 0]"
      }
    }
    warning {
      if {[dict get $configOptions logger suppress] ne "all"} {
        puts "Warning: [lindex $args 0]"
      }
    }
    suppress {
      # TODO: Improve error handling
      dict set configOptions logger suppress [lindex $args 0]
    }
    default {
      return -code error "invalid command for log: $command"
    }
  }
}


proc gophser::ClientConnect {sock host port} {
  variable configOptions
  variable sendStatus
  chan configure $sock -buffering line -blocking 0 -translation {auto binary}
  dict set sendStatus $sock "waiting"
  chan event $sock readable [list ::gophser::ReadSelector $sock]
  chan event $sock writable [list ::gophser::SendTextWhenWritable $sock]

  log info "connection from $host:$port"
}


# TODO: Handle client sending too much data
proc gophser::ReadSelector {sock} {
  variable sendStatus
  if {[catch {gets $sock selector} len] || [eof $sock]} {
      catch {close $sock}
  } elseif {$len >= 0} {
    set isErr [catch {
      set selector [router::safeSelector $selector]
      if {![HandleSelector $sock $selector]} {
        log warning "selector not found: $selector"
        SendError $sock "path not found"
      }
      dict set sendStatus $sock "done"
      # TODO: set routine to tidy up sendDones, etc that have been around for
      # TODO: a while
    } err]
    if {$isErr} {
      log error $err
    }
  }
}


# TODO: report better errors in case handler returns an error
proc gophser::HandleSelector {sock selector} {
  set handler [router::getHandler $selector]
  if {$handler ne {}} {
    # TODO: Better safer way of doing this?
    if {[catch {lassign [{*}$handler $selector] type value}]} {
      error "error running handler for selector: $selector - $::errorInfo"
    }
    switch -- $type {
      text {
        SendText $sock $value
      }
      error {
        SendError $sock $value
      }
      default {
        error "unknown type: $type"
      }
    }
    return true
  }
  return false
}


# TODO: Be careful file isn't too big and reduce transmission rate if big and under heavy load
# TODO: Catch errors
proc gophser::ReadFile {filename} {
  # TODO: put filename handling code into a separate function
  set filename [string trimleft $filename "."]
  set nativeFilename [file normalize $filename]
  set fd [open $nativeFilename]
  set data [read $fd]
  close $fd
  return $data
}


# To be called by writable event to send text when sock is writable
# This will break the text into 10k chunks to help if we have multiple
# slow connections.
proc gophser::SendTextWhenWritable {sock} {
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
proc gophser::SendText {sock msg} {
  variable sendMsgs
  variable sendStatus
  # TODO: Make sendMsgs a list so can send multiple messages?
  dict set sendMsgs $sock $msg
  dict set sendStatus $sock ready
}


# TODO: Turn any tabs in message to % notation
proc gophser::SendError {sock msg} {
  SendText $sock "3$msg\tFAKE\t(NULL)\t0"
  dict set sendStatus $sock "done"
}


# Remove the prefix from the selectorPath
# This is useful to remove mount points and to access variables
# passed in the selector path.
# TODO: Should this be exported?
proc gophser::stripSelectorPrefix {prefixPath selectorPath} {
  set prefixPathParts [file split $prefixPath]
  set pathParts [file split $selectorPath]
  set compPathParts [lrange $pathParts 0 [llength $prefixPathParts]-1]
  foreach prefixPart $prefixPathParts compPart $compPathParts {
    if {$prefixPart ne $compPart} {
      error "selector: $selectorPath does not contain prefix: $prefixPath"
    }
  }
  if {[llength $pathParts] <= [llength $prefixPathParts]} {
    return ""
  }
  return [file join {*}[lrange $pathParts [llength $prefixPathParts] end]]
}


# TODO: Do we need selectorPath?
# selectorMountPath is the path that localDir resides in the selector hierarchy
proc gophser::ServePath {localDir selectorMountPath selectorPath} {
  set selectorSubPath [stripSelectorPrefix $selectorMountPath $selectorPath]
  set path [file join $localDir $selectorSubPath]

  if {![file exists $path]} {
    log warning "local path doesn't exist: $path for selector: $selectorPath"
    return [list error "path not found"]
  }

  set pathPermissions [file attributes $path -permissions]
  if {($pathPermissions & 4) != 4} {
    log warning "local path isn't world readable: $path for selector: $selectorPath"
    return [list error "path not found"]
  }

  # TODO: make path joining safe and check world readable

  if {[file isfile $path]} {
    # TODO: Don't allow gophermap to be downloaded
    # TODO: Support caching when file isn't too big
    return [list text [ReadFile $path]]
  } elseif {[file isdirectory $path]} {
    lassign [cache get $selectorPath] inCache menuText
    if {!$inCache} {
      set selectorLocalPath [MakeSelectorLocalPath $localDir $selectorSubPath]
      set menu [menu create localhost 7070]
      # TODO: Rename gophermap
      if {[file exists [file join $selectorLocalPath gophermap]]} {
        set menu [gophermap::process $menu $localDir $selectorMountPath $selectorSubPath]
      } else {
        set menu [ListDir $menu $localDir $selectorMountPath $selectorSubPath]
      }
      set menuText [menu render $menu]
      cache put $selectorPath $menuText
    }
    return [list text $menuText]
  }
  error "TODO: what is this?"
}


# TODO: Work out at what point the sub path is safe
proc gophser::MakeSelectorLocalPath {localDir selectorSubPath} {
  set localDir [string trimleft $localDir "."]
  set localDir [file normalize $localDir]
  return [file join $localDir $selectorSubPath]
}


# listDir ?switches? menu localDir selectorMountPath selectorSubPath
# switches:
#  -descriptions descriptions  Dictionary of descriptions for each filename
#
# TODO: Make this safer and suitable for running as master command from interpreter
# TODO: Restrict directories and look at permissions (world readable?)
proc gophser::ListDir {args} {
  array set options {}
  while {[llength $args]} {
    switch -glob -- [lindex $args 0] {
      -descriptions {set args [lassign $args - options(descriptions)]}
      --      {set args [lrange $args 1 end] ; break}
      -*      {return -code error "unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] != 4} {
    return -code error "invalid number of arguments"
  }
  if {[info exists options(descriptions)]} {
    set descriptions $options(descriptions)
  } else {
    set descriptions [dict create]
  }

  lassign $args menu localDir selectorMountPath selectorSubPath
  set selectorLocalDir [MakeSelectorLocalPath $localDir $selectorSubPath]
  set files [glob -tails -directory $selectorLocalDir *]
  set files [lsort -nocase $files]
  set descriptons [dict create]

  # TODO: Work out why dict for isn't preserving insertion order
  # TODO: therefore forcing us to use foreach
  foreach file $files {
    if {[dict exists $descriptions $file]} {
      lassign [dict get $descriptions $file] userName description
    } else {
      set userName $file
      set description ""
    }
    dict set descriptions $file [list $userName $description]
  }

  set prevFileDescribed false   ; # This prevents a double proceeding new line
  foreach file $files {
    lassign [dict get $descriptions $file] userName description
    if {$file eq "gophermap"} {
      # Don't display the gophermap
      continue
    }

    # If a description exists then put a blank line before file
    if {!$prevFileDescribed && $description ne ""} {
      set menu [menu info $menu ""]
      set prevFileDescribed true
    } else {
      set prevFileDescribed false
    }

    set selector [file join $selectorMountPath $selectorSubPath $file]
    set nativeFile [file join $selectorLocalDir $file]
    if {[file isfile $nativeFile]} {
      set menu [menu item $menu text $userName $selector]
    } elseif {[file isdirectory $nativeFile]} {
      set menu [menu item $menu menu $userName $selector]
    }

    # If a description exists then put it after the file
    if {$description ne ""} {
      set menu [menu info $menu $description]
      set menu [menu info $menu ""]
    }
  }
  return $menu
}
