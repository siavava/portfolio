-- | Cases for the render facade of the build-time TikZ renderer, recorded
-- | from the TypeScript `transformers/tikz/render.ts` before the move: a
-- | multi-block body (a caption wrapped over comments, a `\definecolor`
-- | inside an option list, a one-line `tikzcd`, tikz-3dplot setup lines,
-- | display math and a malformed lead that must not match), splicing
-- | replacements back literally, the fallback fence, and the figure HTML
-- | through stub caption renderers.
module Test.Transformers.TikzRender (suite) where

import Prelude

import App.Transformers.Tikz.Render
  ( Renderers
  , TikzBlock
  , fallbackFence
  , figureHtml
  , figurePlaceholder
  , operatorPreamble
  , postProcessSvg
  , spliceTikzBlocks
  , texDocument
  , texPackages
  , tikzBlocks
  , tikzLibraries
  )
import App.Transformers.Tikz.Tex as Tex
import Data.Array (index, length)
import Data.Maybe (Maybe(..))
import Data.Nullable (notNull, null)
import Data.String (joinWith)
import Effect (Effect)
import Test.Harness (Tally, expect)

body :: String
body =
  joinWith "\n"
    [ "# Heading"
    , ""
    , "Some prose with display math:"
    , ""
    , "$$ x^2 + y^2 $$"
    , ""
    , "$$"
    , "% caption: A coloured node with $\\alpha$"
    , "%   wrapped onto a second line."
    , "\\begin{tikzpicture}["
    , "  \\definecolor{myblue}{RGB}{30,60,200}"
    , "  node distance=2cm]"
    , "\\node[fill=myblue] (a) {$a$};"
    , "\\end{tikzpicture}"
    , "$$"
    , ""
    , "Between the figures."
    , ""
    , "$$\\begin{tikzcd} A \\arrow[r] & B \\end{tikzcd}$$"
    , "$$"
    , "% caption: A 3-D frame"
    , "\\tdplotsetmaincoords{70}{110}"
    , "  % a stray comment"
    , "\\tdplotsetrotatedcoords{0}{0}{0}"
    , "\\begin{tikzpicture}[tdplot_main_coords]"
    , "\\draw[->] (0,0,0) -- (1,0,0);"
    , "\\end{tikzpicture}"
    , "$$"
    , ""
    , "$$"
    , "\\node {not a lead line};"
    , "\\begin{tikzpicture}\\end{tikzpicture}"
    , "$$"
    , ""
    , "Tail text."
    ]

plain :: String
plain = "No figures here, just $$ x $$ math."

adjacent :: String
adjacent =
  "$$\\begin{tikzpicture}\\draw;\\end{tikzpicture}$$$$\\begin{tikzpicture}\\fill;\\end{tikzpicture}$$"

svg :: String
svg = "<svg width=\"1\">\n\n\n<g/>\n<path/>\n</svg>\n"

block0 :: TikzBlock
block0 =
  { caption: notNull "A coloured node with $\\alpha$ wrapped onto a second line."
  , setup: ""
  , code:
      "\\definecolor{myblue}{RGB}{30,60,200}\n\\begin{tikzpicture}[\n  node distance=2cm]\n\\node[fill=myblue] (a) {$a$};\n\\end{tikzpicture}"
  , keySource:
      "\\definecolor{myblue}{RGB}{30,60,200}\n\\begin{tikzpicture}[\n  node distance=2cm]\n\\node[fill=myblue] (a) {$a$};\n\\end{tikzpicture}"
  }

block1 :: TikzBlock
block1 =
  { caption: null
  , setup: ""
  , code: "\\begin{tikzcd} A \\arrow[r] & B \\end{tikzcd}"
  , keySource: "\\begin{tikzcd} A \\arrow[r] & B \\end{tikzcd}"
  }

block2 :: TikzBlock
block2 =
  { caption: notNull "A 3-D frame a stray comment"
  , setup: "\\tdplotsetmaincoords{70}{110}\n\\tdplotsetrotatedcoords{0}{0}{0}"
  , code:
      "\\begin{tikzpicture}[tdplot_main_coords]\n\\draw[->] (0,0,0) -- (1,0,0);\n\\end{tikzpicture}"
  , keySource:
      "\\tdplotsetmaincoords{70}{110}\n\\tdplotsetrotatedcoords{0}{0}{0}\n\\begin{tikzpicture}[tdplot_main_coords]\n\\draw[->] (0,0,0) -- (1,0,0);\n\\end{tikzpicture}"
  }

stubs :: Renderers
stubs = { math: \e -> "<m>" <> e <> "</m>", inline: \s -> "<i>" <> s <> "</i>\n\n" }

