-- | Markdown and inline-math rendering. Non-math cases assert exact HTML
-- | (that output is this codebase's own logic, recorded from the original
-- | TypeScript); math-bearing cases only smoke-check for KaTeX markup,
-- | since the exact HTML belongs to the katex package and changes with it.
module Test.Utils.MarkdownMath (suite) where

import Prelude

import App.Utils.Katex (renderTex)
import App.Utils.MarkdownMath (renderInlineMath, renderMarkdownMath)
import Data.Foldable (for_)
import Effect (Effect)
import Test.Harness (Tally, expect, expectContains)

type Case = { input :: String, out :: String }

markdownCases :: Array Case
markdownCases =
  [ { input: "", out: "" }
  , { input: "- list\n- items", out: "<ul>\n<li>list</li>\n<li>items</li>\n</ul>\n" }
  , { input: "**emphasis** _under_ and *star*"
    , out: "<p><strong>emphasis</strong> <em>under</em> and <em>star</em></p>\n"
    }
  ]

inlineCases :: Array Case
inlineCases =
  [ { input: "", out: "" }
  , { input: "pure text", out: "pure text" }
  , { input: "a < b & c > d", out: "a &lt; b &amp; c &gt; d" }
  , { input: "snake_case_word stays put", out: "snake_case_word stays put" }
  , { input: "*star em* and **strong**", out: "<em>star em</em> and <strong>strong</strong>" }
  ]

suite :: Tally -> Effect Unit
suite t = do
  for_ markdownCases \c ->
    expect t ("markdown " <> show c.input) c.out (renderMarkdownMath c.input)
  for_ inlineCases \c ->
    expect t ("inline " <> show c.input) c.out (renderInlineMath c.input)
  expectContains t "inline math renders katex" "katex" (renderInlineMath "$x^2$")
  expectContains t "markdown math renders katex" "katex" (renderMarkdownMath "value $x^2$ rises")
  expectContains t "renderTex inline" "katex" (renderTex "x^2" false)
  expectContains t "renderTex display" "katex-display" (renderTex "\\int_0^1 x\\,dx" true)
