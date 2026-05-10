{-# LANGUAGE CPP #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}

{- |
   Module      : Main
   Copyright   : Copyright (C) 2006-2024 John MacFarlane
   License     : GNU GPL, version 2 or above

   Maintainer  : John MacFarlane <jgm@berkeley@edu>
   Stability   : alpha
   Portability : portable

Parses command-line options and calls the appropriate readers and
writers. This is the gwark CLI entry point; it is the lean fork's
counterpart to the upstream pandoc executable.
-}
module Main where
import qualified Control.Exception as E
import System.Environment (getArgs, getProgName)
import Text.Pandoc.App ( convertWithOpts, defaultOpts, options
                       , parseOptionsFromArgs, handleOptInfo, versionInfo )
import Text.Pandoc.Error (handleError)
import Data.Monoid (Any(..))
import PandocCLI.Lua (getEngine)
import Text.Pandoc.Scripting (ScriptingEngine(..))
import qualified Data.Text as T
#ifdef NIGHTLY
import qualified Language.Haskell.TH as TH
import Data.Time
#endif

#ifdef NIGHTLY
versionSuffix :: String
versionSuffix = "-nightly-" ++
  $(TH.stringE =<<
    TH.runIO (formatTime defaultTimeLocale "%F" <$> Data.Time.getCurrentTime))
#else
versionSuffix :: String
versionSuffix = ""
#endif

main :: IO ()
main = E.handle (handleError . Left) $ do
  prg <- getProgName
  rawArgs <- getArgs
  let hasVersion = getAny $ foldMap
         (\s -> Any (s == "-v" || s == "--version"))
         (takeWhile (/= "--") rawArgs)
  let versionOr action = if hasVersion then versionInfoCLI else action
  versionOr $ do
    engine <- getEngine
    res <- parseOptionsFromArgs options defaultOpts prg rawArgs
    case res of
      Left e -> handleOptInfo engine e
      Right opts -> convertWithOpts engine opts

getFeatures :: [String]
getFeatures =
  [
#ifdef LUA
    "+lua"
#else
    "-lua"
#endif
  , "-server"
  ]

versionInfoCLI :: IO ()
versionInfoCLI = do
  scriptingEngine <- getEngine
  versionInfo getFeatures
              (Just $ T.unpack (engineName scriptingEngine))
              versionSuffix
