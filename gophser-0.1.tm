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
  variable responses [dict create]
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

# Store data for selector in the cache
proc gophser::cache::store {cacheVar selector data {keepSeconds 60}} {
  upvar $cacheVar cache
  set expireTime [clock add [clock seconds] $keepSeconds seconds]
  dict set cache store $selector [list $expireTime $data]
}


# Fetch data for selector from the cache
# Return: data or {} is not in cache
proc gophser::cache::fetch {cacheVar selector} {
  upvar $cacheVar cache
  set currentTime [clock seconds]
  set cleanupTime [dict get $cache details cleanupTime]
  
  # Clean up expired entries if it has been over 360 seconds since last done
  if {$currentTime - $cleanupTime > 360} {
    set cache [Cleanup $cache]
  }

  if {![dict exists $cache store $selector]} {
    return {}
  }

  lassign [dict get $cache store $selector] expireTime data

  # Remove entry if expired
  if {$currentTime > $expireTime} {
    dict unset cache store $selector
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
  dict for {selector entry} $store {
    lassign $entry expireTime
    # If current time is past the expire time
    if {$currentTime > $expireTime} {
      lappend expiredSelectors $selector
    }
  }
  foreach selector $expiredSelectors {
    dict unset cache store $selector
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
  variable databases [dict create]
}


proc gophser::gophermap::process {menu localDir selector selectorMountPath selectorSubPath} {
  variable descriptions

  set selectorLocalDir [::gophser::MakeSelectorLocalPath $localDir $selectorSubPath]
  set gophermapPath [file join $selectorLocalDir gophermap]

  try {
    set fd [open $gophermapPath r]
    set db [::read $fd]
    close $fd
  } on error err {
    # TOOD: log error
    return -code error "error processing: $gophermapPath, for selector: $selector, $err"
  }

  # TODO: create a validate command
  if {![IsDict $db]} {
    # TOOD: log error and improve error message
    return -code error "error processing: $gophermapPath, for selector: $selector, structure isn't valid"
  }

  return [ProcessMenu $menu $db $selectorLocalDir $selector $selectorMountPath $selectorSubPath]
}


# Returns whether value is a valid dictionary
# TODO: Place somewhere else
proc gophser::gophermap::IsDict value {
  expr {![catch {dict size $value}]}
}


# TODO: refine and reduce if possible the paths being passed as args
proc gophser::gophermap::ProcessMenu {menu db selectorLocalDir selector selectorMountPath selectorSubPath} {
  # TODO: in validation table menu must exist
  if {[dict exists $db menu title]} {
    set menu [H1 $menu [dict get $db menu title]]
  }
  set sections [::gophser::DictGetDef $db menu sections {}]
  foreach sectionID $sections {
    set menu [ProcessSection $menu $db $sectionID $selectorLocalDir $selector $selectorMountPath $selectorSubPath]
  }
  return $menu
}


# TODO: consider arg order here and in other commands
# TODO: Cache sections?
proc gophser::gophermap::ProcessSection {menu db sectionID selectorLocalDir selector selectorMountPath selectorSubPath} {
  if {![dict exists $db section]} {
    # TODO: raise error and log error if section doesn't exist
  }
  if {![dict exists $db section $sectionID]} {
    # TODO: raise error and log error if sectionID doesn't exist
  }

  set section [dict get $db section $sectionID]
  if {[dict exists $section title]} {
    set menu [H2 $menu [dict get $section title]]
  }

  if {[dict exists $section intro]} {
    foreach line [dict get $section intro] {
      set menu [::gophser::menu::info $menu $line]
    }
    set menu [::gophser::menu::info $menu ""]
  }


  # TODO: Rethink items as not really happy with it
  set menu [ProcessItems $menu [::gophser::DictGetDef $section items {}]]

  if {[dict exists $section dir]} {
    # TODO: add support for a filepath or pattern or other options, sort?
    set descriptions [::gophser::DictGetDef $db description {}]
    set menu [gophser::gophermap::Dir $menu $descriptions $selectorLocalDir \
                                      $selectorMountPath $selectorSubPath]
  }
  return $menu

}


proc gophser::gophermap::ProcessItems {menu items} {
  # TODO: Rethink items as not really happy with it
  foreach item $items {
    # TODO: support another key for info types, such as text rather than username?
    set item_username [::gophser::DictGetDef $item username ""]
    set item_type [::gophser::DictGetDef $item type ""]
    set item_selector [::gophser::DictGetDef $item selector ""]
    set item_hostname [::gophser::DictGetDef $item hostname ""]
    set item_port [::gophser::DictGetDef $item port ""]
    # TODO: this will remove defaults from hostname and port and needs to be hardened
    # TODO: add ability to addd description
    # TODO: Should catch and rewrap errors
    set menu [::gophser::menu::item $menu $item_type $item_username \
                                    $item_selector $item_hostname $item_port]
  }
  return $menu
}


proc gophser::gophermap::H1 {menu text} {
  set textlen [string length $text]
  if {$textlen > 65} {
    # TODO: Generate a warning
  }
  # TODO: Should we call menu:: directory for H1, H2 and H3
  #

  set menu [::gophser::menu::info $menu [string repeat "=" [expr {$textlen+4}]]]
  set menu [::gophser::menu::info $menu "= $text ="]
  set menu [::gophser::menu::info $menu [string repeat "=" [expr {$textlen+4}]]]
  set menu [::gophser::menu::info $menu ""]
  return $menu
}


proc gophser::gophermap::H2 {menu text} {
  set textlen [string length $text]
  if {$textlen > 69} {
    # TODO: Generate a warning
  }
  set underlineCh "="

  # TODO: check if there is a blank line before in menu and put one if not
  set menu [::gophser::menu::info $menu $text]
  set menu [::gophser::menu::info $menu [string repeat $underlineCh $textlen]]
  set menu [::gophser::menu::info $menu ""]
  return $menu
}


# TODO: Add support for this, perhaps in items
proc gophser::gophermap::H3 {text} {
  set textlen [string length $text]
  if {$textlen > 69} {
    # TODO: Generate a warning
  }
  set underlineCh "-"

  Item info $text
  Item info [string repeat $underlineCh $textlen]
  Item info ""
}


# Display the files in the current directory
# TODO: be able to specify a glob pattern?
proc gophser::gophermap::Dir {menu descriptions localDir selectorMountPath selectorSubPath} {
  return [::gophser::ListDir -descriptions $descriptions \
                             $menu $localDir \
                             $selectorMountPath [string trimleft $selectorSubPath "/"]]
}



# TODO: Add support for this, perhaps in items
# TODO: Or support a urls entry with an option description
proc gophser::gophermap::Url {username url } {
  variable menu
  set menu [::gophser::menu::url $menu $username $url]
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


# Route handlers
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#


package require hetdb


# selectorMountPath  is the path that localDir resides in the selector hierarchy
# TODO: Test how this handles an empty selector, the same as "/"?
# TODO: Test that selector must begin with "/" this will help avoid selector
# TODO: confusion - document this reason
proc gophser::ServePath {request localDir selectorMountPath} {
  variable cache
  set selector [dict get $request selector]
  # TODO: Create a proc to do this neatly
  if {$selectorMountPath eq "/" && $selector eq ""} {
    set subPath ""
  } else {
    set subPath [stripSelectorPrefix $selectorMountPath $selector]
  }
  set subPath [string trimleft [selectorToSafeFilePath $subPath] "/"]
  set path [file join $localDir $subPath]

  if {![file exists $path]} {
    log warning "local path doesn't exist: $path for selector: $selector"
    return [dict create type error value "path not found"]
  }

  set pathPermissions [file attributes $path -permissions]
  if {($pathPermissions & 4) != 4} {
    log warning "local path isn't world readable: $path for selector: $selector"
    return [dict create type error value "path not found"]
  }

  if {[file isfile $path]} {
    # TODO: Don't allow gophermap to be downloaded
    # TODO: Support caching when file isn't too big?
    return [dict create type text value [ReadFile $path]]
  } elseif {[file isdirectory $path]} {
    # TODO: Should this be moved above?
    set menuText [cache fetch cache $selector]
    if {$menuText eq {}} {
      set selectorLocalDir [MakeSelectorLocalPath $localDir $subPath]
      set menu [menu create localhost 7070]
      # TODO: Rename gophermap
      if {[file exists [file join $selectorLocalDir gophermap]]} {
        # TODO: could we just pass selectorLocalDir into process? or even open the
        # TODO: the gophermap here and then send it to process?
        set menu [gophermap::process $menu $localDir $selector $selectorMountPath $subPath]
      } else {
        set menu [ListDir $menu $selectorLocalDir $selectorMountPath $subPath]
      }
      set menuText [menu render $menu]
      cache store cache $selector $menuText
    }
    return [dict create type text value $menuText]
  }
  error "TODO: what is this?"
}


# selectorMountPath is the path that localDir resides in the selector hierarchy
#                   TODO: change to selectorPrefix?
# TODO: Rename?
# TODO: Format for linkDirectory  dict or hetdb?
# TODO: Add a description to link directory entries
# TODO: Add an intro text for first page
# TODO: Add layout in which to list links or intro text for the directory
# TODO: Test how this handles an empty selector, the same as "/"?
proc gophser::ServeLinkDirectory {request directoryDB selectorMountPath} {
  # TODO: Support caching? - needs testing
  variable cache
  set selector [dict get $request selector]
  set menuText [cache fetch cache $selector]
  if {$menuText eq {}} {
    # TODO: Create a proc to do this neatly
    if {$selectorMountPath eq "/" && $selector eq ""} {
      set subPath ""
    } else {
      set subPath [stripSelectorPrefix $selectorMountPath $selector]
    }
    set subPath [string trimleft [selectorToSafeFilePath $subPath] "/"]
    set selectorTags [split $subPath "/"]
    # TODO: Need to find a better way of handling default host and port here and below
    set menu [menu create localhost 7070]
    if {$subPath eq ""} {
      # TODO: Display an intro text - perhaps with some links
      # TODO: Sort into alphabetical order
      hetdb for $directoryDB tag {name title} {
        set menu [menu item $menu menu $tag_title "$selectorMountPath/$tag_name"]
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
          set menu [menu url $menu $link_title $link_url]
        } else {
          return [dict create type error value "path not found"]
        }
      }
    }
    set menuText [menu render $menu]
    cache store cache $selector $menuText
  }
  return [dict create type text value $menuText]
}


# Serve a html page for cases when the selector begins with 'URL:' followed by
# a URL.  This is for clients that don't support the 'URL:' selector prefix so
# that they can be served a html page which points to the URL.  This conforms
# to:
#   gopher://bitreich.org:70/1/scm/gopher-protocol/file/references/h_type.txt.gph
proc gophser::ServeURL {request} {
  set selector [dict get $request selector]
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

  if {![regexp {^URL:([^\s]*)$} $selector - url]} {
    log warning "malformed URL: selector: $selector"
    return [dict create type error value "malformed URL: selector"]
  }
  return [dict create type text value [string map [list @URL $url] $htmlTemplate]]
}


# Helper commands
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#
# TODO: Put these somewhere else, only here to help cleanup and organize
# TODO: the code - also have tests for this file in helpers.test

# mount localDir selectorMountPath
#
# localDir: The local absolute directory path
# selectorMountPath: The path for the selector which must not contain wildcards
#  TODO: Strip trailing slash on selectorMountPath and test
proc gophser::mount {localDir selectorMountPath} {
  set localDir [string trim $localDir]
  set selectorMountPath [selectorToSafeFilePath $selectorMountPath]

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
  if {$selectorMountPath eq "/"} {
    set selectorMountPathGlob "*"
  } else {
    set selectorMountPathGlob "$selectorMountPath/*"
  }

  # Match with and without trailing slash
  set routeArgs [list $localDir $selectorMountPath]
  route $selectorMountPath $routeArgs {{request localDir selectorMountPath} {
    gophser::ServePath $request $localDir $selectorMountPath
  }}
  route $selectorMountPathGlob $routeArgs {{request localDir selectorMountPath} {
    gophser::ServePath $request $localDir $selectorMountPath
  }}
}


proc gophser::provideLinkDir {directoryDB selectorMountPath} {
  if {[string match {*[*?]*} $selectorMountPath] ||
      [string match {*\[*} $selectorMountPath] ||
      [string match {*\]*} $selectorMountPath]} {
    return -code error "selector can not contain wildcards"
  }

  # TODO: relook at whether safeSelector use is appropriate here
  if {$selectorMountPath eq "/"} {
    set selectorMountPathGlob "*"
  } else {
    set selectorMountPathGlob "$selectorMountPath/*"
  }
  # TODO: Find a better way of doing this
  set routeArgs [list $directoryDB $selectorMountPath]
  route $selectorMountPath $routeArgs {{request directoryDB selectorMountPath} {
    gophser::ServeLinkDirectory $request $directoryDB $selectorMountPath
  }}
  route $selectorMountPathGlob $routeArgs {{request directoryDB selectorMountPath} {
    gophser::ServeLinkDirectory $request $directoryDB $selectorMountPath
  }}
}


# Turns a selector into a safe file path
# It is important that selectors are passed through this before being used
# as a file path.
# TODO: Only allow absolute paths
# TODO: Strip out anything including and past a tab
# Convert spaces to % notation
# Resolves .. without going past root of path
# Removes . directory element
# Supports directory elements beginning with ~
# This ensures there is a leading "/"
# TODO: Put this in a collection of safety functions
proc gophser::selectorToSafeFilePath {selector} {
  set selector [string map {" " "%20"} $selector]
  set elements [file split $selector]
  set path [list]
  foreach e $elements {
    if {$e eq ".."} {
      set path [lreplace $path end end]
    } elseif {$e ne "." && $e ne "/"} {
      if {[string match {./*} $e]} {
        set e [string range $e 2 end]
      }
      lappend path $e
    }
  }

  if {[llength $path] == 0} {
    return {/}
  }

  return "/[file join {*}$path]"
}


# Remove the prefix from the selector
# This is useful to remove mount points and to access variables
# passed in the selector path.
# TODO: Should this be exported?
proc gophser::stripSelectorPrefix {prefix selector} {
  if {![regexp "^${prefix}(.*)$" $selector - subSelector]} {
    return -code error "selector: $selector does not contain prefix: $prefix"
  }
  return $subSelector
}


# TODO: Work out at what point the sub path is safe
proc gophser::MakeSelectorLocalPath {localDir selectorSubPath} {
  set localDir [string trimleft $localDir "."]
  set localDir [file normalize $localDir]
  return [file join $localDir $selectorSubPath]
}


# TODO: define using dict getdef if present
proc gophser::DictGetDef {dictionaryValue args} {
  if {[llength $args] < 2} {
    return -code "wrong # args: should be \"DictGetDef dictionaryValue ?key ...? key default\""
  }
  set default [lindex $args end]
  set keys [lrange $args 0 end-1]
  if {[dict exists $dictionaryValue {*}$keys]} {
    return [dict get $dictionaryValue {*}$keys]
  }
  return $default
}


# TODO: Pass descriptions as arg rather than via switch
# listDir ?switches? menu selectorLocalDir selectorMountPath selectorSubPath
# switches:
#  -descriptions descriptions  Dictionary of descriptions for each filename
#
# arguments:
#   selectorSubPath  must be a relative math
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

  lassign $args menu selectorLocalDir selectorMountPath selectorSubPath
  set dirs [glob -tails -type d -nocomplain -directory $selectorLocalDir *]
  set dirs [lsort -nocase $dirs]
  set files [glob -tails -type f -nocomplain -directory $selectorLocalDir *]
  set files [lsort -nocase $files]


  set prevFileDescribed false   ; # This prevents a double proceeding new line
  foreach entriesDF [list [list d $dirs] [list f $files]] {
    lassign $entriesDF type entries
    foreach localName $entries {
      # TODO: Rename gophermap?
      if {$localName eq "gophermap"} {
        continue
      }
      set description [DictGetDef $descriptions $localName description ""]
      set username [DictGetDef $descriptions $localName username $localName]
      set group [DictGetDef $descriptions $localName group {}]

      # If a description exists then put a blank line before file
      if {!$prevFileDescribed && $description ne ""} {
        set menu [menu info $menu ""]
        set prevFileDescribed true
      } else {
        set prevFileDescribed false
      }

      set selector [MakeSelectorPath $selectorMountPath $selectorSubPath $localName]
      if {$type eq "f"} {
        set menu [menu item $menu text $username $selector]
      } else {
        # Directory
        set menu [menu item $menu menu $username $selector]
      }

      foreach groupItem $group {
        lassign $groupItem groupItemName groupItemUsername
        set selector [MakeSelectorPath $selectorMountPath $selectorSubPath $groupItemName]

        if {$groupItemUsername eq ""} {
          set groupItemUsername $groupItemName
        }
        # If a directory
        if {[lsearch $dirs $groupItemName] >= 0} {
          set menu [menu item $menu menu $groupItemUsername $selector]
        } else {
          # Else a file
          # TODO: check exists in files because may not exist at all
          # TODO: file type detection using extension and a file program?
          set menu [menu item $menu image $groupItemUsername $selector]
        }
      }

      # If a description exists then put it after the file
      if {$description ne ""} {
        set menu [menu info $menu $description]
      }

      if {$description ne {} || $group ne {}} {
        set menu [menu info $menu ""]
      }
    }
  }
  return $menu
}


# Join path components to make a selector path beginning with "/" and with
# each component joined with "/"
# TODO: rename and test
proc gophser::MakeSelectorPath {args} {
  return "/[string trimleft [join [concat {*}$args] "/"] "/"]"
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
proc gophser::menu::url {menu userName url} {
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

  set itemTypeMap {text 0 0 0 menu 1 1 1 info i i i html h h h image I I I}
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
# funcArgs A list of arguments to use after the request when applying the func
# func     A function suitable for the apply command
proc gophser::router::route {pattern funcArgs func} {
  variable routes
  lappend routes [list $pattern $funcArgs $func]
  Sort
}


# TODO: rename
proc gophser::router::getHandler {selector} {
  variable routes
  foreach route $routes {
    lassign $route pattern funcArgs func
    if {[string match $pattern $selector]} {
      return [list $funcArgs $func]
    }
  }
  return {}
}


# Sort the routes from most specific to least specific
proc gophser::router::Sort {} {
  variable routes
  set routes [lsort -command CompareRoutes $routes]
}


# Compare the routes for lsort to determine which is most specific
# TODO: This compares assuming routes are based on paths whose components are
# TODO: joined with "/" - revisit this and test properly.
proc gophser::router::CompareRoutes {a b} {
  set patternPartsA [split [lindex $a 0] "/"]
  set patternPartsB [split [lindex $b 0] "/"]
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

