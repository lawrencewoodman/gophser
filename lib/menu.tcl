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

