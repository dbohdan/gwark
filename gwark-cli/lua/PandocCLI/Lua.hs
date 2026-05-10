{-# LANGUAGE OverloadedStrings #-}
{- |
   Module      : PandocCLI.Lua
   Copyright   : © 2022-2024 Albert Krewinkel, 2026 dbohdan
   License     : GPL-2.0-or-later

Lua-enabled scripting engine for the gwark CLI. Selected via
@cabal flag(lua)@ (default @True@). The REPL (@gwark lua ...@) is
not exposed; Lua filters via @--lua-filter=FILE.lua@ are the only
supported entry point.
-}
module PandocCLI.Lua (getEngine) where

import Text.Pandoc.Lua (getEngine)
