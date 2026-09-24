-- | ## Tex
-- |
-- | TeX-source munging for the build-time TikZ renderer: `\definecolor`
-- | hoisting, the operator preamble, the document node-tikzjax compiles,
-- | and the packages and libraries it loads. Pure string work with no TeX
-- | or SVG knowledge beyond the shapes below. `transformers/tikz/tex.ts`
-- | re-exports `hoistDefineColor` for the figure dev-tools; the renderer
-- | reaches the rest through `App.Transformers.Tikz.Render`. @ts-internal
module App.Transformers.Tikz.Tex
  ( Operator
  , TexParts
  , hoistDefineColor
  , operatorPreamble
  , texDocument
  , texPackages
  , tikzLibraries
  ) where

import Prelude

import Data.Array (catMaybes)
import Data.Array.NonEmpty as NEA
import Data.Maybe (maybe)
import Data.String (Pattern(..), contains, joinWith, trim)
import Data.String.Regex (Regex, match, replace)
import Data.String.Regex.Flags (global, multiline)
import Data.String.Regex.Unsafe (unsafeRegex)

-- | One `\providecommand` entry of the operator preamble: the command
-- | name with its backslash, and the `\operatorname{…}` body.
type Operator = { name :: String, body :: String }

-- | What `texDocument` wraps: the operator preamble, the tikz-3dplot
-- | setup lines (empty when the figure has none), and the picture.
type TexParts = { preamble :: String, setup :: String, code :: String }

-- | Eats the line break too: a blank line in a picture's option list is TeX's "Runaway argument".
defineColorLine :: Regex
defineColorLine =
  unsafeRegex "^[ \\t]*(\\\\definecolor\\{[^{}]*\\}\\{[^{}]*\\}\\{[^{}]*\\})[ \\t]*\\r?\\n?"
    (multiline <> global)

-- | Hoists every `\definecolor` line to before the picture. Placed inside
-- | the `\begin{tikzpicture}[…]` option list (a common authoring slip) it
-- | is invalid TeX (`\XC@definec@lor has an extra }`) and silently drops
-- | the whole diagram to the client fallback; defining the colour up front
-- | is always valid. Code without a definition comes back unchanged.
-- |
-- | Trimming each whole-line match gives exactly the definition: it
-- | starts with a backslash and ends with a brace, while the edges the
-- | pattern consumed are only spaces, tabs, and an optional line break.
hoistDefineColor :: String -> String
hoistDefineColor code = case defs of
  [] -> code
  _ -> joinWith "\n" defs <> "\n" <> replace defineColorLine "" code
  where
  defs = maybe [] (map trim <<< catMaybes <<< NEA.toArray) (match defineColorLine code)

-- | One `\providecommand{name}{body}%` line per operator. node-tikzjax
-- | runs real TeX, which does not load the KaTeX macro map, so this is
-- | how figure node text gets the prose shortcuts (`\argmax`, `\OPT`, …).
-- | `\providecommand` stores each body inertly, so a figure that never
-- | uses one pays nothing. Every line ends with `%`: TeX turns each line
-- | end into a space token, and the ~125 invisible spaces would otherwise
-- | accumulate before the picture, shifting it ~400pt right inside its
-- | bounding box.
operatorPreamble :: Array Operator -> String
operatorPreamble operators = joinWith "\n" (map line operators)
  where
  line { name, body } = "\\providecommand{" <> name <> "}{" <> body <> "}%"

-- | The document node-tikzjax compiles: the `\set` shim, the operator
-- | preamble, the tikz-3dplot setup on its own line when there is one
-- | (it must precede `\begin{tikzpicture}`), and the picture.
texDocument :: TexParts -> String
texDocument { preamble, setup, code } =
  "\\begin{document}\n\\providecommand{\\set}[1]{\\{#1\\}}%\n"
    <> preamble
    <> "\n"
    <> setupLine
    <> code
    <> "\n\\end{document}"
  where
  setupLine = if setup == "" then "" else setup <> "\n"

-- | The TeX packages a figure needs, in the order the renderer's option
-- | object listed them: `amsmath` and `amssymb` for math (a `$`) or a
-- | commutative diagram, `tikz-cd` for a `tikzcd` environment, and
-- | `tikz-3dplot` when there is 3-D setup or the code mentions `tdplot`.
texPackages :: { setup :: String, code :: String } -> Array String
texPackages { setup, code } =
  (if hasMath || needsTikzCd then [ "amsmath", "amssymb" ] else [])
    <> (if needsTikzCd then [ "tikz-cd" ] else [])
    <> (if uses3d then [ "tikz-3dplot" ] else [])
  where
  needsTikzCd = contains (Pattern "\\begin{tikzcd}") code
  hasMath = contains (Pattern "$") code
  uses3d = setup /= "" || contains (Pattern "tdplot") code

-- | The TikZ libraries every figure loads.
tikzLibraries :: String
tikzLibraries = "automata,positioning,arrows.meta,calc,shapes.geometric"
