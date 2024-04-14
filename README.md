Gophers
=======

A [Gopher](https://en.wikipedia.org/wiki/Gopher_(protocol)) server module
written in Tcl.

The module makes it easy to create simple or complex gopher servers by
requiring this module in a Tcl script and then configuring the server as
needed.  The servers can act as an embedded server within a program or as
a standalone server.

Conforms to [RFC 1436 - The Internet Gopher Protocol](https://datatracker.ietf.org/doc/html/rfc1436).


Requirements
------------
* Tcl 8.6+
* Tcllib


Build
-----
The source code for the module is in `lib/`.
To build the module use [buildtm](https://github.com/lawrencewoodman/buildtm).

    $ tclsh buildtm.tcl gophser.build


Testing
-------
There is a testsuite in `tests/`.  To run it:

    $ tclsh tests/all.tcl


Licence
-------
Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>

This software is licensed under an MIT Licence.  Please see the file, [LICENCE.md](https://github.com/lawrencewoodman/gophser/blob/master/LICENCE.md), for details.
