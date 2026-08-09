-- | Locked-down cases for the TikZ figure route's pure core: hash
-- | sanitization, cache file naming, and the response rewrite that strips
-- | the `<figure>` wrapper and makes the SVG root responsive.
module Test.Server.Tikz (suite) where

import Prelude

import App.Server.Tikz (cacheFileName, sanitizeHash, tikzResponseHtml)
import Data.String (Pattern(..), contains)
import Effect (Effect)
import Test.Harness (Tally, expect, expectContains)

-- | Root carrying fixed size attributes but no `style` attribute.
bare :: String
bare = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"302.878\" height=\"149.6\"><g></g></svg>"

-- | Figure-wrapped root with an existing `style` (no trailing semicolon).
styled :: String
styled =
  "\n<figure class=\"tikz-figure\" data-hash=\"deadbeef\"><svg width=\"100\" height=\"50\" style=\"color:red\"><path d=\"M0 0\"></path></svg></figure>\n"

-- | Existing `style` already ending in a semicolon plus stray whitespace.
semi :: String
semi =
  "<svg width=\"12.5\" height=\"7\" style=\"overflow:visible; \"><circle r=\"1\"></circle></svg>"

-- | No fixed `width` attribute on the root: the rewrite must not touch it.
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
