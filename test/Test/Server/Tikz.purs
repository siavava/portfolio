-- | Locked-down cases for the TikZ figure route's pure core: hash
-- | sanitization, cache file naming, and the response rewrite that strips
-- | the `<figure>` wrapper and makes the SVG root responsive.
-- |
-- | Then the two passes on their own: the wrapper comes off only at the
-- | body's edges, and only the root `<svg>` is rewritten — attribute
-- | order does not matter, nested SVGs keep their sizes, and a root sized
-- | in anything but plain numbers is left alone.
module Test.Server.Tikz (suite) where

import Prelude

import App.Server.Tikz
  ( cacheFileName
  , responsiveSvgRoot
  , sanitizeHash
  , stripFigureWrapper
  , tikzResponseHtml
  )
import Data.String (Pattern(..), contains)
import Effect (Effect)
import Test.Harness (Tally, expect, expectContains)

bare :: String
bare = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"302.878\" height=\"149.6\"><g></g></svg>"

styled :: String
styled =
  "\n<figure class=\"tikz-figure\" data-hash=\"deadbeef\"><svg width=\"100\" height=\"50\" style=\"color:red\"><path d=\"M0 0\"></path></svg></figure>\n"

semi :: String
semi =
  "<svg width=\"12.5\" height=\"7\" style=\"overflow:visible; \"><circle r=\"1\"></circle></svg>"

unsized :: String
unsized = "<svg viewBox=\"0 0 10 10\"><rect></rect></svg>"

suite :: Tally -> Effect Unit
suite t = do
  expect t "sanitizeHash keeps lowercase hex" "abc123def" (sanitizeHash "abc123def")
  expect t "sanitizeHash strips uppercase hex" "" (sanitizeHash "ABC")
  expect t "sanitizeHash reduces path traversal to its hex residue" "ecad"
    (sanitizeHash "../../../etc/passwd")
  expect t "sanitizeHash of empty string" "" (sanitizeHash "")
  expect t "sanitizeHash strips unicode, uppercase, punctuation" "def123"
    (sanitizeHash "🎉θ-ABC-def-123")
  expect t "cacheFileName appends .html" "deadbeef.html" (cacheFileName "deadbeef")
  let bareOut = tikzResponseHtml bare
  expect t "style-less root gains responsive style"
    "<svg style=\"width:100%;max-width:302.878px;height:auto\" xmlns=\"http://www.w3.org/2000/svg\"><g></g></svg>"
    bareOut
  expectContains t "responsive declaration present" "max-width:302.878px;height:auto" bareOut
  expect t "fixed width attribute removed" false (contains (Pattern "width=\"") bareOut)
  expect t "fixed height attribute removed" false (contains (Pattern "height=\"") bareOut)
  let styledOut = tikzResponseHtml styled
  expect t "wrapper stripped, decl appended after normalized semicolon"
    "<svg style=\"color:red;width:100%;max-width:100px;height:auto\"><path d=\"M0 0\"></path></svg>"
    styledOut
  expect t "figure wrapper absent" false (contains (Pattern "<figure") styledOut)
  expect t "existing trailing semicolon not doubled"
    "<svg style=\"overflow:visible;width:100%;max-width:12.5px;height:auto\"><circle r=\"1\"></circle></svg>"
    (tikzResponseHtml semi)
  expect t "width-less root left untouched" unsized (tikzResponseHtml unsized)

  expect t "sanitizeHash keeps every lowercase hex digit" "0123456789abcdef"
    (sanitizeHash "0123456789abcdefg")
  expect t "an empty hash names a bare .html file" ".html" (cacheFileName (sanitizeHash "XYZ"))

  expect t "the wrapper and its surrounding whitespace come off"
    "<svg></svg><figcaption class=\"tikz-cap\">c</figcaption>"
    ( stripFigureWrapper
        "\n\n<figure class=\"tikz-figure\"><svg></svg><figcaption class=\"tikz-cap\">c</figcaption></figure>\n\n"
    )
  expect t "a figure tag inside the body is kept" "<p>x</p><figure></figure><p>y</p>"
    (stripFigureWrapper "<p>x</p><figure></figure><p>y</p>")
  expect t "a body without a wrapper is unchanged" "<svg></svg>" (stripFigureWrapper "<svg></svg>")

  expect t "height before width is rewritten the same"
    "<svg style=\"width:100%;max-width:40px;height:auto\"></svg>"
    (responsiveSvgRoot "<svg height=\"20\" width=\"40\"></svg>")
  expect t "only the root svg is rewritten; a nested one keeps its size"
    "<svg style=\"width:100%;max-width:40px;height:auto\"><svg width=\"4\" height=\"2\"></svg></svg>"
    (responsiveSvgRoot "<svg width=\"40\" height=\"20\"><svg width=\"4\" height=\"2\"></svg></svg>")
  expect t "a percentage width is not a fixed size" "<svg width=\"100%\" height=\"20\"></svg>"
    (responsiveSvgRoot "<svg width=\"100%\" height=\"20\"></svg>")
  expect t "a root with a width but no height still goes responsive"
    "<svg style=\"width:100%;max-width:7.5px;height:auto\" viewBox=\"0 0 1 1\"></svg>"
    (responsiveSvgRoot "<svg width=\"7.5\" viewBox=\"0 0 1 1\"></svg>")
  expect t "no svg at all is left untouched" "<p>fallback</p>"
    (responsiveSvgRoot "<p>fallback</p>")
