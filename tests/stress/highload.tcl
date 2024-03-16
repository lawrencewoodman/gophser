set ThisScriptDir [file dirname [info script]]
set RepoRootDir [file join $ThisScriptDir .. ..]
source [file join $ThisScriptDir .. test_helpers.tcl]


proc stressServer {numConnections selectors} {
  foreach selector $selectors {
    set elapsed [time {
      for {set i 0} {$i < $numConnections} {incr i} {
        TestHelpers::gopherGet localhost 7070 $selector
      }
    }]
    set ms [scan $elapsed {%f microseconds per iteration}]
    outputStat $selector [expr {$ms / $numConnections}]
  }
}


proc stressServerSwarm {numConnections selectors} {
  foreach selector $selectors {
    set elapsed [time {
      TestHelpers::gopherSwarmGet $numConnections localhost 7070 $selector
    }]
    TestHelpers::gopherSwarmGetVerifyResults
    set ms [scan $elapsed {%f microseconds per iteration}]
    outputStat $selector [expr {$ms / $numConnections}]
  }
}


proc outputStat {name elapsed} {
  set msPerConnection [scan $elapsed {%f microseconds per iteration}]
  set connectionsPerSec [expr {1000000 / $elapsed}]

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
  "  set str {}" \
  "  for {set i 0} {\$i < 9999} {incr i} {" \
  "    append str {abcdefghijklmnopqrstuvwxyz0123}" \
  "  }" \
  "  return \$str" \
  "}"] "\n"]

#set selectors {"/tests/"}
#set selectors {"/say/hello"}
set selectors {
  "/bigfile" "/say/hello" "/tests/test_helpers.tcl" "/tests/"
  "/tests/fixtures/"
}
#set selectors {"/bigfile"}
set serverThread [TestHelpers::startServer $configContent]

puts "Consecutive Connections"
puts "=======================\n"
set timings [stressServer 800 $selectors]

puts "Simultaneous Connections"
puts "========================\n"
set timings [stressServerSwarm 800 $selectors]
TestHelpers::shutdownServer $serverThread

