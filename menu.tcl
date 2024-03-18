# Menu handling
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#
package require textutil

namespace eval gophers::menu {
  namespace export {[a-z]*}
  namespace ensemble create
}


proc gophers::menu::create {{defaultHost localhost} {defaultPort 70} } {
  set defaults [dict create hostname $defaultHost port $defaultPort]
  dict create defaults $defaults menu {}
}


# Add information text
# The text will be wrapped if the line length exceeds 80 characters
# TODO: Work out what length to set this to wrap
proc gophers::menu::info {menuVar text} {
  upvar $menuVar menuVal
  item menuVal info $text FAKE
}


# Add an item to the menu
proc gophers::menu::item {menuVar itemType userName selector {hostname {}} {port {}}} {
  upvar $menuVar menuVal
  if {$hostname eq {}} {
    set hostname [dict get $menuVal defaults hostname]
  }
  if {$port eq {}} {
    set port [dict get $menuVal defaults port]
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
      dict lappend menuVal menu [list $itemType "" $selector $hostname $port]
    }
    foreach t [split $text "\n"] {
      # TODO: Work out what's best to put as the selector in this case
      # TODO: Work out what to put as host and port
      dict lappend menuVal menu [list $itemType $t $selector $hostname $port]
    }
  } else {
    dict lappend menuVal menu [list $itemType $userName $selector $hostname $port]
  }
}


# Render the menu as text ready for sending
proc gophers::menu::render {menuVal} {
  set menuStr ""
  foreach item [dict get $menuVal menu] {
    lassign $item type userName selector hostname port
    set itemStr "$type$userName\t$selector\t$hostname\t$port\r\n"
    append menuStr $itemStr
  }
  append menuStr ".\r\n"
  return $menuStr
}
