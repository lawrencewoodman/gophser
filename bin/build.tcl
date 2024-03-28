# Script to build the module

proc appendFileToModule {fdModule filename} {
  set fd [open $filename r]
  puts $fdModule [read $fd]
  close $fd
}

# TODO: Add error detection

proc buildModule {configDir config} {
  set name [dict get $config name]
  set version [dict get $config version]
  set summary [dict get $config summary]
  set files [dict get $config files]
  set moduleFilename "$name-$version.tm"
  
  puts "Building: $moduleFilename"
  set fdModule [open $moduleFilename w]
  puts $fdModule "# Module: $name v$version"
  puts $fdModule "# $summary"
  puts $fdModule "#"
  # TODO: Add more to header, what it was built with
  
  foreach file $files {
    set incFiles [
      list {*}[glob -directory $configDir $file] \
    ]

    foreach incFile [lsort $incFiles] {
      puts "  Adding file: $incFile"
      appendFileToModule $fdModule $incFile
    }
  }
  close $fdModule
}


proc loadBuildFile {filename} {
  set fd [open $filename r]
  set buildConfig [read $fd]
  set buildLines {}
  foreach line [split $buildConfig "\n"] {
    if {![regexp -- {\s*#.*$} $line]} {
      lappend buildLines $line
    }  
  }
  close $fd
  return [join $buildLines "\n"]
}



lassign $argv buildFilename
set buildConfigDir [file dirname $buildFilename]
set buildConfig [loadBuildFile $buildFilename]

buildModule $buildConfigDir $buildConfig
