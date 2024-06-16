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
