-- | Checks for the algorithm-block parser: directives and the fence meta
-- | that overrides them, the comment split, keyword and control-word
-- | rendering, the blank lines trimmed from either end, and the bracket
-- | feet with the push that stacks them. Expected values were recorded from
-- | the original TypeScript; math only smoke-checks for KaTeX markup, since
-- | its exact HTML belongs to the katex package. The row pass's raw fields,
-- | where directives may sit, and the push a line's feet ask for follow the
-- | module's documentation.
module Test.Components.AlgorithmBlock (suite) where

import Prelude

import App.Components.AlgorithmBlock
  ( Line
  , digitsFor
  , footAt
  , footDepth
  , footPushFor
  , headingFor
  , parse
  , readRows
  , renderCode
  , renderComment
  , splitComment
  )
import Data.Array ((!!))
import Data.Maybe (Maybe(..))
import Data.Nullable (toMaybe)
import Effect (Effect)
import Test.Harness (Tally, expect, expectContains)

linesOf :: String -> Array Line
linesOf code = (parse code "").lines

htmlOf :: String -> Array String
htmlOf = map _.html <<< linesOf

line :: Int -> String -> Line
line level html = { level, html, comment: "", feet: [], footPush: 0.0 }

kw :: String -> String
kw word = "<b class=\"kw\">" <> word <> "</b>"

