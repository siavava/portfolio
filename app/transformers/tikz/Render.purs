-- | ## Render
-- |
-- | The pure side of the build-time TikZ renderer, and its TypeScript
-- | facade. `transformers/tikz/render.ts` works on a raw markdown body:
-- | it parses the `$$…tikzpicture…$$` blocks here, compiles each through
-- | node-tikzjax (cached on disk by source hash), and splices the results
-- | back here, either as a `:tikz-figure` placeholder or, when a block
-- | fails, as a ` ```tikz ` fence the client `<TikzDiagram>` renders. The
-- | TeX, caption, and SVG helpers of the sibling modules are defined again
-- | below rather than re-exported, since declarations are generated from
-- | a module's own definitions. @ts-internal
module App.Transformers.Tikz.Render
  ( Operator
  , Renderers
  , TexParts
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
  ) where

import Prelude

import App.Transformers.Tikz.Caption (extractCaption, renderCaptionWith)
import App.Transformers.Tikz.Svg as Svg
import App.Transformers.Tikz.Tex (hoistDefineColor)
import App.Transformers.Tikz.Tex as Tex
import Data.Array (catMaybes, foldl, index, mapWithIndex, snoc)
import Data.Array.NonEmpty as NEA
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Nullable (Nullable, toMaybe, toNullable)
import Data.String (joinWith)
import Data.String.Regex (Regex, match, replace, split)
import Data.String.Regex.Flags (global, noFlags)
import Data.String.Regex.Unsafe (unsafeRegex)

-- | One parsed `$$…$$` block: its caption (`null` without one), the
-- | tikz-3dplot setup lines (empty without any), the picture with its
-- | `\definecolor`s hoisted, and the source the figure's cache key hashes.
type TikzBlock =
  { caption :: Nullable String
  , setup :: String
  , code :: String
  , keySource :: String
  }

-- | The caption renderers `figureHtml` takes: `math` turns one bare TeX
-- | expression into HTML (KaTeX), `inline` renders inline markdown
-- | (`marked`). Restated here, like the two synonyms below, so the
-- | generated declarations can name them.
type Renderers = { math :: String -> String, inline :: String -> String }

-- | What `texDocument` wraps: the operator preamble, the setup lines
-- | (empty without any), and the picture.
type TexParts = { preamble :: String, setup :: String, code :: String }

-- | One operator of the preamble: the command name with its backslash,
-- | and its `\operatorname{…}` body.
type Operator = { name :: String, body :: String }

-- | Both groups always participate, so `split` yields `[text, lead, picture, text, …]`.
tikzBlockRegex :: Regex
tikzBlockRegex = unsafeRegex
  ( "\\$\\$\\s*((?:(?:%[^\\n]*|\\\\tdplot[^\\n]*)\\n\\s*)*)"
      <> "(\\\\begin\\{(?:tikzpicture|tikzcd)\\}[\\s\\S]*?\\\\end\\{(?:tikzpicture|tikzcd)\\})"
      <> "\\s*\\$\\$"
  )
  noFlags

tdplotLine :: Regex
tdplotLine = unsafeRegex "\\\\tdplot[^\\n]*" global

-- | Every `$$…tikzpicture…$$` block of a markdown body, in order. The
-- | setup lines are pulled out of the leading block so the renderer
-- | re-emits them ahead of the picture, and they are folded into the
-- | cache key.
tikzBlocks :: String -> Array TikzBlock
tikzBlocks body = foldl collect [] (mapWithIndex { i: _, chunk: _ } chunks)
  where
  chunks = split tikzBlockRegex body
  collect acc { i, chunk: lead }
    | i `mod` 3 == 1 = snoc acc (block lead (fromMaybe "" (index chunks (i + 1))))
    | otherwise = acc

block :: String -> String -> TikzBlock
block lead picture =
  { caption: toNullable (extractCaption lead)
  , setup
  , code
  , keySource: if setup == "" then code else setup <> "\n" <> code
  }
  where
  setup = joinWith "\n" (maybe [] (catMaybes <<< NEA.toArray) (match tdplotLine lead))
  code = hoistDefineColor picture

-- | Replaces the blocks of a body, in order, with the given replacements;
-- | the text between them is kept. A missing replacement is spliced in as
-- | `undefined`, as the original's `replacements[i++]` callback returned.
spliceTikzBlocks :: Array String -> String -> String
spliceTikzBlocks replacements body =
  joinWith "" (mapWithIndex piece (split tikzBlockRegex body))
  where
  piece i chunk = case i `mod` 3 of
    0 -> chunk
    1 -> fromMaybe "undefined" (index replacements (i / 3))
    _ -> ""

-- | The block-level MDC component a rendered figure becomes; the page
-- | fetches its cached SVG by hash.
figurePlaceholder :: String -> String
figurePlaceholder key = "\n\n:tikz-figure{hash=\"" <> key <> "\"}\n\n"

lineBreakRuns :: Regex
lineBreakRuns = unsafeRegex "\\s*\\n\\s*" global

-- | The ` ```tikz ` fence a block falls back to when it fails to render,
-- | its caption (line breaks folded to spaces) riding in the info string.
fallbackFence :: Nullable String -> String -> String
fallbackFence caption code =
  "\n\n```tikz" <> meta <> "\n" <> code <> "\n```\n\n"
  where
  meta = case toMaybe caption of
    Just text | text /= "" -> " " <> replace lineBreakRuns " " text
    _ -> ""

newlineRuns :: Regex
newlineRuns = unsafeRegex "\\n{2,}" global

newlines :: Regex
newlines = unsafeRegex "\\n" global

-- | The cached figure: the post-processed SVG on one line inside
-- | `figure.tikz-figure.tikz-diagram-rendered`, followed by the rendered
-- | caption as `figcaption.tikz-cap` when there is one.
figureHtml :: Renderers -> Nullable String -> String -> String
figureHtml renderers caption svg =
  "\n\n<figure class=\"tikz-figure tikz-diagram-rendered\">" <> inline <> cap <> "</figure>\n\n"
  where
  inline = replace newlines "" (replace newlineRuns "\n" svg)
  cap = case toMaybe caption of
    Just text | text /= "" ->
      "<figcaption class=\"tikz-cap\">" <> renderCaptionWith renderers text <> "</figcaption>"
    _ -> ""

-- | The document node-tikzjax compiles (see `Tex.texDocument`).
texDocument :: TexParts -> String
texDocument parts = Tex.texDocument parts

-- | The TeX packages a figure loads, in option order (see
-- | `Tex.texPackages`).
texPackages :: { setup :: String, code :: String } -> Array String
texPackages source = Tex.texPackages source

-- | The TikZ libraries every figure loads.
tikzLibraries :: String
tikzLibraries = Tex.tikzLibraries

-- | The `\providecommand` operator preamble (see `Tex.operatorPreamble`).
operatorPreamble :: Array Operator -> String
operatorPreamble operators = Tex.operatorPreamble operators

-- | The SVG post-processing pass run after text outlining (see
-- | `Svg.postProcessSvg`).
postProcessSvg :: String -> String
postProcessSvg svg = Svg.postProcessSvg svg
