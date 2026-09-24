-- | Checks for the TeX renderer's contract. The exact HTML belongs to the
-- | katex package, so these only look for the markers of each promise:
-- | output is HTML plus MathML, display mode centres a block and inline
-- | mode does not, the course macro map is always applied, and bad TeX
-- | never throws — it stays visible on the page instead.
module Test.Utils.Katex (suite) where

import Prelude

import App.Utils.Katex (renderTex)
import Data.String (Pattern(..), contains)
import Effect (Effect)
import Test.Harness (Tally, expect, expectContains)

suite :: Tally -> Effect Unit
suite t = do
  let inline = renderTex "x^2" false
  expectContains t "inline TeX renders as KaTeX HTML" "katex-html" inline
  expectContains t "inline TeX carries MathML for screen readers" "<math" inline
  expect t "inline TeX is not a centred display block" false
    (contains (Pattern "katex-display") inline)
  expectContains t "display TeX renders as a centred block" "katex-display"
    (renderTex "\\sum_{i=1}^n i" true)

  let reals = renderTex "\\R" false
  expectContains t "the course macro \\R renders blackboard-bold R" "double-struck" reals
  expect t "a course macro is not flagged as an unknown command" false
    (contains (Pattern "#cc0000") reals)
  expectContains t "an unknown command renders in the error colour rather than throwing"
    "#cc0000"
    (renderTex "\\notamacro" false)

  let broken = renderTex "\\frac{" false
  expectContains t "malformed TeX is marked as an error" "katex-error" broken
  expectContains t "malformed TeX keeps its source visible" "\\frac{" broken
