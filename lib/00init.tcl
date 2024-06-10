# Gopher Server Module
#
# Copyright (C) 2024 Lawrence Woodman <https://lawrencewoodman.github.io/>
#
# Licensed under an MIT licence.  Please see LICENCE.md for details.
#

namespace eval gophser {
  namespace export {[a-z]*}

  # A selector cache
  variable cache
  # TODO: Rename listen
  variable listen
  variable responses [dict create]
  variable configOptions [dict create logger [dict create suppress none]]
}
