-- | Markdown and inline-math rendering. Non-math cases assert exact HTML
-- | (that output is this codebase's own logic, recorded from the original
-- | TypeScript); math-bearing cases either smoke-check for KaTeX markup or
-- | compare against `renderTex` itself, since the exact HTML belongs to the
-- | katex package and changes with it.
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
  , { input: "one\ntwo", out: "<p>one<br>two</p>\n" }
  ]

inlineCases :: Array Case
inlineCases =
  [ { input: "", out: "" }
  , { input: "pure text", out: "pure text" }
  , { input: "a < b & c > d", out: "a &lt; b &amp; c &gt; d" }
  , { input: "snake_case_word stays put", out: "snake_case_word stays put" }
  , { input: "*star em* and **strong**", out: "<em>star em</em> and <strong>strong</strong>" }
  , { input: "_under_", out: "<em>under</em>" }
  , { input: "a*b", out: "a*b" }
  , { input: "costs 5 $", out: "costs 5 $" }
  , { input: "**<b>**", out: "<strong>&lt;b&gt;</strong>" }
  , { input: "Tom &amp; Jerry", out: "Tom &amp;amp; Jerry" }
  ]

mathCases :: Array { label :: String, input :: String, out :: String }
mathCases =
  [ { label: "a lone math segment", input: "$x^2$", out: renderTex "x^2" false }
  , { label: "math between text"
    , input: "area $x^2$ grows"
    , out: "area " <> renderTex "x^2" false <> " grows"
    }
  , { label: "two math segments"
    , input: "$a$ and $b$"
    , out: renderTex "a" false <> " and " <> renderTex "b" false
    }
  , { label: "stars inside math are not emphasis"
    , input: "$a*b*c$"
    , out: renderTex "a*b*c" false
    }
  , { label: "angle brackets inside math are not escaped"
    , input: "$a<b$"
    , out: renderTex "a<b" false
    }
  , { label: "emphasis around math"
    , input: "**bold** $x$ _it_"
    , out: "<strong>bold</strong> " <> renderTex "x" false <> " <em>it</em>"
    }
  , { label: "course macros inside math", input: "$\\R$", out: renderTex "\\R" false }
  ]

suite :: Tally -> Effect Unit
suite t = do
  for_ markdownCases \c ->
    expect t ("markdown " <> show c.input) c.out (renderMarkdownMath c.input)
  for_ inlineCases \c ->
    expect t ("inline " <> show c.input) c.out (renderInlineMath c.input)
  for_ mathCases \c ->
    expect t ("inline " <> c.label) c.out (renderInlineMath c.input)
  expectContains t "inline math renders katex" "katex" (renderInlineMath "$x^2$")
  expectContains t "markdown math renders katex" "katex" (renderMarkdownMath "value $x^2$ rises")
  expectContains t "markdown block math sits in a math-block" "<div class=\"math-block\">"
    (renderMarkdownMath "$$x^2$$")
  expectContains t "markdown block math renders in display mode" "katex-display"
    (renderMarkdownMath "$$x^2$$")
  expectContains t "renderTex inline" "katex" (renderTex "x^2" false)
  expectContains t "renderTex display" "katex-display" (renderTex "\\int_0^1 x\\,dx" true)
