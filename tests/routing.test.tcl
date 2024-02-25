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


test getHandlerInfo-1 {Return false if route not found} \
-setup {
  set url "bob"
} -body {
  urlrouter::getHandlerInfo $url
} -result {}


test getHandlerInfo-2 {Detect an empty pattern for the root} \
-setup {
  set url ""
} -body {
  urlrouter::getHandlerInfo $url
} -result [list testRoot {/}]


test getHandlerInfo-3 {Detect an empty pattern for the root with a trailing slash} \
-setup {
  set url {/}
} -body {
  urlrouter::getHandlerInfo $url
} -result [list testRoot {/}]


test getHandlerInfo-4 {Detect a single splat on its own} \
-setup {
  set url {/files/fred.txt}
} -body {
  urlrouter::getHandlerInfo $url
} -result [list testFilesSplat {/files/fred.txt fred.txt}]


test getHandlerInfo-5 {Detect a single splat on its own against multiple sub-directories} \
-setup {
  set url {/files/something/bob.txt}
} -body {
  urlrouter::getHandlerInfo $url
} -result [list testFilesSplat {/files/something/bob.txt something/bob.txt}]


test getHandlerInfo-6 {Detect named parameters} \
-setup {
  set url {/dirA/someFile.txt}
} -body {
  urlrouter::getHandlerInfo $url
} -result [list testDirFilename {/dirA/someFile.txt dirA someFile.txt}]


test getHandlerInfo-7 {Detect exact path} \
-setup {
  set url {/files}
} -body {
  urlrouter::getHandlerInfo $url
} -result [list testFiles  {/files}]


test getHandlerInfo-8 {Detect exact path with trailing slash} \
-setup {
  set url {/files/}
} -body {
  urlrouter::getHandlerInfo $url
} -result [list testFiles {/files}]


test SafeURL-1 {} \
-setup {
  set tests {
    /tests
    /fred/bob/dave
    /fred/bob/..
    /fred/bob/../..
    /./gerald/.
    /~fred
    /.fred
  }
} -body {
  set res {}
  foreach test $tests {
    lassign $test url want
    lappend res [urlrouter::SafeURL $url]
  }
  set res
} -result [list /tests /fred/bob/dave /fred / /gerald /~fred \
                /.fred]
