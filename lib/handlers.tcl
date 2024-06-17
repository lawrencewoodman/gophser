# Route handlers
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#


package require hetdb


# selectorMountPath  is the path that localDir resides in the selector hierarchy
# TODO: Test how this handles an empty selector, the same as "/"?
# TODO: Test that selector must begin with "/" this will help avoid selector
# TODO: confusion - document this reason
proc gophser::ServePath {request localDir selectorMountPath} {
  variable cache
  set selector [dict get $request selector]
  # TODO: Create a proc to do this neatly
  if {$selectorMountPath eq "/" && $selector eq ""} {
    set subPath ""
  } else {
    set subPath [stripSelectorPrefix $selectorMountPath $selector]
  }
  set subPath [string trimleft [selectorToSafeFilePath $subPath] "/"]
  set path [file join $localDir $subPath]

  if {![file exists $path]} {
    log warning "local path doesn't exist: $path for selector: $selector"
    return [dict create type error value "path not found"]
  }

  set pathPermissions [file attributes $path -permissions]
  if {($pathPermissions & 4) != 4} {
    log warning "local path isn't world readable: $path for selector: $selector"
    return [dict create type error value "path not found"]
  }

  if {[file isfile $path]} {
    # TODO: Don't allow gophermap to be downloaded
    return [MakeFileResponse $path]
  } elseif {[file isdirectory $path]} {
    # TODO: Should this be moved above?
    set menuText [cache fetch cache $selector]
    if {$menuText eq {}} {
      set selectorLocalDir [MakeSelectorLocalPath $localDir $subPath]
      set menu [menu create localhost 7070]
      # TODO: Rename gophermap
      if {[file exists [file join $selectorLocalDir gophermap]]} {
        # TODO: could we just pass selectorLocalDir into process? or even open the
        # TODO: the gophermap here and then send it to process?
        set menu [gophermap::process $menu $localDir $selector $selectorMountPath $subPath]
      } else {
        set menu [ListDir $menu $selectorLocalDir $selectorMountPath $subPath]
      }
      set menuText [menu render $menu]
      cache store cache $selector $menuText
    }
    return [dict create type text value $menuText]
  }
  error "TODO: what is this?"
}


# selectorMountPath is the path that localDir resides in the selector hierarchy
#                   TODO: change to selectorPrefix?
# TODO: Rename?
# TODO: Format for linkDirectory  dict or hetdb?
# TODO: Add a description to link directory entries
# TODO: Add an intro text for first page
# TODO: Add layout in which to list links or intro text for the directory
# TODO: Test how this handles an empty selector, the same as "/"?
proc gophser::ServeLinkDirectory {request directoryDB selectorMountPath} {
  # TODO: Support caching? - needs testing
  variable cache
  set selector [dict get $request selector]
  set menuText [cache fetch cache $selector]
  if {$menuText eq {}} {
    # TODO: Create a proc to do this neatly
    if {$selectorMountPath eq "/" && $selector eq ""} {
      set subPath ""
    } else {
      set subPath [stripSelectorPrefix $selectorMountPath $selector]
    }
    set subPath [string trimleft [selectorToSafeFilePath $subPath] "/"]
    set selectorTags [split $subPath "/"]
    # TODO: Need to find a better way of handling default host and port here and below
    set menu [menu create localhost 7070]
    if {$subPath eq ""} {
      # TODO: Display an intro text - perhaps with some links
      # TODO: Sort into alphabetical order
      hetdb for $directoryDB tag {name title} {
        set menu [menu item $menu menu $tag_title "$selectorMountPath/$tag_name"]
      }
    } else {
      set menu [menu info $menu "Tags: [join $selectorTags ", "]"]
      # TODO: add a menu header command to make above a title
      set menu [menu info $menu ""]
      # TODO: Change menu command to use upvar
      # TODO: Change for command to prefix vars with table name and be able to
      # TODO: select any valid field with missing fields returned blank
      hetdb for $directoryDB link {url title tags} {
        set tagsMatch true
        foreach tag $selectorTags {
          if {$tag ni $link_tags} {
            set tagsMatch false
            break
          }
        }
        if {$tagsMatch} {
          set menu [menu url $menu $link_title $link_url]
        } else {
          return [dict create type error value "path not found"]
        }
      }
    }
    set menuText [menu render $menu]
    cache store cache $selector $menuText
  }
  return [dict create type text value $menuText]
}


# Serve a html page for cases when the selector begins with 'URL:' followed by
# a URL.  This is for clients that don't support the 'URL:' selector prefix so
# that they can be served a html page which points to the URL.  This conforms
# to:
#   gopher://bitreich.org:70/1/scm/gopher-protocol/file/references/h_type.txt.gph
proc gophser::ServeURL {request} {
  set selector [dict get $request selector]
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

  if {![regexp {^URL:([^\s]*)$} $selector - url]} {
    log warning "malformed URL: selector: $selector"
    return [dict create type error value "malformed URL: selector"]
  }
  return [dict create type text value [string map [list @URL $url] $htmlTemplate]]
}

