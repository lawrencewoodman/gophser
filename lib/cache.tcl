# Cache selector paths
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

# TODO: Test cache

# TODO: Create an new or similar command to create a new cache and pass as variable

# Put data for selectorPath in the cache
proc gophser::cache::store {selectorPath data {keepSeconds 60}} {
  variable store
  set expireTime [clock add [clock seconds] $keepSeconds seconds]
  dict set store $selectorPath [list $expireTime $data]
}


# Return: {exists data}
proc gophser::cache::fetch {selectorPath} {
  variable store
  variable cleanTime

  set currentTime [clock seconds]
  
  # Clean up expired entries if it has been over 360 seconds since last done
  if {$currentTime - $cleanTime > 360} {
    Cleanup
  }

  if {![dict exists $store $selectorPath]} {
    return {false {}}
  }

  lassign [dict get $store $selectorPath] expireTime data

  # Remove entry if expired
  if {$currentTime > $expireTime} {
    Remove $selectorPath
    return {false {}}
  }
  return [list true $data]
}


proc gophser::cache::Remove {selectorPath} {
  variable store
  dict unset store $selectorPath
}


# Remove any cache entries that have expired
# This is used to prevent the cache from taking up too much memory
proc gophser::cache::Cleanup {} {
  variable store
  variable cleanTime
  set cleanTime [clock seconds]
  set expiredSelectors [list]
  dict for {selectorPath entry} $store {
    lassign $entry expireTime
    # If current time is past the expire time
    if {[clock seconds] > $expireTime} {
      lappend expiredSelectors $selectorPath
    }
  }
  foreach selectorPath $expiredSelectors {
    Remove $selectorPath
  }
}
