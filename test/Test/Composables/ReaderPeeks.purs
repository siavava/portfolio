-- | Checks for the reader peeks' pure placement: which links count as
-- | links into the notes site and the index key they resolve to, the
-- | figure card centred above its figure (clear of the viewport's top,
-- | within 260–560px wide), and the reference card centred on the
-- | pointer inside the viewport, above the link when it fits and below
-- | when it doesn't, at whole-pixel offsets 10px off the link.
module Test.Composables.ReaderPeeks (suite) where

import Prelude

import App.Composables.ReaderPeeks
  ( figCardPlacement
  , peekNotesPath
  , refCardBottom
  , refCardFitsAbove
  , refCardLeft
  , refCardTop
  )
import Data.Maybe (Maybe(..))
import Data.Nullable (toMaybe)
import Effect (Effect)
import Test.Harness (Tally, expect)

notesPath :: String -> Maybe String
notesPath = toMaybe <<< peekNotesPath

suite :: Tally -> Effect Unit
suite t = do
  expect t "notes path: a lesson link keys by its pathname"
    (Just "/algorithms/sorting")
    (notesPath "https://notes.amittai.studio/algorithms/sorting")
  expect t "notes path: a trailing slash is dropped"
    (Just "/algorithms/sorting")
    (notesPath "https://notes.amittai.studio/algorithms/sorting/")
  expect t "notes path: every trailing slash is dropped"
    (Just "/deep-learning")
    (notesPath "https://notes.amittai.studio/deep-learning///")
  expect t "notes path: query and fragment are not part of the key"
    (Just "/algorithms/sorting")
    (notesPath "https://notes.amittai.studio/algorithms/sorting/?tab=2#proof")
  expect t "notes path: the site root keys as the empty path"
    (Just "")
    (notesPath "https://notes.amittai.studio/")
  expect t "notes path: another site is not the notes site" Nothing
    (notesPath "https://amittai.studio/algorithms")
  expect t "notes path: a lookalike host is not the notes site" Nothing
    (notesPath "https://notes.amittai.studio.example.com/algorithms")
  expect t "notes path: plain http is not the notes site" Nothing
    (notesPath "http://notes.amittai.studio/algorithms")
  expect t "notes path: a relative href is not the notes site" Nothing
    (notesPath "/algorithms/sorting")
  expect t "notes path: an empty href is not the notes site" Nothing (notesPath "")

  expect t "fig card: centred over the figure, 10px above it, as wide as it"
    { left: "300px", top: "290px", width: "400px" }
    (figCardPlacement { left: 100.0, top: 300.0, width: 400.0 })
  expect t "fig card: a narrow figure gets a 260px card, still centred on it"
    { left: "150px", top: "290px", width: "260px" }
    (figCardPlacement { left: 100.0, top: 300.0, width: 100.0 })
  expect t "fig card: a wide figure gets a 560px card, still centred on it"
    { left: "500px", top: "290px", width: "560px" }
    (figCardPlacement { left: 100.0, top: 300.0, width: 800.0 })
  expect t "fig card: a figure near the top keeps the card 8px clear of it"
    { left: "300px", top: "8px", width: "400px" }
    (figCardPlacement { left: 100.0, top: 12.0, width: 400.0 })
  expect t "fig card: a figure scrolled above the viewport still pins the card at 8px"
    { left: "300px", top: "8px", width: "400px" }
    (figCardPlacement { left: 100.0, top: -250.0, width: 400.0 })
  expect t "fig card: exactly 18px down, the card sits right at the 8px line"
    { left: "300px", top: "8px", width: "400px" }
    (figCardPlacement { left: 100.0, top: 18.0, width: 400.0 })
  expect t "fig card: fractional offsets print as plain decimals"
    { left: "160.5px", top: "90.75px", width: "300.5px" }
    (figCardPlacement { left: 10.25, top: 100.75, width: 300.5 })
  expect t "fig card: a negative-zero centre prints as 0px"
    { left: "0px", top: "40px", width: "260px" }
    (figCardPlacement { left: negate 0.0, top: 50.0, width: negate 0.0 })

  expect t "ref card: centred on the pointer" 335.0 (refCardLeft 500.0 1440.0)
  expect t "ref card: held 12px in from the left edge" 12.0 (refCardLeft 50.0 1440.0)
  expect t "ref card: exactly at the left margin" 12.0 (refCardLeft 177.0 1440.0)
  expect t "ref card: held 12px in from the right edge" 1098.0 (refCardLeft 1400.0 1440.0)
  expect t "ref card: exactly at the right margin" 1098.0 (refCardLeft 1263.0 1440.0)

  expect t "ref card: an unrendered card goes above" true (refCardFitsAbove 0.0 0.0)
  expect t "ref card: a card with room above the link goes above" true
    (refCardFitsAbove 100.0 300.0)
  expect t "ref card: a card without room above goes below" false (refCardFitsAbove 100.0 100.0)
  expect t "ref card: exactly 8px to spare still fits above" true (refCardFitsAbove 100.0 118.0)
  expect t "ref card: under 8px to spare goes below" false (refCardFitsAbove 100.0 117.5)

  expect t "ref card above: bottom sits 10px above the link's top" "510px"
    (refCardBottom 900.0 400.0)
  expect t "ref card above: the offset rounds to whole pixels" "510px"
    (refCardBottom 900.0 400.4)
  expect t "ref card above: the offset rounds up from the half" "511px"
    (refCardBottom 900.0 399.5)
  expect t "ref card below: top sits 10px below the link's bottom" "230px" (refCardTop 220.0)
  expect t "ref card below: the offset rounds to whole pixels" "231px" (refCardTop 220.6)
