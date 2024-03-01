# Menu handling
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#


namespace eval gophers::menu {
  namespace export {[a-z]*}
  namespace ensemble create
}


proc gophers::menu::create {{defaultHost localhost} {defaultPort 70} } {
  set defaults [dict create hostname $defaultHost port $defaultPort]
  dict create defaults $defaults menu {}
}


proc gophers::menu::addFile {menuVar itemType displayString selector {hostname {}} {port {}}} {
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
    default {
      # TODO: Have this as a warning only?
      error "unknown item type: $itemType"
    }
  }
  dict lappend menuVal menu [list $itemType $displayString $selector $hostname $port]
}


proc gophers::menu::addMenu {menuVar displayString selector {hostname {}} {port {}}} {
  upvar $menuVar menuVal
  if {$hostname eq {}} {
    set hostname [dict get $menuVal defaults hostname]
  }
  if {$port eq {}} {
    set port [dict get $menuVal defaults port]
  }
  dict lappend menuVal menu [list 1 $displayString $selector $hostname $port]
}


# Render the menu as text ready for sending
proc gophers::menu::render {menuVal} {
  set menuStr ""
  foreach item [dict get $menuVal menu] {
    lassign $item type displayString selector hostname port
    set itemStr "$type$displayString\t$selector\t$hostname\t$port\n"
    append menuStr $itemStr
  }
  return $menuStr
}
