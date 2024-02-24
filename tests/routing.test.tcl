package require tcltest
namespace import tcltest::*

set ThisScriptDir [file dirname [info script]]
set RepoRootDir [file join $ThisScriptDir ..]

source [file join $ThisScriptDir test_helpers.tcl]
source [file join $RepoRootDir routing.tcl]

# Create the routes to test against
urlrouter::route "" testRoot
urlrouter::route "/files" testFiles
urlrouter::route "/files/*" testFilesSplat
urlrouter::route "/{dir}/{filename}" testDirFilename


proc testRoot {sock url} {
  TestHelpers::SetHandlerVars [list testRoot $sock $url]
}

proc testFiles {sock args} {
  TestHelpers::SetHandlerVars [list testFiles $sock {*}$args]
}


proc testFilesSplat {sock args} {
  TestHelpers::SetHandlerVars [list testFilesSplat $sock {*}$args]
}

proc testDirFilename {sock args} {
  TestHelpers::SetHandlerVars [list testDirFilename $sock {*}$args]
}


test handleURL-1 {Return false if route not found} \
-setup {
  set sock 1
  set url "bob"
} -body {
  urlrouter::handleURL $sock $url
} -result false


test handleURL-2 {Detect an empty pattern for the root} \
-setup {
  TestHelpers::ResetHandlerVars
  set sock 2
  set url ""
} -body {
  list [urlrouter::handleURL $sock $url] {*}[TestHelpers::GetHandlerVars]
} -result [list true testRoot 2 ""]


test handleURL-3 {Detect an empty pattern for the root with a trailing slash} \
-setup {
  TestHelpers::ResetHandlerVars
  set sock 3
  set url {/}
} -body {
  list [urlrouter::handleURL $sock $url] {*}[TestHelpers::GetHandlerVars]
} -result [list true testRoot 3 {/}]


test handleURL-4 {Detect a single splat on its own} \
-setup {
  TestHelpers::ResetHandlerVars
  set sock 4
  set url {/files/fred.txt}
} -body {
  list [urlrouter::handleURL $sock $url] {*}[TestHelpers::GetHandlerVars]
} -result [list true testFilesSplat 4 {/files/fred.txt} {fred.txt}]


test handleURL-5 {Detect a single splat on its own against multiple sub-directories} \
-setup {
  TestHelpers::ResetHandlerVars
  set sock 5
  set url {/files/something/bob.txt}
} -body {
  list [urlrouter::handleURL $sock $url] {*}[TestHelpers::GetHandlerVars]
} -result [list true testFilesSplat 5 {/files/something/bob.txt} {something/bob.txt}]


test handleURL-6 {Detect named parameters} \
-setup {
  TestHelpers::ResetHandlerVars
  set sock 6
  set url {/dirA/someFile.txt}
} -body {
  list [urlrouter::handleURL $sock $url] {*}[TestHelpers::GetHandlerVars]
} -result [list true testDirFilename 6 {/dirA/someFile.txt} {dirA} {someFile.txt}]


test handleURL-7 {Detect exact path} \
-setup {
  TestHelpers::ResetHandlerVars
  set sock 7
  set url {/files}
} -body {
  list [urlrouter::handleURL $sock $url] {*}[TestHelpers::GetHandlerVars]
} -result [list true testFiles 7 {/files}]


test handleURL-8 {Detect exact path with trailing slash} \
-setup {
  TestHelpers::ResetHandlerVars
  set sock 8
  set url {/files/}
} -body {
  list [urlrouter::handleURL $sock $url] {*}[TestHelpers::GetHandlerVars]
} -result [list true testFiles 8 {/files/}]

test removal of .. and ./

test NormalizeURL-1 {} \
-setup {
  set tests {
    {/tests tests}
  }
} -body {
  set res {}
  foreach test $tests {
    lassign $test url want
    lappend res [list $url [urlrouter::NormalizeURL $url] $want]
  }
  set res
} -result [list {tests tests tests}]
