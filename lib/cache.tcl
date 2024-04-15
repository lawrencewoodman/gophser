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
  # TODO: Store expire time rather than curren time?
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
