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


# TODO: Remove addFile and addMenu and just use item
proc gophers::menu::addFile {menuVar itemType userName selector {hostname {}} {port {}}} {
  upvar $menuVar menuVal
  if {$itemType ni {0 text}} {
    # TODO: Have this as a warning only?
    error "unknown file item type: $itemType"
  }
  AddItem menuVal $itemType $userName $selector $hostname $port
}


proc gophers::menu::addMenu {menuVar userName selector {hostname {}} {port {}}} {
  upvar $menuVar menuVal
  AddItem menuVal menu $userName $selector $hostname $port
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

# TODO: rename to item
proc gophers::menu::AddItem {menuVar itemType userName selector {hostname {}} {port {}}} {
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
    default {
      # TODO: Have this as a warning only?
      error "unknown item type: $itemType"
    }
  }
  dict lappend menuVal menu [list $itemType $userName $selector $hostname $port]
}
