# Route handlers
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#


# selectorPath is the complete path requested.  This is assumed to have
#              been made safe.
# selectorMountPath is the path that localDir resides in the selector hierarchy
proc gophser::ServePath {localDir selectorMountPath selectorPath} {
  variable cache
  set selectorSubPath [stripSelectorPrefix $selectorMountPath $selectorPath]
  set path [file join $localDir $selectorSubPath]

  if {![file exists $path]} {
    log warning "local path doesn't exist: $path for selector: $selectorPath"
    return [list error "path not found"]
  }

  set pathPermissions [file attributes $path -permissions]
  if {($pathPermissions & 4) != 4} {
    log warning "local path isn't world readable: $path for selector: $selectorPath"
    return [list error "path not found"]
  }

  if {[file isfile $path]} {
    # TODO: Don't allow gophermap to be downloaded
    # TODO: Support caching when file isn't too big?
    return [list text [ReadFile $path]]
  } elseif {[file isdirectory $path]} {
    # TODO: Should this be moved above?
    set menuText [cache fetch cache $selectorPath]
    if {$menuText eq {}} {
      set selectorLocalPath [MakeSelectorLocalPath $localDir $selectorSubPath]
      set menu [menu create localhost 7070]
      # TODO: Rename gophermap
      if {[file exists [file join $selectorLocalPath gophermap]]} {
        set menu [gophermap::process $menu $localDir $selectorPath $selectorMountPath $selectorSubPath]
      } else {
        set menu [ListDir $menu $localDir $selectorMountPath $selectorSubPath]
      }
      set menuText [menu render $menu]
      cache store cache $selectorPath $menuText
    }
    return [list text $menuText]
  }
  error "TODO: what is this?"
}


# selectorMountPath is the path that localDir resides in the selector hierarchy
#                   TODO: change to selectorPrefix?
# selector is the complete path requested.  This is assumed to have
#              been made safe.
# TODO: Rename?
# TODO: Format for linkDirectory  dict or hetdb?
# TODO: Add a description to link directory entries
# TODO: Add an intro text for first page
# TODO: Add layout in which to list links or intro text for the directory
proc gophser::ServeLinkDirectory {directoryDB selectorMountPath selector} {
  # TODO: Support caching? - needs testing
  variable cache
  set menuText [cache fetch cache $selector]
  if {$menuText eq {}} {
    set selectorSubPath [stripSelectorPrefix $selectorMountPath $selector]
    set selectorTags [split $selectorSubPath "/"]
    # TODO: Need to find a better way of handling default host and port here and below
    set menu [menu create localhost 7070]
    if {$selectorSubPath eq ""} {
      # TODO: Display an intro text - perhaps with some links
      # TODO: Sort into alphabetical order
      hetdb for $directoryDB tag {name title} {
        lassign [dict values $tag] name title
        set menu [menu url $menu "gopher://localhost:7070/1$selectorMountPath/$name" $title]
      }
    } else {
      set menu [menu info $menu "Tags: [join $selectorTags ", "]"]
      # TODO: add a menu header command to make above a title
      set menu [menu info $menu ""]
      # TODO: Change menu command to use upvar
      # TODO: Change for command to prefix vars with table name and be able to
      # TODO: select any valid field with missing fields returned blank
      hetdb for $directoryDB link {url title tags} {
        lassign [dict values $link] url title tags
        set tagsMatch true
        foreach tag $selectorTags {
          if {$tag ni $tags} {
            set tagsMatch false
            break
          }
        }
        if {$tagsMatch} {
          set menu [menu url $menu $url $title]
        } else {
          return [list error "path not found"]
        }
      }
    }
    set menuText [menu render $menu]
    cache store cache $selector $menuText
  }
  return [list text $menuText]
}


# Serve a html page for cases when the selector begins with 'URL:' followed by
# a URL.  This is for clients that don't support the 'URL:' selector prefix so
# that they can be served a html page which points to the URL.  This conforms
# to:
#   gopher://bitreich.org:70/1/scm/gopher-protocol/file/references/h_type.txt.gph
proc gophser::ServeURL {selectorPath} {
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
  set url [regsub {^URL:[ ]*(.*)$} $selectorPath {\1}]
  return [list text [string map [list @URL $url] $htmlTemplate]]
}

