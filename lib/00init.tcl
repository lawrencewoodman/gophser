# Gopher Server Module
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

namespace eval gophers {
  namespace export {[a-z]*}

  # TODO: Rename listen
  variable listen
  variable sendMsgs [dict create]
  # TODO: improve statuses
  # Status of a send:
  #  waiting: waiting for something to send
  #  ready:   something is ready to send
  #  done:    nothing left to send, close
  variable sendStatus [dict create]
  variable configOptions [dict create logger [dict create suppress none]]
}
