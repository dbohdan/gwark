{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE PatternGuards         #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE ViewPatterns          #-}
{- |
   Module      : Text.Pandoc.Readers.LaTeX
   Copyright   : Copyright (C) 2006-2024 John MacFarlane
   License     : GNU GPL, version 2 or above

   Maintainer  : John MacFarlane <jgm@berkeley.edu>
   Stability   : alpha
   Portability : portable

Stripped-down LaTeX reader for the lean fork. Only what the Markdown
reader needs is exported:

  * 'applyMacros' (re-exported from "Text.Pandoc.Readers.LaTeX.Parsing")
  * 'rawLaTeXBlock' and 'rawLaTeXInline' for the @raw_tex@ extension.

The @latex@ input format itself is no longer wired up; this module is
only here so the @+raw_tex@ and @+latex_macros@ extensions of the
Markdown reader keep working.
-}
module Text.Pandoc.Readers.LaTeX
  ( applyMacros
  , rawLaTeXBlock
  , rawLaTeXInline
  ) where

import Control.Applicative (many, optional, (<|>))
import Control.Monad (void, guard)
import Data.Text (Text)
import qualified Data.Text as T
import Text.Pandoc.Class (PandocMonad)
import Text.Pandoc.Parsing hiding (blankline, many, mathDisplay, mathInline,
                                   optional, space, spaces, withRaw, (<|>))
import Text.Pandoc.TeX (Tok (..), TokType (..))
import Text.Pandoc.Readers.LaTeX.Macro (macroDef)
import Text.Pandoc.Readers.LaTeX.Math (inlineEnvironmentNames)
import Text.Pandoc.Readers.LaTeX.Parsing

-- | Parse a raw LaTeX block. Used by the Markdown reader's @raw_tex@
-- extension to detect block-level @\\command@ or
-- @\\begin{env}...\\end{env}@ sequences.
rawLaTeXBlock :: (PandocMonad m, HasMacros s, HasReaderOptions s)
              => ParsecT Sources s m Text
rawLaTeXBlock = do
  lookAhead (try (char '\\' >> letter))
  toks <- getInputTokens
  snd <$> rawLaTeXParser toks blockSnippet blockSnippet
  where
    blockSnippet =     macroDef (const ())
                   <|> void rawEnvironment
                   <|> void rawCommand

-- | Parse a raw LaTeX inline. Used by the Markdown reader's @raw_tex@
-- extension.
rawLaTeXInline :: (PandocMonad m, HasMacros s, HasReaderOptions s)
               => ParsecT Sources s m Text
rawLaTeXInline = do
  lookAhead (try (char '\\' >> letter))
  toks <- getInputTokens
  raw <- snd <$> rawLaTeXParser toks inlineSnippet inlineSnippet
  finalbraces <- mconcat <$> many (try (string "{}")) -- see #5439
  return $ raw <> T.pack finalbraces
  where
    inlineSnippet = mathEnvBegin <|> rawCommand

-- | Recognize @\\begin{env}...\\end{env}@ for math environments
-- (recognized by 'inlineEnvironmentNames').
mathEnvBegin :: PandocMonad m => LP m ()
mathEnvBegin = try $ do
  void $ controlSeq "begin"
  envName <- braced
  let nm = untokenize envName
  guard (nm `elem` inlineEnvironmentNames)
  void $ manyTill anyTok (try (controlSeq "end" >> bracedExact nm))

-- | Match @{...}@ where the content is exactly the given text.
bracedExact :: PandocMonad m => Text -> LP m ()
bracedExact target = try $ do
  toks <- braced
  guard (untokenize toks == target)

-- | Recognize a generic @\\command[opt]{arg}{arg}...@. We do not
-- interpret the command; we only consume enough tokens that the caller
-- can grab the raw source.
rawCommand :: PandocMonad m => LP m ()
rawCommand = try $ do
  Tok _ (CtrlSeq _) _ <- anyControlSeq
  optional (symbol '*')
  skipMany rawArg
  where
    rawArg = try (void rawopt) <|> try (sp >> void braced)

-- | Recognize a complete @\\begin{env}...\\end{env}@ block, regardless
-- of @env@. Used by 'rawLaTeXBlock'.
rawEnvironment :: PandocMonad m => LP m ()
rawEnvironment = try $ do
  void $ controlSeq "begin"
  envName <- untokenize <$> braced
  skipMany (try (void rawopt) <|> try (void braced))
  void $ manyTill (try nestedEnv <|> void anyTok)
                  (try (controlSeq "end" >> bracedExact envName))
  where
    nestedEnv = try $ do
      lookAhead (try (controlSeq "begin"))
      rawEnvironment
