-- | Checks for the timeline preview's placement: it hangs above the phrase
-- | whenever it clears the viewport's top by the edge margin — the exact
-- | boundary included — and drops below otherwise; its left edge keeps the
-- | margin from both sides, the right-hand clamp winning on a viewport too
-- | narrow for the card; and the edge it hangs from is measured from the
-- | viewport's bottom above, from its top below. Expected values were
-- | computed from the original TypeScript formula. Then what the phrase
-- | reads from its props: the month its `period` names however it is
-- | written, the landing on the timeline — the year, and the period's
-- | three-letter month only when it names one — and the description it
-- | adds for a screen reader.
module Test.Components.TimelineTarget (suite) where

import Prelude

import App.Components.TimelineTarget
  ( descriptionFor
  , landingFor
  , peekEdge
  , peekGap
  , peekPlacement
  , periodMonth
  )
import Data.Maybe (Maybe(..))
import Data.Nullable (notNull, null, toMaybe)
import Data.Number (isNaN, nan)
import Effect (Effect)
import Test.Harness (Tally, expect)

desk :: { width :: Number, height :: Number }
desk = { width: 1280.0, height: 800.0 }

phrase :: Number -> Number -> { left :: Number, top :: Number, bottom :: Number }
phrase left top = { left, top, bottom: top + 20.0 }

suite :: Tally -> Effect Unit
suite t = do
  expect t "the gap and the edge margin" { gap: 8.0, edge: 12.0 }
    { gap: peekGap, edge: peekEdge }

  expect t "a card with room above hangs above, its bottom 8px over the phrase"
    { left: 100.0, edge: 308.0, above: true }
    (peekPlacement (phrase 100.0 500.0) desk 300.0 240.0)
  expect t "a card that would cross the top edge margin drops below"
    { left: 100.0, edge: 228.0, above: false }
    (peekPlacement (phrase 100.0 200.0) desk 300.0 240.0)
  expect t "a card that meets the top edge margin exactly stays above"
    { left: 100.0, edge: 548.0, above: true }
    (peekPlacement (phrase 100.0 260.0) desk 300.0 240.0)
  expect t "half a pixel short of the margin drops below"
    { left: 100.0, edge: 287.5, above: false }
    (peekPlacement (phrase 100.0 259.5) desk 300.0 240.0)
  expect t "a taller card needs more room to sit above"
    { left: 100.0, edge: 528.0, above: false }
    (peekPlacement (phrase 100.0 500.0) desk 300.0 481.0)
  expect t "a phrase at the very top puts the card below"
    { left: 100.0, edge: 28.0, above: false }
    (peekPlacement (phrase 100.0 0.0) desk 300.0 240.0)

  expect t "a phrase near the left side clamps the card to the margin"
    { left: 12.0, edge: 308.0, above: true }
    (peekPlacement (phrase 4.0 500.0) desk 300.0 240.0)
  expect t "a phrase scrolled off the left side clamps the card to the margin"
    { left: 12.0, edge: 308.0, above: true }
    (peekPlacement (phrase (-50.0) 500.0) desk 300.0 240.0)
  expect t "a phrase at the margin keeps its left"
    { left: 12.0, edge: 308.0, above: true }
    (peekPlacement (phrase 12.0 500.0) desk 300.0 240.0)
  expect t "a phrase near the right side clamps the card to width - 300 - 12"
    { left: 968.0, edge: 308.0, above: true }
    (peekPlacement (phrase 1100.0 500.0) desk 300.0 240.0)
  expect t "a phrase exactly at the right clamp keeps its left"
    { left: 968.0, edge: 308.0, above: true }
    (peekPlacement (phrase 968.0 500.0) desk 300.0 240.0)
  expect t "a viewport too narrow for the card lets the right clamp win"
    { left: 8.0, edge: 288.0, above: true }
    (peekPlacement (phrase 40.0 300.0) { width: 320.0, height: 580.0 } 300.0 240.0)
  expect t "a phone viewport clamps the card within both margins"
    { left: 63.0, edge: 108.0, above: false }
    (peekPlacement (phrase 200.0 80.0) { width: 375.0, height: 812.0 } 300.0 240.0)

  expect t "fractional rects place above as the original arithmetic does"
    { left: 12.0, edge: 319.19999999999993, above: true }
    ( peekPlacement { left: 0.5, top: 500.1, bottom: 520.1 }
        { width: 1280.0, height: 811.3 }
        300.0
        240.0
    )
  expect t "fractional rects place below as the original arithmetic does"
    { left: 33.25, edge: 228.35, above: false }
    (peekPlacement { left: 33.25, top: 200.1, bottom: 220.35 } desk 300.0 240.0)

  let unmeasured = peekPlacement (phrase nan 500.0) desk 300.0 240.0
  expect t "an unmeasured left stays NaN through both clamps, as Math.min/max do"
    { leftIsNaN: true, edge: 308.0, above: true }
    { leftIsNaN: isNaN unmeasured.left, edge: unmeasured.edge, above: unmeasured.above }
  expect t "a card wider than the viewport pins to a negative left"
    { left: -32.0, edge: 308.0, above: true }
    (peekPlacement (phrase 100.0 500.0) { width: 280.0, height: 800.0 } 300.0 240.0)

  expect t "no period prop names no month" Nothing (toMaybe (periodMonth null))
  expect t "a period's month is read however it is written" [ Just 6, Just 6, Just 6, Just 6 ]
    (map (toMaybe <<< periodMonth <<< notNull) [ "Jun", "June", "jun", "6" ])
  expect t "a period written with its year still names its month" (Just 2)
    (toMaybe (periodMonth (notNull "Feb 2026")))
  expect t "a period with no month in it names none" Nothing
    (toMaybe (periodMonth (notNull "someday")))

  expect t "a phrase about the whole year lands on the year alone"
    { year: 2024, period: null }
    (landingFor 2024 null)
  expect t "a phrase about one period lands on its month's label"
    { year: 2024, period: notNull "jun" }
    (landingFor 2024 (notNull 6))
  expect t "the first and last months land on their labels"
    [ notNull "jan", notNull "dec" ]
    (map (_.period <<< landingFor 2021 <<< notNull) [ 1, 12 ])

  expect t "the phrase describes itself by its year on the timeline" "2024 on the timeline"
    (descriptionFor 2024)
