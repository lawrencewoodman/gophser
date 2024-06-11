apply {{} {
  set thisScriptDir [file dirname [info script]]
  set moduleDir [file normalize [file join $thisScriptDir .. ..]]
  set modules [lsort -decreasing [glob -directory $moduleDir gophser-*.tm]]
  source [lindex $modules 0]
  source [file join $moduleDir tests test_helpers.tcl]
  TestHelpers::setRepoRootDir $moduleDir
}}

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

set configScript {
  proc makeBigStr {} {
    set str {}
    for {set i 0} {$i < 9999} {incr i} {
      append str {abcdefghijklmnopqrstuvwxyz0123}
    }
    return $str
  }


  set bigStr [makeBigStr]
  gophser::log suppress all
  gophser::route "/bigfile" [list $bigStr] {{request bigStr} {
    set selector [dict get $request selector]
    return [dict create type text value $bigStr]
  }}
  gophser::route "/say/*" {} {{request} {
    set selector [dict get $request selector]
    set word [gophser::stripSelectorPrefix "/say" $selector]
    return [dict create type text value [string map {"%20" " "} $word]]
  }}
  gophser::mount [file normalize $repoRootDir] "/"
}


set selectors {
  "/bigfile" "/tests/test_helpers.tcl" "/tests/" "/tests/fixtures/"
  "/say/hello"
}


set serverThread [TestHelpers::startServer $configScript]

puts "Consecutive Connections"
puts "=======================\n"
set timings [stressServer 800 $selectors]

puts "Simultaneous Connections"
puts "========================\n"
set timings [stressServerSwarm 800 $selectors]
TestHelpers::shutdownServer $serverThread

