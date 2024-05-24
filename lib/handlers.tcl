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
    set menuText [cache fetch cache $selectorPath]
    if {$menuText eq {}} {
      set selectorLocalPath [MakeSelectorLocalPath $localDir $selectorSubPath]
      set menu [menu create localhost 7070]
      # TODO: Rename gophermap
      if {[file exists [file join $selectorLocalPath gophermap]]} {
        set menu [gophermap::process $menu $localDir $selectorMountPath $selectorSubPath]
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

