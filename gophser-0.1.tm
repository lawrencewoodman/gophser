# gophser v0.1
# A gopher server module
# Created using buildtm.
# Changes should be made to source files not this file.

# Gopher Server Module
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

namespace eval gophser {
  namespace export {[a-z]*}

  # TODO: Rename listen
  variable listen
  variable sendMsgs [dict create]
  # TODO: improve statuses
  # Status of a send:
  #  waiting: waiting for something to send
  #  ready:   something is ready to send
  #  done:    nothing left to send, close
  variable sendStatus [dict create]
  variable configOptions [dict create logger [dict create suppress none]]
}

# Cache selector menus
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

namespace eval gophser::cache {
  namespace export {[a-z]*}
  namespace ensemble create
  variable store [dict create]
  variable cleanTime [clock seconds]
}


# Put data for selectorPath in the cache
proc gophser::cache::put {selectorPath data} {
  variable store
  dict set store $selectorPath [list [clock seconds] $data]
}


# Return: {exists data}
proc gophser::cache::get {selectorPath} {
  variable store
  variable cleanTime
  
  # If it has been over 60 seconds since the last clean out of old entries
  if {[clock seconds] - $cleanTime > 60} {
    # Clean out old entries
    Clean
  }
  if {![dict exists $store $selectorPath]} {
    return {false {}}
  }
  lassign [dict get $store $selectorPath] getTime data
  return [list true $data]
}


# Remove any cache entries older than 60 seconds
proc gophser::cache::Clean {} {
  variable store
  variable cleanTime
  set cleanTime [clock seconds]
  set oldSelectors [list]
  dict for {selectorPath entry} $store {
    lassign $entry getTime
    # If the entry is more than 60 seconds old, note it for removal
    if {[clock seconds] - $getTime > 60} {
      lappend oldSelectors $selectorPath
    }
  }
  foreach selectorPath $oldSelectors {
    dict unset store $selectorPath
  }
}

# Handle directory gophermap creation
# TODO: This is only a temporary name because it uses a very different
# TODO: format to standard gophermap files and therefore needs renaming
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#


namespace eval gophser::gophermap {
  namespace export {[a-z]*}

  variable menu  
  # Sorted list of files found in the same directory as the gophermap
  variable files
  variable descriptions
}


proc gophser::gophermap::process {
  _menu _files localDir selectorRootPath selectorSubPath
} {
  variable menu
  variable files
  variable descriptions

  set menu $_menu
  set files $_files
  set descriptions [dict create]

  set interp [interp create -safe]
  $interp eval {unset {*}[info vars]}
  $interp alias menu ::gophser::gophermap::Menu
  $interp alias describe ::gophser::gophermap::Describe
  $interp alias listFiles ::gophser::gophermap::ListFiles $localDir $selectorRootPath $selectorSubPath
  set gophermapPath [file join $localDir $selectorSubPath gophermap]
  if {[catch {$interp invokehidden source $gophermapPath}]} {
    error "error processing: $gophermapPath, for selector: [file join $selectorRootPath $selectorSubPath], $::errorInfo"
  }
  return $menu
}


proc gophser::gophermap::Menu {command args} {
  variable menu
  switch -- $command {
    item {
      # TODO: ensure can only include files in the current location?
      set menu [::gophser::menu::item $menu {*}$args]
    }
    default {
      return -code error "menu: invalid command: $command"
    }
  }
}


# TODO: Be able to add extra info next to filename such as size and date
proc gophser::gophermap::Describe {filename description} {
  variable descriptions
  dict set descriptions $filename $description
}


proc gophser::gophermap::ListFiles {localDir selectorRootPath selectorSubPath} {
  variable menu
  variable files
  variable descriptions
  
  set menu [::gophser::ListDir -nogophermap -files $files \
                               -descriptions $descriptions \
                               $menu $localDir \
                               $selectorRootPath $selectorSubPath]
}

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
    return [list text [ReadFile $path]]
  } elseif {[file isdirectory $path]} {
    lassign [cache get $selectorPath] inCache menuText
    if {!$inCache} {
      set menu [menu create localhost 7070]
      set menu [ListDir $menu $localDir $selectorMountPath $selectorSubPath]
      set menuText [menu render $menu]
      cache put $selectorPath $menuText
    }
    return [list text $menuText]
  }
  error "TODO: what is this?"
}



