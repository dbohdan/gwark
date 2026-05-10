{-# LANGUAGE OverloadedStrings #-}
import Text.Pandoc
import Text.Pandoc.Walk (walk)
import qualified Data.Text.IO as T
import qualified Data.Text as Text

sampleMarkdown :: Text.Text
sampleMarkdown = Text.unlines
  [ "# Test Doc"
  , ""
  , "Paragraph with *emphasis*, **strong**, and `code`."
  , ""
  , "[Link](https://example.com) and an image: ![alt](img.png)."
  , ""
  , "> Blockquote"
  , ">"
  , "> with multiple paragraphs."
  , ""
  , "- bullet 1"
  , "- bullet 2"
  , ""
  , "1. ordered"
  , "2. items"
  , ""
  , "| Col1 | Col2 |"
  , "|------|------|"
  , "| a    | b    |"
  , ""
  , "Math: $x^2 + y^2 = z^2$ and display:"
  , ""
  , "$$\\int_0^\\infty e^{-x} dx = 1$$"
  , ""
  , "```haskell"
  , "main = putStrLn \"hello\""
  , "```"
  , ""
  , "Footnote[^1]."
  , ""
  , "[^1]: footnote text"
  , ""
  , "\\newcommand{\\xx}[1]{X#1X}"
  , "Macro: $\\xx{42}$."
  ]

main :: IO ()
main = do
  result <- runIO $ do
    p <- readMarkdown def{readerExtensions = pandocExtensions} sampleMarkdown
    let p' = walk (id :: Inline -> Inline) p
    html <- writeHtml5String
              def{ writerHTMLMathMethod = MathJax defaultMathJaxURL
                 , writerExtensions = pandocExtensions
                 } p'
    md <- writeMarkdown
            def{ writerExtensions = pandocExtensions
               , writerColumns = 9999
               } p'
    plain <- writePlain
               def{writerColumns = 9999} p'
    return (html, md, plain)
  case result of
    Left e -> error (show e)
    Right (html, md, plain) -> do
      putStrLn "=== HTML ==="
      T.putStrLn html
      putStrLn "=== Markdown ==="
      T.putStrLn md
      putStrLn "=== Plain ==="
      T.putStrLn plain
