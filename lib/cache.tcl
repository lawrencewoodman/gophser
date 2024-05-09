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
# Return: {exists data}
proc gophser::cache::fetch {cacheVar selectorPath} {
  upvar $cacheVar cache
  set currentTime [clock seconds]
  set cleanupTime [dict get $cache details cleanupTime]
  
  # Clean up expired entries if it has been over 360 seconds since last done
  if {$currentTime - $cleanupTime > 360} {
    set cache [Cleanup $cache]
  }

  if {![dict exists $cache store $selectorPath]} {
    return {false {}}
  }

  lassign [dict get $cache store $selectorPath] expireTime data

  # Remove entry if expired
  if {$currentTime > $expireTime} {
    dict unset cache store $selectorPath
    return {false {}}
  }
  return [list true $data]
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

