{-# LANGUAGE OverloadedStrings #-}
{- |
   Module      : PandocCLI.Lua
   Copyright   : © 2022-2024 Albert Krewinkel, 2026 dbohdan
   License     : GPL-2.0-or-later

Stub used when gwark-cli is built with @-flag(lua)@. Returns the
no-op scripting engine; @--lua-filter=...@ then fails at run time
with @PandocNoScriptingEngine@.
-}
module PandocCLI.Lua (getEngine) where

import Control.Monad.IO.Class (MonadIO)
import Text.Pandoc.Scripting (ScriptingEngine, noEngine)

getEngine :: MonadIO m => m ScriptingEngine
getEngine = pure noEngine
