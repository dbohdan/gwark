{-# LANGUAGE OverloadedStrings #-}
-- | Imports every Text.Pandoc symbol that Hakyll and gwern.net's
-- build/ directory rely on. If this compiles, the fork is API-compatible
-- with downstream consumers.
module ApiSurface where

import Text.Pandoc
  ( runPure, def
  , Pandoc(..), Block(..), Inline(..), Format(..)
  , nullMeta, nullAttr, MathType(..)
  , ReaderOptions, WriterOptions
  , readerExtensions, writerExtensions, writerColumns
  , writerSectionDivs, writerTableOfContents
  , writerHTMLMathMethod, writerHighlightMethod
  , HTMLMathMethod(..), defaultMathJaxURL
  , WrapOption(WrapPreserve), HighlightMethod(..)
  , readMarkdown, readHtml
  , writeMarkdown, writeHtml5String
  , pandocExtensions, enableExtension, disableExtension
  , Extension(..)
  )
import Text.Pandoc.Walk (walk, walkM, query)
import Text.Pandoc.Builder (setMeta, Blocks, Inlines)
import Text.Pandoc.Class (PandocMonad)
import Text.Pandoc.Highlighting (pygments)
import Text.Pandoc.Writers.Markdown (writePlain)
import Text.Pandoc.Generic (topDown, bottomUp, bottomUpM)

-- Reference every imported binding so a clean compile error fires if
-- any of them no longer resolves.
_apiCheck :: ()
_apiCheck =
  let _ = (runPure, def, nullMeta, nullAttr, defaultMathJaxURL)
      _ = (readMarkdown, readHtml, writeMarkdown, writeHtml5String, writePlain)
      _ = (walk, walkM, query, topDown, bottomUp, bottomUpM)
      _ = (pandocExtensions, enableExtension, disableExtension, setMeta)
      _ = (pygments, MathJax, KaTeX, MathML, PlainMath, WrapPreserve)
      _ = (Pandoc, Block, Inline, Format, MathType, Blocks, Inlines)
      _ = (readerExtensions, writerExtensions, writerColumns,
           writerSectionDivs, writerTableOfContents,
           writerHTMLMathMethod, writerHighlightMethod)
      _ = (NoHighlighting, IdiomaticHighlighting, DefaultHighlighting)
  in ()