# listDir ?switches? menu localDir selectorMountPath selectorSubPath
# switches:
#  -nogophermap      Don't process any gophermaps found
#  -files files      Pass a list of filenames rather than glob them
#
# TODO: Rename -files to -filenames?
# TODO: Make this safer and suitable for running as master command from interpreter
# TODO: Restrict directories and look at permissions (world readable?)
proc gophser::ListDir {args} {
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
  if {[llength $args] != 4} {
    return -code error "listDir: invalid number of arguments"
  }
  lassign $args menu localDir selectorMountPath selectorSubPath
  set localDir [string trimleft $localDir "."]
  set localDir [file normalize $localDir]
  set selectorLocalDir [file join $localDir $selectorSubPath]
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
    return [gophermap::process $menu $files $localDir $selectorMountPath $selectorSubPath]
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

    set selector "[file join $selectorMountPath $selectorSubPath $file]"
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

# Menu handling
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#
package require textutil

namespace eval gophser::menu {
  namespace export {[a-z]*}
  namespace ensemble create
}


proc gophser::menu::create {{defaultHost localhost} {defaultPort 70} } {
  set defaults [dict create hostname $defaultHost port $defaultPort]
  dict create defaults $defaults menu {}
}


# Add information text
# The text will be wrapped if the line length exceeds 80 characters
# TODO: Work out what length to set this to wrap
proc gophser::menu::info {menu text} {
  item $menu info $text FAKE
}


# Add an item to the menu
# Returns a menu with the item added
proc gophser::menu::item {menu itemType userName selector {hostname {}} {port {}}} {
  if {$hostname eq {}} {
    set hostname [dict get $menu defaults hostname]
  }
  if {$port eq {}} {
    set port [dict get $menu defaults port]
  }

  switch -- $itemType {
    text -
    0 {set itemType 0}
    menu -
    1 {set itemType 1}
    info -
    i {set itemType i}
    default {
      # TODO: Have this as a warning only?
      error "unknown item type: $itemType"
    }
  }

  if {$itemType eq "i"} {
    # Wrap the text
    # TODO: Should we split the lines and wrap each to allow
    # TODO: newlines to be used in source text
    set text [::textutil::adjust $userName -length 80]
    if {$text eq ""} {
      dict lappend menu menu [list $itemType "" $selector $hostname $port]
    }
    foreach t [split $text "\n"] {
      # TODO: Work out what's best to put as the selector in this case
      # TODO: Work out what to put as host and port
      dict lappend menu menu [list $itemType $t $selector $hostname $port]
    }
  } else {
    dict lappend menu menu [list $itemType $userName $selector $hostname $port]
  }
  return $menu
}


# Render the menu as text ready for sending
proc gophser::menu::render {menu} {
  set menuStr ""
  foreach item [dict get $menu menu] {
    lassign $item type userName selector hostname port
    set itemStr "$type$userName\t$selector\t$hostname\t$port\r\n"
    append menuStr $itemStr
  }
  append menuStr ".\r\n"
  return $menuStr
}

# Define routes and route selectors to handlers
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

# TODO: add Middleware? for logging, doubledot path protection
# TODO: Enforce only being able to load world readable files that aren't executable?
# TODO: Handle trailing slashes


# TODO: Think about name format and rename file?
namespace eval gophser::router {
  namespace export {[a-z]*}
  variable routes {}
}

# TODO: Restrict pattern and make safe
# TODO: Sort routes after adding from most specific to most general
proc gophser::router::route {pattern handlerName} {
  variable routes
  lappend routes [list $pattern $handlerName]
  Sort
}


# TODO: rename
# TODO: Assumes selector is safe at this point?
# Perhaps use namespace to determine whether input has been checked
proc gophser::router::getHandler {selector} {
  variable routes
  set selector [safeSelector $selector]
  foreach route $routes {
    # TODO: Rename handlerName?
    lassign $route pattern handlerName
    if {[string match $pattern $selector]} {
      return $handlerName
    }
  }
  return {}
}


# Returns a safer version of the selector path
# TODO: Only allow absolute paths
# TODO: Convert tabs to % notation?
# Convert spaces to % notation
# Resolves .. without going past root of path
# Removes . directory element
# Supports directory elements beginning with ~
proc gophser::router::safeSelector {selectorPath} {
  set selectorPath [string map {" " "%20"} $selectorPath]
  set elements [file split $selectorPath]
  set newSelectorPath [list]
  foreach e $elements {
    if {$e eq ".."} {
      set newSelectorPath [lreplace $newSelectorPath end end]
    } elseif {$e ne "." && $e ne "/"} {
      if {[string match {./*} $e]} {
        set e [string range $e 2 end]
      }
      lappend newSelectorPath $e
    }
  }
  return "\/[join $newSelectorPath "/"]"
}


# Sort the routes from most specific to least specific
proc gophser::router::Sort {} {
  variable routes
  set routes [lsort -command CompareRoutes $routes]
}


# Compare the routes for lsort to determine which is most specific
proc gophser::router::CompareRoutes {a b} {
  set patternPartsA [file split [lindex $a 0]]
  set patternPartsB [file split [lindex $b 0]]
  foreach partA $patternPartsA partB $patternPartsB {
    if {$partA ne $partB} {
      if {$partA eq "*"} { return 1 }
      if {$partB eq "*"} { return -1 }
      if {$partA eq ""}  { return 1 }
      if {$partB eq ""}  { return -1 }
    }
  }
  return 0
}

