# A Gopher Server
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#


source "routing.tcl"
source "gophers.tcl"
source "config.tcl"

gophers::init
vwait forever
gophers::shutdown
