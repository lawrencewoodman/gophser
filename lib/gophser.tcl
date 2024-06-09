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
    # TODO: handle error differently
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

