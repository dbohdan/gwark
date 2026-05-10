{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE MonoLocalBinds      #-}
{-# LANGUAGE RankNTypes          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections       #-}
{- |
   Module      : Text.Pandoc.Readers
   Copyright   : Copyright (C) 2006-2024 John MacFarlane
   License     : GNU GPL, version 2 or above

   Maintainer  : John MacFarlane <jgm@berkeley.edu>
   Stability   : alpha
   Portability : portable

This helper module exports the readers.

Note:  all of the readers assume that the input text has @'\n'@
line endings.  So if you get your input text from a web form,
you should remove @'\r'@ characters using @filter (/='\r')@.

-}

module Text.Pandoc.Readers
  (
    -- * Readers: converting /to/ Pandoc format
    Reader (..)
  , readers
  , readMarkdown
  , readHtml
  , readNative
  , readJSON
  -- * Miscellaneous
  , getReader
  , getDefaultExtensions
  ) where

import Control.Monad.Except (throwError)
import Data.Aeson
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as T
import Text.Pandoc.Class
import Text.Pandoc.Definition
import Text.Pandoc.Error
import Text.Pandoc.Extensions
import qualified Text.Pandoc.Format as Format
import Text.Pandoc.Options
import Text.Pandoc.Readers.Markdown
import Text.Pandoc.Readers.HTML (readHtml)
import Text.Pandoc.Readers.Native
import qualified Text.Pandoc.UTF8 as UTF8
import Text.Pandoc.Sources (ToSources(..), sourcesToText)

data Reader m = TextReader (forall a . ToSources a =>
                                ReaderOptions -> a -> m Pandoc)
              | ByteStringReader (ReaderOptions -> BL.ByteString -> m Pandoc)

-- | Association list of formats and readers. The lean fork keeps only
-- Markdown (with all flavor aliases routed to the same reader), HTML,
-- LaTeX, Native, and JSON.
readers :: PandocMonad m => [(Text, Reader m)]
readers = [("native"             , TextReader readNative)
          ,("json"               , TextReader readJSON)
          ,("markdown"           , TextReader readMarkdown)
          ,("html"               , TextReader readHtml)
          ]

-- | Retrieve reader, extensions based on format spec (format+extensions).
getReader :: PandocMonad m => Format.FlavoredFormat -> m (Reader m, Extensions)
getReader flvrd = do
  let readerName = Format.formatName flvrd
  case lookup readerName readers of
    Nothing  -> throwError $ PandocUnknownReaderError readerName
    Just  r  -> (r,) <$>
      Format.applyExtensionsDiff (Format.getExtensionsConfig readerName) flvrd

-- | Read pandoc document from JSON format.
readJSON :: (PandocMonad m, ToSources a)
         => ReaderOptions
         -> a
         -> m Pandoc
readJSON _ s =
  case eitherDecode' . BL.fromStrict . UTF8.fromText
                     . sourcesToText . toSources $ s of
       Right doc -> return doc
       Left e    -> throwError $ PandocParseError ("JSON parse error: "
                                                   <> T.pack e)
