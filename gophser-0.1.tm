# gophser v0.1
# A gopher server module
#
# Created using buildtm
# Changes should be made to source files not this file

# Gopher Server Module
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

namespace eval gophser {
  namespace export {[a-z]*}

  # A selector cache
  variable cache
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

# Cache selector paths
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

namespace eval gophser::cache {
  namespace export {[a-z]*}
  namespace ensemble create
}


proc gophser::cache::create {} {
  return [dict create store {} details [dict create cleanupTime [clock seconds]]]
}

# Store data for selectorPath in the cache
proc gophser::cache::store {cacheVar selectorPath data {keepSeconds 60}} {
  upvar $cacheVar cache
  set expireTime [clock add [clock seconds] $keepSeconds seconds]
  dict set cache store $selectorPath [list $expireTime $data]
}


# Fetch data for selectorPath from the cache
# Return: data or {} is not in cache
proc gophser::cache::fetch {cacheVar selectorPath} {
  upvar $cacheVar cache
  set currentTime [clock seconds]
  set cleanupTime [dict get $cache details cleanupTime]
  
  # Clean up expired entries if it has been over 360 seconds since last done
  if {$currentTime - $cleanupTime > 360} {
    set cache [Cleanup $cache]
  }

  if {![dict exists $cache store $selectorPath]} {
    return {}
  }

  lassign [dict get $cache store $selectorPath] expireTime data

  # Remove entry if expired
  if {$currentTime > $expireTime} {
    dict unset cache store $selectorPath
    return {}
  }
  return $data
}


# Remove any cache entries that have expired
# This is used to prevent the cache from taking up too much memory
proc gophser::cache::Cleanup {cache} {
  set currentTime [clock seconds]
  set store [dict get $cache store]
  dict set cache details cleanupTime [clock seconds]
  set expiredSelectors [list]
  dict for {selectorPath entry} $store {
    lassign $entry expireTime
    # If current time is past the expire time
    if {$currentTime > $expireTime} {
      lappend expiredSelectors $selectorPath
    }
  }
  foreach selectorPath $expiredSelectors {
    dict unset cache store $selectorPath
  }
  return $cache
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
  variable descriptions
  variable includeDir [list]
  variable databases [dict create]
}


# TODO: This or pass config to process?
proc gophser::gophermap::setIncludeDir {_includeDir} {
  variable includeDir
  set includeDir $_includeDir
}


proc gophser::gophermap::process {_menu localDir selector selectorMountPath selectorSubPath} {
  variable menu
  variable descriptions

  set menu $_menu
  set selectorLocalDir [::gophser::MakeSelectorLocalPath $localDir $selectorSubPath]
  set descriptions [dict create]

  set interp [interp create -safe]
  $interp eval {unset {*}[info vars]}

  $interp alias menu ::gophser::gophermap::Menu
  $interp alias describe ::gophser::gophermap::Describe
  # TODO: Should dir be part of menu and there also be another dir for returning the directory entries?
  $interp alias dir ::gophser::gophermap::Dir $localDir $selectorMountPath $selectorSubPath
  $interp alias header ::gophser::gophermap::Header
  $interp alias source ::gophser::gophermap::Source $interp
  $interp alias log ::gophser::gophermap::Log

  set gophermapPath [file join $selectorLocalDir gophermap]
  if {[catch {$interp invokehidden source $gophermapPath} err]} {
    return -code error "error processing: $gophermapPath, for selector: $selector, $err"
  }

  return $menu
}


proc gophser::gophermap::Menu {command args} {
  variable menu
  switch -- $command {
    info {
      set menu [::gophser::menu::info $menu {*}$args]
    }
    text {
      # TODO: ensure can only include files in the current location?
      set menu [::gophser::menu::item $menu text {*}$args]
    }
    menu {
      # TODO: ensure can only include files in the current location?
      set menu [::gophser::menu::item $menu menu {*}$args]
    }
    url {
      set menu [::gophser::menu::url $menu {*}$args]
    }
    default {
      return -code error "menu: invalid command: $command"
    }
  }
}


# TODO: Be able to add extra info next to filename such as size and date
proc gophser::gophermap::Describe {filename userName {description {}}} {
  variable descriptions
  if {$userName eq ""} {set userName $filename}
  dict set descriptions $filename [list $userName $description]
}


proc gophser::gophermap::Header {level text} {
  set textlen [string length $text]
  if {$level == 1} {
    if {$textlen > 65} {
      # TODO: Generate a warning
    }
    Menu info [string repeat "=" [expr {$textlen+4}]]
    Menu info "= $text ="
    Menu info [string repeat "=" [expr {$textlen+4}]]
    Menu info ""
    return
  } elseif {$level == 2} {
    set underlineCh "="
  } elseif {$level == 3} {
    set underlineCh "-"
  } else {
    return -code "invalid header level"
  }

  if {$textlen > 69} {
    # TODO: Generate a warning
  }
  Menu info $text
  Menu info [string repeat $underlineCh $textlen]
  Menu info ""
}


# Display the files in the current directory
proc gophser::gophermap::Dir {localDir selectorMountPath selectorSubPath} {
  variable menu
  variable descriptions

  set menu [::gophser::ListDir -descriptions $descriptions \
                               $menu $localDir \
                               $selectorMountPath $selectorSubPath]
}


proc gophser::gophermap::Source {interp filename} {
  variable includeDir
  # TODO: Make sure filename doesn't include .. to allow moving outside of include path
  set fullFilename [file join $includeDir $filename]
  set isErr [catch {
    set fd [open $fullFilename r]
    set src [::read $fd]
    close $fd
  } err]
  if {$isErr} {
    # TODO: Could this reveal the whole path to filename and do we want this?
    # TODO: Log this error
    return -code error $err
  }
  # TODO: Test what this returns and return errors properly
  return [$interp eval $src]
}



# TODO: Test this and check this is the form we would like to use in a gophermap
proc gophser::gophermap::Log {command args} {
  gophser::log $command {*}$args
}

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


# Route handlers
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#


package require hetdb


# selectorPath is the complete path requested.  This is assumed to have
#              been made safe.
# selectorMountPath is the path that localDir resides in the selector hierarchy
proc gophser::ServePath {localDir selectorMountPath selectorPath} {
  variable cache
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

  if {[file isfile $path]} {
    # TODO: Don't allow gophermap to be downloaded
    # TODO: Support caching when file isn't too big?
    return [list text [ReadFile $path]]
  } elseif {[file isdirectory $path]} {
    # TODO: Should this be moved above?
    set menuText [cache fetch cache $selectorPath]
    if {$menuText eq {}} {
      set selectorLocalPath [MakeSelectorLocalPath $localDir $selectorSubPath]
      set menu [menu create localhost 7070]
      # TODO: Rename gophermap
      if {[file exists [file join $selectorLocalPath gophermap]]} {
        set menu [gophermap::process $menu $localDir $selectorPath $selectorMountPath $selectorSubPath]
      } else {
        set menu [ListDir $menu $localDir $selectorMountPath $selectorSubPath]
      }
      set menuText [menu render $menu]
      cache store cache $selectorPath $menuText
    }
    return [list text $menuText]
  }
  error "TODO: what is this?"
}


# selectorMountPath is the path that localDir resides in the selector hierarchy
#                   TODO: change to selectorPrefix?
# selector is the complete path requested.  This is assumed to have
#              been made safe.
# TODO: Rename?
# TODO: Format for linkDirectory  dict or hetdb?
# TODO: Add a description to link directory entries
# TODO: Add an intro text for first page
# TODO: Add layout in which to list links or intro text for the directory
proc gophser::ServeLinkDirectory {directoryDB selectorMountPath selector} {
  # TODO: Support caching? - needs testing
  variable cache
  set menuText [cache fetch cache $selector]
  if {$menuText eq {}} {
    set selectorSubPath [stripSelectorPrefix $selectorMountPath $selector]
    set selectorTags [split $selectorSubPath "/"]
    # TODO: Need to find a better way of handling default host and port here and below
    set menu [menu create localhost 7070]
    if {$selectorSubPath eq ""} {
      # TODO: Display an intro text - perhaps with some links
      # TODO: Sort into alphabetical order
      hetdb for $directoryDB tag {name title} {
        set menu [menu url $menu "gopher://localhost:7070/1$selectorMountPath/$tag_name" $tag_title]
      }
    } else {
      set menu [menu info $menu "Tags: [join $selectorTags ", "]"]
      # TODO: add a menu header command to make above a title
      set menu [menu info $menu ""]
      # TODO: Change menu command to use upvar
      # TODO: Change for command to prefix vars with table name and be able to
      # TODO: select any valid field with missing fields returned blank
      hetdb for $directoryDB link {url title tags} {
        set tagsMatch true
        foreach tag $selectorTags {
          if {$tag ni $link_tags} {
            set tagsMatch false
            break
          }
        }
        if {$tagsMatch} {
          set menu [menu url $menu $link_url $link_title]
        } else {
          return [list error "path not found"]
        }
      }
    }
    set menuText [menu render $menu]
    cache store cache $selector $menuText
  }
  return [list text $menuText]
}


# Serve a html page for cases when the selector begins with 'URL:' followed by
# a URL.  This is for clients that don't support the 'URL:' selector prefix so
# that they can be served a html page which points to the URL.  This conforms
# to:
#   gopher://bitreich.org:70/1/scm/gopher-protocol/file/references/h_type.txt.gph
proc gophser::ServeURL {selectorPath} {
  set htmlTemplate {
  <HTML>
    <HEAD>
      <META HTTP-EQUIV="refresh" content="2;URL=@URL">
    </HEAD>
    <BODY>
      You are following a link from gopher to a web site.  You will be
      automatically taken to the web site shortly.  If you do not get sent
      there, please click
      <A HREF="@URL">here</A> to go to the web site.
      <P>
      The URL linked is:
      <P>
      <A HREF="@URL">@URL</A>
      <P>
      Thanks for using gopher!
    </BODY>
  </HTML>
  }
  set url [regsub {^URL:[ ]*(.*)$} $selectorPath {\1}]
  return [list text [string map [list @URL $url] $htmlTemplate]]
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


# Supports protocols: gopher, ssh, http, https
proc gophser::menu::url {menu url userName} {
  lassign [SplitURL $url] protocol host port path type

  switch $protocol {
    gopher {
      # Should conform to RFC 4266
      if {$type eq ""} { set type 1 }
      if {$port eq ""} { set port 70 }
      return [item $menu $type $userName $path $host $port]
    }
    ssh -
    http -
    https {
      # Conforms to: gopher://bitreich.org:70/1/scm/gopher-protocol/file/references/h_type.txt.gph
      # 'host' and 'port' point to the gopher server that provided the
      # directory this is to support clients that don't support the
      # URL: prefix.  These clients should be served a HTML page which points
      # to the desired URL.
      # TODO: defaults seems like the wrong name when it refers to this server
      # TODO: look at a better name than defaults
      set host [dict get $menu defaults hostname]
      set port [dict get $menu defaults port]
      return [item $menu "h" $userName "URL:$url" $host $port]
    }
  }
  # TODO: Support gophers protocol in future?
  return -code error "unsupported protocol: $protocol"
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

  set itemTypeMap {text 0 0 0 menu 1 1 1 info i i i html h h h}
  if {![dict exists $itemTypeMap $itemType]} {
    return -code error "unknown item type: $itemType"
  }
  set itemType [dict get $itemTypeMap $itemType]

  # TODO: Handle if menu selector is blank should it be "/"? - Is that true?

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


# Split up a URL to return a list containing {protocol host port path type}
# where type is a gopher item type if relevant
proc gophser::menu::SplitURL {url} {
  regexp {^(.*):\/\/([^:/]+)(:[0-9]*)?(.*)$} $url - protocol host port path
  set port [string trimleft $port {:}]
  set type ""
  if {$protocol in {gopher gophers}} {
    regexp {^\/(.)(.*)$} $path - type path
  }
  return [list $protocol $host $port $path $type]
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
# TODO: Should probably change this to safeFilePath and move it somewhere else
proc gophser::router::safeSelector {selectorPath} {
  # TODO: Work out how safe this selector really is
  # TODO: and whether this should be done at this
  # TODO: point or when actually handling file
  # TODO: path
  if {[string match {URL:*} $selectorPath]} {
    return [string trim $selectorPath]
  }
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