suite :: Tally -> Effect Unit
suite t = do
  let directives = parse "caption:  Binary search \nnumber: 3\n\n\nfoo\n" ""
  expect t "a caption directive is read and trimmed" "Binary search" directives.caption
  expect t "a number directive is read" "3" directives.number
  expect t "directives and the blank lines around them are not rows" [ line 0 "foo" ]
    directives.lines
  let overridden = parse "Caption: Mixed Case\nNUMBER: 12\nfoo" "caption=\"Other\" number=7"
  expect t "the meta caption wins over the body's" "Other" overridden.caption
  expect t "the meta number wins over the body's" "7" overridden.number
  let partial = parse "caption: Kept\nnumber: 3\nfoo" "number=x caption=\"\""
  expect t "an empty meta caption still overrides" "" partial.caption
  expect t "a meta number that is not digits is ignored" "3" partial.number
  expect t "an empty block has no lines" [] (linesOf "")

  expect t "a spaced // opens a comment" { content: "x ← 1", comment: "init" }
    (splitComment "x ← 1 // init")
  expect t "a ▷ before a // opens the comment there"
    { content: "y", comment: "note // other" }
    (splitComment "y ▷ note // other")
  expect t "an unspaced // is code" { content: "a//b", comment: "" } (splitComment "a//b")
  expect t "a line can be all comment" { content: "", comment: "only" } (splitComment "▷ only")
  expect t "a comment is escaped but keywords stay plain" "do &lt; it"
    (renderComment "do < it")
  expect t "a line keeps its comment rendered" (Just "do &lt; it")
    (map _.comment (linesOf "x ← 1 // do < it" !! 0))

  expect t "keywords are bolded, their case kept"
    [ kw "Return" <> " X"
    , kw "else if" <> " y"
    , kw "for each" <> " v"
    , kw "for" <> " i " <> kw "to" <> " n"
    , "format done"
    , "a &lt; b " <> kw "and" <> " c"
    , "<strong>key</strong> step"
    , "<strong>" <> kw "return" <> "</strong> x"
    , "<i class=\"ctrl\">end</i>"
    , "BEGIN now"
    ]
    ( htmlOf
        ( "Return X\nelse if y\nfor each v\nfor i to n\nformat done\na < b and c\n"
            <> "**key** step\n**return** x\nEnd\nBEGIN now"
        )
    )

  expect t "blank lines inside are kept, those at either end dropped"
    [ line 0 "a", line 0 "", line 0 "b" ]
    (linesOf "\n\na\n\nb\n\n  \n")
  expect t "carriage returns are dropped" [ "a", "b" ] (htmlOf "a\r\nb")
  expect t "two spaces make a level" [ 0, 1, 2, 1 ]
    (map _.level (readRows "a\n  b\n    c\n   d").rows)

  expect t "each guide a line closes ends in a foot"
    [ line 0 (kw "while" <> " x " <> kw "do")
    , line 1 (kw "if" <> " y " <> kw "then")
    , { level: 2, html: "z", comment: "", feet: [ 1 ], footPush: 0.1 }
    , { level: 1, html: "w", comment: "", feet: [ 0 ], footPush: 0.1 }
    , line 0 "<i class=\"ctrl\">end</i>"
    ]
    (linesOf "while x do\n  if y then\n    z\n  w\nend")

  let
    closing = linesOf "a\n  b\n    c\nd"
    deep = closing !! 2
  expect t "a line closing two blocks stacks both feet" (Just [ 0, 1 ]) (map _.feet deep)
  expect t "stacked feet push the next line further" (Just (0.1 + 0.46)) (map _.footPush deep)
  expect t "the last line closes every open block" (Just [ 0, 1 ])
    (map _.feet ((linesOf "a\n  b\n    c") !! 2))
  expect t "the outer foot sits one below the inner" (Just (Just 1))
    (map (\l -> toMaybe (footDepth l 1)) deep)
  expect t "the innermost foot sits at depth 0" (Just (Just 0))
    (map (\l -> toMaybe (footDepth l 2)) deep)
  expect t "a guide that runs on has no foot" (Just Nothing)
    (map (\l -> toMaybe (footDepth l 1)) (closing !! 1))
  expect t "a guide closing on its line is a foot" (Just true) (map (\l -> footAt l 1) deep)
  expect t "the innermost closing guide is a foot" (Just true) (map (\l -> footAt l 2) deep)
  expect t "a guide that runs on is not a foot" (Just false)
    (map (\l -> footAt l 1) (closing !! 1))
  expect t "a depth past the line's guides is not a foot" (Just false)
    (map (\l -> footAt l 3) deep)

  expect t "an unnumbered algorithm's heading" "Algorithm:" (headingFor "")
  expect t "a numbered algorithm's heading" "Algorithm 3:" (headingFor "3")

  expect t "a single digit line count" 1 (digitsFor 9)
  expect t "an empty block still reserves a digit" 1 (digitsFor 0)
  expect t "a two-digit line count" 2 (digitsFor 10)
  expect t "a three-digit line count" 3 (digitsFor 120)

  expectContains t "math renders through katex" "katex" (renderCode "sort $A$ in place")
  expectContains t "text beside math is still rendered" (kw "for") (renderCode "for $i$")

  expect t "a row keeps its code and comment raw"
    [ { level: 1, content: "x ← a < b", comment: "init & go" } ]
    (readRows "  x ← a < b // init & go").rows
  expect t "the last caption and number in the body win"
    { caption: "Second", number: "2" }
    ( let
        read = readRows "caption: First\nnumber: 1\ncaption: Second\nnumber: 2\nfoo"
      in
        { caption: read.caption, number: read.number }
    )
  expect t "a directive between rows is still taken out" [ "foo", "bar" ]
    (map _.content (readRows "foo\ncaption: Mid\nbar").rows)
  expect t "a trailing comment-only line is not blank, so it stays" [ "a", "" ]
    (map _.content (readRows "a\n▷ closing note").rows)

  expect t "top-level lines have no feet" [ [], [] ] (map _.feet (linesOf "a\nb"))
  expect t "a guide that the next line runs deeper than stays open" (Just [])
    (map _.feet (linesOf "  a\n    b" !! 0))
  expect t "a line two levels in closes both guides on the last line" (Just [ 0, 1 ])
    (map _.feet (linesOf "a\n    b\nc" !! 1))

  expect t "a line with no feet pushes nothing" 0.0 (footPushFor [])
  expect t "a single foot pushes a little" 0.1 (footPushFor [ 0 ])
  expect t "each foot stacked under the shallowest pushes further" (0.1 + 2.0 * 0.46)
    (footPushFor [ 1, 2, 3 ])
  expect t "the push spans the shallowest to the deepest foot" (0.1 + 2.0 * 0.46)
    (footPushFor [ 3, 1 ])
