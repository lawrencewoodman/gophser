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

