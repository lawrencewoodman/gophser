# Helper functions for the tests

namespace eval TestHelpers {
    variable handlerVars {}
}

proc TestHelpers::SetHandlerVars {vars} {
    variable handlerVars
    lappend handlerVars $vars
}

proc TestHelpers::GetHandlerVars {} {
    variable handlerVars
    return {*}$handlerVars
}

proc TestHelpers::ResetHandlerVars {} {
    variable handlerVars
    set handlerVars {}
}