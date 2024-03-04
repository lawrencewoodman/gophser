set ThisScriptDir [file dirname [info script]]
set RepoRootDir [file join $ThisScriptDir .. ..]
source [file join $ThisScriptDir .. test_helpers.tcl]


proc stressServer {selectors} {
  set timings {}
  foreach selector $selectors {
    lappend timings [time {TestHelpers::gopherGet localhost 7070 $selector} 50000]
  }
  return $timings
}

proc outputStat {name elapsed} {
  set msPerConnection [scan $elapsed {%f microseconds per iteration}]
  set msTotal [expr {$msPerConnection * 50000}]
  set secTotal [expr {$msTotal / 1000000}]
  set connectionsPerSec [expr {50000 / $secTotal}]

  puts "$name:"
  puts "   ms / connection: $msPerConnection"
  puts "  conections / sec: $connectionsPerSec\n"
}

proc outputStats {selectors timings} {
  foreach selector $selectors elapsed $timings {
    outputStat $selector $elapsed
  }
}

set configContent [join [list \
  "log suppress all" \
  "route \"/bigfile\" sendBigFile" \
  "route \"/say/{word}\" sendWord" \
  "mount \"[file normalize $RepoRootDir]\" \"/\"" \
  "proc sendWord {selector args} {" \
  "  string map {\"%20\" \" \"} \$args" \
  "}" \
  "proc sendBigFile {selector args} {" \
  "  for {set i 0} {\$i < 9999} {incr i} {" \
  "    sendText \$sock {abcdefghijklmnopqrstuvwxyz0123}" \
  "  }" \
  "}"] "\n"]

set selectors {"/tests/" "/say/hello"}
set serverThread [TestHelpers::startServer $configContent]
set timings [stressServer $selectors]
TestHelpers::shutdownServer $serverThread

outputStats $selectors $timings

