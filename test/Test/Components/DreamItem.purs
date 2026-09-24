-- | Checks for the dream checklist's label segmentation: plain text and
-- | `[text](url)` links come out in order, with no empty text between two
-- | links that touch; anything the link pattern refuses — an empty link
-- | text, a target with a space — stays plain text; and the slicing is by
-- | code unit, the way `matchAll` reports its indices.
module Test.Components.DreamItem (suite) where

import Prelude

import App.Components.DreamItem (LabelPart, partsOf)
import Data.Nullable (notNull, null)
import Effect (Effect)
import Test.Harness (Tally, expect)

plain :: String -> LabelPart
plain text = { text, href: null }

link :: String -> String -> LabelPart
link text href = { text, href: notNull href }

suite :: Tally -> Effect Unit
suite t = do
  expect t "a label with no links is one plain segment" [ plain "Run a marathon" ]
    (partsOf "Run a marathon")
  expect t "an empty label has no segments" [] (partsOf "")
  expect t "a link mid-label splits it into text, link, text"
    [ plain "Visit ", link "Kyoto" "https://example.com/kyoto", plain " in spring" ]
    (partsOf "Visit [Kyoto](https://example.com/kyoto) in spring")
  expect t "a label that is only a link is only the link" [ link "Kyoto" "https://kyoto.jp" ]
    (partsOf "[Kyoto](https://kyoto.jp)")
  expect t "a link that opens the label has no text before it"
    [ link "Learn" "/learn", plain " the cello" ]
    (partsOf "[Learn](/learn) the cello")
  expect t "two links that touch have no empty text between them"
    [ link "a" "x", link "b" "y" ]
    (partsOf "[a](x)[b](y)")
  expect t "two links apart keep the text between them"
    [ plain "See ", link "a" "x", plain " and ", link "b" "y" ]
    (partsOf "See [a](x) and [b](y)")
  expect t "a target with a space is not a link" [ plain "[a](has space)" ]
    (partsOf "[a](has space)")
  expect t "an empty link text is not a link" [ plain "[](x)" ] (partsOf "[](x)")
  expect t "an astral character before a link splits cleanly"
    [ plain "🌸 ", link "bloom" "b", plain " done" ]
    (partsOf "🌸 [bloom](b) done")
