# Gopher Server Handling Code
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#


proc gophser::init {port} {
  variable listen
  variable cache
  set listen [socket -server ::gophser::ClientConnect $port]
  set cache [cache create]
  # Add route to handle URL: selectors
  route "URL:*" gophser::ServeURL
}

proc gophser::shutdown {} {
  variable listen
  catch {close $listen}
}


# mount localDir selectorMountPath
#
# localDir: The local absolute directory path
# selectorMountPath: The path for the selector which must not contain wildcards
proc gophser::mount {localDir selectorMountPath} {
  set localDir [string trim $localDir]

  if {$localDir eq ""} {
    return -code error "local dir blank"
  }
  if {[string index $localDir 0] ne "/"} {
    return -code error "can not mount relative directories: $localDir"
  }

  set localDir [file normalize $localDir]

  if {![file exists $localDir]} {
    return -code error "local directory doesn't exist: $localDir"
  }

  if {![file isdirectory $localDir]} {
    return -code error "local directory isn't a directory: $localDir"
  }

  if {[string match {*[*?]*} $selectorMountPath] ||
      [string match {*\[*} $selectorMountPath] ||
      [string match {*\]*} $selectorMountPath]} {
    return -code error "selector can not contain wildcards"
  }

  # TODO: relook at whether safeSelector use is appropriate here
  set selectorMountPath [router::safeSelector $selectorMountPath]
  if {$selectorMountPath eq "/"} {
    set selectorMountPathGlob "/*"
  } else {
    set selectorMountPathGlob "$selectorMountPath/*"
  }

  route $selectorMountPathGlob [list gophser::ServePath $localDir $selectorMountPath]
}


proc gophser::provideLinkDir {directoryDB selectorMountPath} {
  if {[string match {*[*?]*} $selectorMountPath] ||
      [string match {*\[*} $selectorMountPath] ||
      [string match {*\]*} $selectorMountPath]} {
    return -code error "selector can not contain wildcards"
  }

  # TODO: relook at whether safeSelector use is appropriate here
  set selectorMountPath [router::safeSelector $selectorMountPath]
  if {$selectorMountPath eq "/"} {
    set selectorMountPathGlob "/*"
  } else {
    set selectorMountPathGlob "$selectorMountPath/*"
  }
  # TODO: Find a better way of doing this
  route $selectorMountPathGlob [list gophser::ServeLinkDirectory $directoryDB $selectorMountPath]
  route $selectorMountPath [list gophser::ServeLinkDirectory $directoryDB $selectorMountPath]
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
  if {[catch {SafeGets $sock 255 selector} len] || [eof $sock]} {
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


# TODO: Add a timeout, probably by switching to non blocking io
# TODO: although channel should be non blocking - check by testing
# TODO: with a few byte selector without a '\n' at the end and see
# TODO: what happens.
# Like ::gets but with a maxSize parameter to prevent a client from sending
# a huge amount of data leading to a DoS.
proc gophser::SafeGets {channelId maxSize varname} {
  upvar $varname result
  set result ""
  for {set i 0} {$i < $maxSize} {incr i} {
    set char [read $channelId 1]
    if {$char eq ""} {
      # TODO: Better error here?
      # TODO: Test against gets
      error EOF
    } elseif {[string first $char "\n"] == -1} {
      append result $char
    } else {
      break
    }
  }
  return $i
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
  set compPath [file join {*}[lrange $pathParts 0 [llength $prefixPathParts]-1]]
  if {$prefixPath ne $compPath} {
    return -code error "selector: $selectorPath does not contain prefix: $prefixPath"
  }
  set remainingPathParts [lrange $pathParts [llength $prefixPathParts] end]
  if {[llength $remainingPathParts] == 0} {return ""}
  return [file join {*}$remainingPathParts]
}



# TODO: Work out at what point the sub path is safe
proc gophser::MakeSelectorLocalPath {localDir selectorSubPath} {
  set localDir [string trimleft $localDir "."]
  set localDir [file normalize $localDir]
  return [file join $localDir $selectorSubPath]
}


# Make a list of directory entries for ListDir
# type is f for file, d for directory
# names is a list of file/dir names
# descriptions is a dict with key file/dir name and values: {userName description}
proc gophser::MakeDirEntries {type names descriptions} {
  set dirEntries [list]
  foreach name $names {
    if {$name eq "gophermap"} {
      # Don't display the gophermap
      continue
    }
    if {[dict exists $descriptions $name]} {
      lassign [dict get $descriptions $name] userName description
    } else {
      set userName $name
      set description ""
    }
    lappend dirEntries [list $name $type $userName $description]
  }
  return $dirEntries
}


# listDir ?switches? menu localDir selectorMountPath selectorSubPath
# switches:
#  -descriptions descriptions  Dictionary of descriptions for each filename
#
# Creates menu items for each file/dir in directory
# Entries are sorted alphabetically with directories proceeding files
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
  set dirs [glob -tails -type d -nocomplain -directory $selectorLocalDir *]
  set dirs [lsort -nocase $dirs]
  set files [glob -tails -type f -nocomplain -directory $selectorLocalDir *]
  set files [lsort -nocase $files]

  set dirEntriesD [MakeDirEntries d $dirs $descriptions]
  set dirEntriesF [MakeDirEntries f $files $descriptions]
  set dirEntries [concat $dirEntriesD $dirEntriesF]

  set prevFileDescribed false   ; # This prevents a double proceeding new line
  foreach dirEntry $dirEntries {
    lassign $dirEntry localName type userName description

    # If a description exists then put a blank line before file
    if {!$prevFileDescribed && $description ne ""} {
      set menu [menu info $menu ""]
      set prevFileDescribed true
    } else {
      set prevFileDescribed false
    }

    set selector [file join $selectorMountPath $selectorSubPath $localName]
    if {$type eq "f"} {
      set menu [menu item $menu text $userName $selector]
    } else {
      # Directory
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

