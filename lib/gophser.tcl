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
  route "URL:*" {} {{request} {
    gophser::ServeURL $request
  }}
}

proc gophser::shutdown {} {
  variable listen
  catch {close $listen}
}


# TODO: Rename
# TODO: make pattern safe
# funcArgs A list of arguments to use after the request when applying the func
# func     A function suitable for the apply command
proc gophser::route {pattern funcArgs func} {
  router::route $pattern $funcArgs $func
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
  chan configure $sock -buffering line -blocking 0 -translation {auto binary}
  chan event $sock readable [list ::gophser::ReadSelector $sock]
  chan event $sock writable [list ::gophser::SendResponseWhenWritable $sock]

  log info "connection from $host:$port"
}


proc gophser::ReadSelector {sock} {
  try {
    set len [SafeGets $sock 255 selector]
    if {[eof $sock]} {
      # TODO: find a neater way of handling this
      # TODO: log error?
      catch {close $sock}
      return
    }
    if {$len >= 0} {
      HandleRequest $sock $selector
    }
  } on error err {
    # TODO: log error?
    catch {close $sock}
  }
}



proc gophser::HandleRequest {sock selector} {
  lassign [router::getHandler $selector] handlerArgs handler
  if {$handler eq {}} {
    # TODO: should we just have a selector not found handler?
    log warning "selector not found: $selector"
    SendError $sock "path not found"
    return
  }

  try {
    set request [dict create selector $selector]
    set response [apply $handler $request {*}$handlerArgs]
  } on error err {
    log error "error running handler for selector: $selector - $err"
    # TODO: create some sort of error response
    # TODO: close the sock?
  }
  AddResponse $sock $response
}



proc gophser::AddResponse {sock response} {
  variable responses
  dict set responses $sock $response
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


# TODO: Be careful file isn't too big and reduce transmission rate if big and under heavy load
# TODO: Catch errors
proc gophser::ReadFile {filename} {
  # TODO: put filename handling code into a separate function
  set filename [string trimleft $filename "."]
  set nativeFilename [file normalize $filename]
  set fd [open $nativeFilename {RDONLY BINARY}]
  set data [read $fd]
  close $fd
  return $data
}


# To be called by writable event to send a response if present when sock is
# writable.
# This will break the response values into 10k chunks to help if we have
# multiple slow connections.
proc gophser::SendResponseWhenWritable {sock} {
  variable responses
  if {![dict exists $responses $sock]} {
    return
  }
  set response [dict get $responses $sock]
  # TODO: better name than value?
  set type [dict get $response type]
  set value [dict get $response value]

  switch $type {
    error {
      # TODO: Add CRLF on end?
      set value "3$value\tFAKE\t(NULL)\t0"
      try {
        puts -nonewline $sock $value
      } on error err {
        # TODO: handle error differently
        puts stderr "Error writing to socket: $err"
      }
      dict unset responses $sock
      catch {close $sock}
      return
    }
    text {
      # TODO: find a way of loading and sending parts of files
#      set str [string range $value 0 10000]
#      set value [string range $value 10001 end]

      try {
        puts -nonewline $sock $value
      } on error err {
        # TODO: handle error differently
        puts stderr "Error writing to socket: $err"
      }

      dict unset responses $sock
      # TODO: catch error and log if present
      catch {close $sock}
    }
    default {
      error "unknown type: $type"
    }
  }
}


# TODO: Turn any tabs in message to % notation
proc gophser::SendError {sock msg} {
  set response [dict create type error value $msg]
  AddResponse $sock $response
}

