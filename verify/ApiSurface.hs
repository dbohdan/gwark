{-# LANGUAGE OverloadedStrings #-}
module ApiSurface where

-- Imports every Text.Pandoc symbol that Hakyll and gwern.net's
-- build/ directory rely on. If this module compiles, every imported
-- name resolves; the lean fork is API-compatible with downstream
-- consumers. Each name appears in a non-ambiguous context below.

import Text.Pandoc
import Text.Pandoc.Walk (walk, walkM, query)
import Text.Pandoc.Builder (setMeta, Blocks, Inlines)
import Text.Pandoc.Class (PandocMonad)
import Text.Pandoc.Highlighting (pygments)
import Text.Pandoc.Writers.Markdown (writePlain)
import Text.Pandoc.Generic (topDown, bottomUp, bottomUpM)
import qualified Data.Text as T
import Skylighting (Style)

-- Prove every term-level symbol resolves by giving each its own
-- monomorphic binding.
sym_runPure :: PandocPure a -> Either PandocError a
sym_runPure = runPure

sym_def_reader :: ReaderOptions
sym_def_reader = def

sym_def_writer :: WriterOptions
sym_def_writer = def

sym_nullMeta :: Meta
sym_nullMeta = nullMeta

sym_nullAttr :: Attr
sym_nullAttr = nullAttr

sym_defaultMathJaxURL :: T.Text
sym_defaultMathJaxURL = defaultMathJaxURL

sym_readMarkdown :: PandocMonad m => ReaderOptions -> T.Text -> m Pandoc
sym_readMarkdown = readMarkdown

sym_readHtml :: PandocMonad m => ReaderOptions -> T.Text -> m Pandoc
sym_readHtml = readHtml

sym_writeMarkdown :: PandocMonad m => WriterOptions -> Pandoc -> m T.Text
sym_writeMarkdown = writeMarkdown

sym_writePlain :: PandocMonad m => WriterOptions -> Pandoc -> m T.Text
sym_writePlain = writePlain

sym_writeHtml5String :: PandocMonad m => WriterOptions -> Pandoc -> m T.Text
sym_writeHtml5String = writeHtml5String

sym_walk :: (Inline -> Inline) -> Pandoc -> Pandoc
sym_walk = walk

sym_walkM :: (Monad m, Applicative m) => (Inline -> m Inline) -> Pandoc -> m Pandoc
sym_walkM = walkM

sym_query :: Monoid c => (Inline -> c) -> Pandoc -> c
sym_query = query

sym_topDown :: (Inline -> Inline) -> Pandoc -> Pandoc
sym_topDown = topDown

sym_bottomUp :: (Inline -> Inline) -> Pandoc -> Pandoc
sym_bottomUp = bottomUp

sym_bottomUpM :: (Monad m, Applicative m) => (Inline -> m Inline) -> Pandoc -> m Pandoc
sym_bottomUpM = bottomUpM

sym_setMeta :: Pandoc -> Pandoc
sym_setMeta = setMeta "k" ("v" :: T.Text)

sym_pandocExtensions :: Extensions
sym_pandocExtensions = pandocExtensions

sym_extEnableDisable :: Extensions
sym_extEnableDisable = enableExtension Ext_smart $
                       disableExtension Ext_emoji pandocExtensions

sym_pygments :: Style
sym_pygments = pygments

sym_blocks :: Blocks
sym_blocks = mempty

sym_inlines :: Inlines
sym_inlines = mempty

sym_format :: Format
sym_format = Format "x"

sym_mathTypes :: [HTMLMathMethod]
sym_mathTypes = [MathJax defaultMathJaxURL, KaTeX "", MathML, PlainMath]

sym_wrap :: WrapOption
sym_wrap = WrapPreserve

sym_hl :: [HighlightMethod]
sym_hl = [NoHighlighting, IdiomaticHighlighting, DefaultHighlighting]

sym_writerFields :: WriterOptions -> WriterOptions
sym_writerFields o = o
  { writerExtensions     = pandocExtensions
  , writerColumns        = 80
  , writerSectionDivs    = True
  , writerTableOfContents= True
  , writerHTMLMathMethod = MathJax defaultMathJaxURL
  , writerHighlightMethod= NoHighlighting
  }

sym_readerFields :: ReaderOptions -> ReaderOptions
sym_readerFields o = o { readerExtensions = pandocExtensions }

sym_blockInlineMath :: (Block, Inline, MathType)
sym_blockInlineMath = (HorizontalRule, Space, InlineMath)