suite :: Tally -> Effect Unit
suite t = do
  expect t "tikzBlocks: count, skipping display math and a bad lead" 3
    (length (tikzBlocks body))
  expect t "tikzBlocks: block 0" (Just block0) (index (tikzBlocks body) 0)
  expect t "tikzBlocks: block 1" (Just block1) (index (tikzBlocks body) 1)
  expect t "tikzBlocks: block 2" (Just block2) (index (tikzBlocks body) 2)
  expect t "tikzBlocks: a body without figures" 0 (length (tikzBlocks plain))
  expect t "tikzBlocks: adjacent blocks"
    [ "\\begin{tikzpicture}\\draw;\\end{tikzpicture}"
    , "\\begin{tikzpicture}\\fill;\\end{tikzpicture}"
    ]
    (map _.code (tikzBlocks adjacent))
  expect t "spliceTikzBlocks: replacements in order, literally"
    "# Heading\n\nSome prose with display math:\n\n$$ x^2 + y^2 $$\n\n<A>\n\nBetween the figures.\n\n<B $& $1>\n<C>\n\n$$\n\\node {not a lead line};\n\\begin{tikzpicture}\\end{tikzpicture}\n$$\n\nTail text."
    (spliceTikzBlocks [ "<A>", "<B $& $1>", "<C>" ] body)
  expect t "spliceTikzBlocks: a missing replacement reads undefined"
    "# Heading\n\nSome prose with display math:\n\n$$ x^2 + y^2 $$\n\n<A>\n\nBetween the figures.\n\nundefined\nundefined\n\n$$\n\\node {not a lead line};\n\\begin{tikzpicture}\\end{tikzpicture}\n$$\n\nTail text."
    (spliceTikzBlocks [ "<A>" ] body)
  expect t "spliceTikzBlocks: extra replacements unused" "12"
    (spliceTikzBlocks [ "1", "2", "3", "4" ] adjacent)
  expect t "spliceTikzBlocks: a body without figures" "No figures here, just $$ x $$ math."
    (spliceTikzBlocks [] plain)
  expect t "figurePlaceholder" "\n\n:tikz-figure{hash=\"ab12\"}\n\n" (figurePlaceholder "ab12")
  expect t "fallbackFence: no caption" "\n\n```tikz\n\\draw;\n```\n\n"
    (fallbackFence null "\\draw;")
  expect t "fallbackFence: empty caption" "\n\n```tikz\n\\draw;\n```\n\n"
    (fallbackFence (notNull "") "\\draw;")
  expect t "fallbackFence: caption in the info string"
    "\n\n```tikz A caption\n\\draw;\n\\fill;\n```\n\n"
    (fallbackFence (notNull "A caption") "\\draw;\n\\fill;")
  expect t "fallbackFence: caption line breaks folded" "\n\n```tikz two lines here\nx\n```\n\n"
    (fallbackFence (notNull "two\n   lines \n here") "x")
  expect t "figureHtml: no caption"
    "\n\n<figure class=\"tikz-figure tikz-diagram-rendered\"><svg width=\"1\"><g/><path/></svg></figure>\n\n"
    (figureHtml stubs null svg)
  expect t "figureHtml: empty caption"
    "\n\n<figure class=\"tikz-figure tikz-diagram-rendered\"><svg width=\"1\"><g/><path/></svg></figure>\n\n"
    (figureHtml stubs (notNull "") svg)
  expect t "figureHtml: rendered caption"
    "\n\n<figure class=\"tikz-figure tikz-diagram-rendered\"><svg width=\"1\"><g/><path/></svg><figcaption class=\"tikz-cap\"><i>with <m>x</m> math</i></figcaption></figure>\n\n"
    (figureHtml stubs (notNull "with $x$ math") svg)
  expect t "postProcessSvg facade"
    "<svg width=\"16.000\" height=\"16.000\" viewBox=\"-3 -3 16.000 16.000\"><path fill=\"currentColor\" stroke=\"var(--tk-hi)\" style=\"stroke-width:1\"/></svg>"
    ( postProcessSvg
        "<svg width=\"10\" height=\"10\" viewBox=\"0 0 10 10\"><path fill=\"#000\" stroke=\"#cc5500\" stroke-width=\"1\"/></svg>"
    )
  expect t "texDocument facade"
    (Tex.texDocument { preamble: "p", setup: "s", code: "c" })
    (texDocument { preamble: "p", setup: "s", code: "c" })
  expect t "texPackages facade" [ "amsmath", "amssymb", "tikz-3dplot" ]
    (texPackages { setup: "\\tdplotsetmaincoords{1}{2}", code: "$x$" })
  expect t "tikzLibraries facade" Tex.tikzLibraries tikzLibraries
  expect t "operatorPreamble facade" "\\providecommand{\\OPT}{\\operatorname{OPT}}%"
    (operatorPreamble [ { name: "\\OPT", body: "\\operatorname{OPT}" } ])
