-- | Checks for the pure policy behind the timeline: the intro curve holds
-- | the early years rather than racing them, a sweep is planned from the
-- | ground it actually covers, arrow keys step a year at a time, the wheel's
-- | glide is frame-rate independent, periods read and speak the way they
-- | are written, periods are drawn longest first on their one line, and the
-- | light switch says which way it flips. Then the rest of the rail's
-- | arithmetic: the S-curve and its inverse, where each column starts, the
-- | scroll floor and limit that centre the first and last years, the column
-- | a requested year lands on, each column's fade under the label gutter and
-- | off the right edge (gentler on touch), the frame-rate independent fling
-- | decay; months and period ends read any of the usual ways; the route's
-- | year and period, the spotlight a tap toggles, the column the skip link
-- | focuses, the pose the panel grows from, and the kernel's sweep held back
-- | under reduced motion.
module Test.Components.Timeline (suite) where

import Prelude

import App.Components.Timeline
  ( HoverStep(..)
  , PeriodInfo
  , columnTakesWheel
  , columnsFor
  , decayVelocity
  , followTo
  , hoverStep
  , introExponent
  , introProgress
  , kernelFor
  , landedColumn
  , landing
  , landingYear
  , markerOpacity
  , monthLabel
  , monthNumber
  , offsets
  , periodInfo
  , periodPoint
  , planSweep
  , poseFrom
  , railSpans
  , requestedSpot
  , runsOf
  , sameSpot
  , scrollFloor
  , scrollLimit
  , smoothstep
  , smoothstepInv
  , spotKey
  , startingIn
  , stepTarget
  , targetIndex
  , themeAriaFor
  , togglePick
  )
import App.Utils.ThemeIcon (themeIconFor)
import Data.Array (all, length, zipWith, (!!))
import Data.Array as Array
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Nullable (notNull, null, toMaybe)
import Data.Number (abs)
import Effect (Effect)
import Test.Harness (Tally, expect)

widths :: Array Number
widths = [ 290.0, 80.0, 290.0, 290.0, 290.0, 290.0, 290.0, 290.0, 360.0 ]

near :: Number -> Number -> Boolean
near a b = abs (a - b) < 0.01

info :: Int -> String -> Maybe String -> Maybe PeriodInfo
info year from to = toMaybe (periodInfo year from (maybe' to))
  where
  maybe' = case _ of
    Just value -> notNull value
    Nothing -> null

label :: Maybe PeriodInfo -> Maybe String
label = map _.label

spoken :: Maybe PeriodInfo -> Maybe String
spoken = map _.spoken

suite :: Tally -> Effect Unit
suite t = do
  let exponent = introExponent widths
  expect t "the intro curve holds the head (exponent at least 1)" true (exponent >= 1.0)
  expect t "the intro curve stays within its ceiling" true (exponent <= 2.6)
  expect t "a degenerate rail falls back to the ceiling" 2.6 (introExponent [])
  expect t "a rail that is all head is held at 1" 1.0 (introExponent [ 100.0 ])
  expect t "the sweep never runs ahead of a plain smoothstep" true
    ( all (\ms -> introProgress widths 1900.0 ms <= smoothstep (ms / 1900.0) + 1.0e-9)
        [ 100.0, 300.0, 665.0, 1000.0, 1500.0, 1899.0 ]
    )
  expect t "the sweep ends at 1" 1.0 (introProgress widths 1900.0 1900.0)
  expect t "a zero-length sweep is already done" 1.0 (introProgress widths 0.0 0.0)

  let
    gutter = 100.0
    viewport = 1440.0
    full = landing widths gutter viewport 0.5 (-1)
    whole = planSweep widths gutter viewport full full
    early = planSweep widths gutter viewport full (landing widths gutter viewport 0.5 2)
  expect t "a full sweep runs the full duration" 1900.0 whole.duration
  expect t "a sweep plans a delay per column" (length widths) (length whole.delays)
  expect t "a full sweep brings columns in left to right" true
    (all identity (zipWith (<=) whole.delays (fromMaybe [] (Array.tail whole.delays))))
  expect t "every delay falls within the sweep" true
    (all (\ms -> ms >= 0.0 && ms <= whole.duration) whole.delays)
  expect t "a short sweep runs shorter" true (early.duration < whole.duration)
  expect t "a short sweep keeps a floor" true (early.duration >= 0.45 * 1900.0)
  expect t "a sweep back toward the start stages every column within it" true
    (all (\ms -> ms <= early.duration) early.delays)

  expect t "the centred landing places a column's edge mid-viewport"
    (gutter + 290.0 + 80.0 - viewport / 2.0)
    (landing widths gutter viewport 0.5 2)
  expect t "a top landing places the column at the viewport's edge" (gutter + 290.0 + 80.0)
    (landing widths gutter 600.0 0.0 2)
  expect t "-1 lands on the last column" (landing widths gutter viewport 0.5 8)
    (landing widths gutter viewport 0.5 (-1))
  expect t "the first column is held at the rail's floor" true
    (landing widths gutter viewport 0.5 0 <= 0.0)

  let
    stops = map (landing widths gutter viewport 0.5) [ 0, 1, 2, 3, 4, 5, 6, 7, 8 ]
    stop i = fromMaybe 0.0 (stops !! i)
  expect t "an arrow steps forward to the next year" (stop 4)
    (stepTarget widths gutter viewport (stop 3) 1)
  expect t "an arrow steps back to the previous year" (stop 2)
    (stepTarget widths gutter viewport (stop 3) (-1))
  expect t "between two years, forward goes to the nearer one ahead" (stop 4)
    (stepTarget widths gutter viewport (stop 3 + 40.0) 1)
  expect t "at the last year, forward stays put" (stop 8)
    (stepTarget widths gutter viewport (stop 8) 1)

  let
    oneFrame = followTo 0.0 100.0 16.67
    twoHalves = followTo (followTo 0.0 100.0 8.335) 100.0 8.335
  expect t "the glide is frame-rate independent" true (near oneFrame twoHalves)
  expect t "the glide closes part of the way per frame" true (oneFrame > 0.0 && oneFrame < 100.0)

  expect t "a single month reads as its month" (Just "jun") (label (info 2023 "Jun" Nothing))
  expect t "a single month is spoken in full" (Just "June") (spoken (info 2023 "Jun" Nothing))
  expect t "a range within the year" (Just "jun – sep") (label (info 2022 "Jun" (Just "Sep")))
  expect t "a range within the year, spoken" (Just "June to September")
    (spoken (info 2022 "June" (Just "9")))
  expect t "a run past New Year names both years" (Just "sep 2021 – jun 2024")
    (label (info 2021 "Sep" (Just "Jun 2024")))
  expect t "a run past New Year, spoken" (Just "September 2021 to June 2024")
    (spoken (info 2021 "Sep" (Just "Jun 2024")))
  expect t "an end month before the start runs into the next year" (Just "nov 2025 – feb 2026")
    (label (info 2025 "Nov" (Just "Feb")))
  expect t "a run's months are counted inclusively" (Just 34)
    (map _.months (info 2021 "Sep" (Just "Jun 2024")))
  expect t "a month that cannot be read is no period" Nothing (label (info 2023 "sometime" Nothing))

  let
    periods = Array.mapMaybe identity
      [ info 2020 "Sep" (Just "Jun 2024")
      , info 2021 "Jun" (Just "Aug")
      , info 2021 "Sep" (Just "Jun 2024")
      , info 2022 "Jun" (Just "Sep")
      , info 2023 "Jun" (Just "Dec")
      , info 2023 "Aug" Nothing
      ]
    runs = runsOf periods
  expect t "the longest run is drawn first" (Just 2020) (map _.year (Array.head runs))
  expect t "a single month is drawn last, over the runs beneath it" (Just 8)
    (map _.month (Array.last runs))

  expect t "a run knows where it ends" (Just { year: 2024, month: 6 })
    ( map (\run -> { year: run.endYear, month: run.endMonth })
        (Array.find (\run -> run.year == 2020) runs)
    )

  let
    columns = columnsFor [ 2020, 2021, 2022, 2023, 2024 ]
    laid = railSpans columns runs
    spanOf year month = Array.find (\span -> span.year == year && span.month == month) laid
    august = spanOf 2023 8
    teaching = spanOf 2021 9
  expect t "every period gets a span on the rail" (length runs) (length laid)
  expect t "a month's span starts at its month in its column" (Just true)
    (map (\span -> near span.left (3.0 * 290.0 + 7.0 / 12.0 * 290.0)) august)
  expect t "a month's span is a twelfth of the year" (Just true)
    (map (\span -> near span.width (290.0 / 12.0 - 1.0)) august)
  expect t "a run past New Year spans the columns after it" (Just true)
    ( map
        ( \span -> near span.width
            (4.0 * 290.0 + 6.0 / 12.0 * 290.0 - (290.0 + 8.0 / 12.0 * 290.0) - 1.0)
        )
        teaching
    )
  expect t "longer runs are laid first, so shorter ones draw over them" (Just 2020)
    (map _.year (Array.head laid))
  expect t "a span carries its period's key" (Just "2021-9-2024-6") (map _.key teaching)

  expect t "in the dark, the light switch offers the lights"
    "lights on — switch to light mode"
    (themeAriaFor true)
  expect t "in the light, the light switch offers the dark"
    "lights off — switch to dark mode"
    (themeAriaFor false)
  expect t "in the dark, the light switch shows the sun" "lucide:sun" (themeIconFor true)
  expect t "in the light, the light switch shows the moon" "lucide:moon" (themeIconFor false)

  expect t "the S-curve starts at rest" 0.0 (smoothstep 0.0)
  expect t "the S-curve is halfway at the midpoint" 0.5 (smoothstep 0.5)
  expect t "the S-curve ends at rest" 1.0 (smoothstep 1.0)
  expect t "the S-curve holds before its start" 0.0 (smoothstep (-0.5))
  expect t "the S-curve holds past its end" 1.0 (smoothstep 1.5)
  expect t "the inverse answers when the sweep reaches each point" true
    (all (\y -> near (smoothstep (smoothstepInv y)) y) [ 0.05, 0.25, 0.5, 0.75, 0.95 ])
  expect t "the inverse meets the curve's ends" true
    (near (smoothstepInv 0.0) 0.0 && near (smoothstepInv 1.0) 1.0)

  expect t "each column starts where the ones before it end" [ 0.0, 290.0, 370.0 ]
    (offsets [ 290.0, 80.0, 290.0 ])
  expect t "KNOWN BUG: a rail with no columns still gets a start at 0" [ 0.0 ] (offsets [])

  expect t "the scroll limit centres the last year's leading edge"
    (gutter + 290.0 + 80.0 + 6.0 * 290.0 - viewport / 2.0)
    (scrollLimit widths gutter viewport)
  expect t "a rail too short to scroll has no limit" 0.0 (scrollLimit [ 290.0 ] gutter viewport)
  expect t "KNOWN BUG: a rail with no columns takes its limit from the gutter" 300.0
    (scrollLimit [] 800.0 1000.0)
  expect t "the scroll floor centres the first year" (gutter - viewport / 2.0)
    (scrollFloor gutter viewport)
  expect t "the scroll floor never rises above zero" 0.0 (scrollFloor 900.0 1440.0)
  expect t "the last year's landing is the scroll limit" (scrollLimit widths gutter viewport)
    (landing widths gutter viewport 0.5 (-1))
  expect t "the first year's landing is the scroll floor" (scrollFloor gutter viewport)
    (landing widths gutter viewport 0.5 0)
  expect t "at the first year, back stays put" (stop 0)
    (stepTarget widths gutter viewport (stop 0) (-1))

  let
    rail = columnsFor [ 2022, 2019 ]
  expect t "the rail runs every year from the first entry to the last" [ 2019, 2020, 2021, 2022 ]
    (map _.year rail)
  expect t "only years with entries are filled" [ true, false, false, true ] (map _.filled rail)
  expect t "empty years are bare ticks and the last column carries the tail"
    [ 290.0, 80.0, 80.0, 360.0 ]
    (map _.width rail)
  expect t "a column's span is its year alone, without the tail" [ 290.0, 80.0, 80.0, 290.0 ]
    (map _.span rail)
  expect t "no entries, no rail" [] (map _.year (columnsFor []))

  let
    wheel =
      { deltaX: 0.0
      , deltaY: 40.0
      , scrollTop: 0.0
      , clientHeight: 600.0
      , scrollHeight: 900.0
      , idle: 1.0e9
      , railIdle: 1.0e9
      }
  expect t "a long year takes a downward wheel while it has more below" true
    (columnTakesWheel wheel)
  expect t "a long year takes an upward wheel while it has more above" true
    (columnTakesWheel wheel { deltaY = -40.0, scrollTop = 120.0 })
  expect t "a long year at its bottom hands a fresh downward wheel to the rail" false
    (columnTakesWheel wheel { scrollTop = 300.0 })
  expect t "a long year at its top hands a fresh upward wheel to the rail" false
    (columnTakesWheel wheel { deltaY = -40.0 })
  expect t "a flick that began on the year stays with it past the bottom" true
    (columnTakesWheel wheel { scrollTop = 300.0, idle = 16.0 })
  expect t "a pause long enough frees the wheel for the rail" false
    (columnTakesWheel wheel { scrollTop = 300.0, idle = 400.0 })
  expect t "a year that fits never takes the wheel" false
    (columnTakesWheel wheel { scrollHeight = 600.0 })
  expect t "a sideways wheel always moves the rail" false
    (columnTakesWheel wheel { deltaX = 60.0, idle = 16.0 })
  expect t "a wheel event with no movement moves the rail" false
    (columnTakesWheel wheel { deltaY = 0.0 })
  expect t "a sweep the rail took keeps the rail as a long year slides under the pointer" false
    (columnTakesWheel wheel { railIdle = 16.0 })
  expect t "after a pause, a long year under the pointer takes a fresh wheel" true
    (columnTakesWheel wheel { railIdle = 400.0 })

  let
    idle = { rested: Nothing, candidate: Nothing, anchor: Nothing }
    at = { x: 100.0, y: 200.0 }
    opened = idle { rested = Just "2023-5-2024-3", anchor = Just at }
  expect t "a pointer moving onto a period with nothing open starts resting there" Rest
    (hoverStep idle "2023-5-2024-3" at)
  expect t "moving on within the period it rests toward keeps the rest running" Ignore
    (hoverStep idle { candidate = Just "2023-5-2024-3" } "2023-5-2024-3" at)
  expect t "moving onto another period restarts the rest there" Rest
    (hoverStep idle { candidate = Just "2023-5-2024-3" } "2023-6-2023-8" at)
  expect t "moving within the open period drops any rest toward another" Settle
    (hoverStep opened { candidate = Just "2023-6-2023-8" } "2023-5-2024-3" { x: 100.0, y: 260.0 })
  expect t "a nudge where a period opened does not hand it to the one that slid under" Ignore
    (hoverStep opened "2023-6-2023-8" { x: 104.0, y: 207.0 })
  expect t "moving clear of where it opened lets another period take over" Rest
    (hoverStep opened "2023-6-2023-8" { x: 100.0, y: 230.0 })

  expect t "a requested year lands on its column" 1 (targetIndex rail (notNull 2020))
  expect t "no requested year lands at the end" (-1) (targetIndex rail null)
  expect t "a year off the rail lands at the end" (-1) (targetIndex rail (notNull 1999))

  let
    fade left width translate coarse =
      markerOpacity { left, width, viewport: 1440.0, translate, coarse }
  expect t "a column resting mid-viewport is fully lit" 1.0 (fade 500.0 290.0 0.0 false)
  expect t "a year on screen at rest is not dimmed by a fade it never entered" 1.0
    (fade 100.0 290.0 0.0 false)
  expect t "a column sliding under the label gutter dims with the distance left" 0.25
    (fade 100.0 290.0 300.0 false)
  expect t "a column past the gutter is out" 0.0 (fade (-50.0) 290.0 500.0 false)
  expect t "a column running off the right edge dims toward it" true
    (near (fade 1100.0 290.0 0.0 false) 0.975)
  expect t "under a fine pointer a column mostly off the right edge is nearly out" true
    (near (fade 1250.0 290.0 0.0 false) 0.225)
  expect t "on touch, a column at least half on screen stays fully lit" 1.0
    (fade 1250.0 290.0 0.0 true)
  expect t "on touch, a column mostly off screen still fades out" 0.0
    (fade 1350.0 290.0 0.0 true)
  expect t "every opacity is between 0 and 1" true
    ( all (\left -> between 0.0 1.0 (fade left 290.0 200.0 false))
        [ -400.0, -100.0, 0.0, 50.0, 200.0, 700.0, 1200.0, 1400.0, 1800.0 ]
    )

  expect t "a fling loses 6% per 60 Hz frame" true (near (decayVelocity 10.0 16.67) 9.4)
  expect t "no time, no decay" 10.0 (decayVelocity 10.0 0.0)
  expect t "the fling decays the same at any refresh rate" true
    (near (decayVelocity (decayVelocity 10.0 8.335) 8.335) (decayVelocity 10.0 16.67))

  expect t "a month reads from its short name" (Just 6) (monthNumber "Jun")
  expect t "a month reads from its full name, any case, any padding" (Just 6)
    (monthNumber " JUNE ")
  expect t "a month reads from its number" (Just 12) (monthNumber "12")
  expect t "a month reads from a padded number" (Just 2) (monthNumber "02")
  expect t "a longer abbreviation reads too" (Just 9) (monthNumber "Sept")
  expect t "thirteen is no month" Nothing (monthNumber "13")
  expect t "zero is no month" Nothing (monthNumber "0")
  expect t "an empty month is no month" Nothing (monthNumber "")
  expect t "a period shows a month as three letters" [ "jun", "sep", "sep", "dec" ]
    (map monthLabel [ "June", "9", "Sept", "DEC" ])
  expect t "a month that cannot be read shows its first three letters as written" "Sum"
    (monthLabel " Summer ")

  expect t "a bare month has no year" (notNull { month: 2, year: null }) (periodPoint "Feb")
  expect t "a month and year" (notNull { month: 2, year: notNull 2026 }) (periodPoint "Feb 2026")
  expect t "a dashed year and month" (notNull { month: 2, year: notNull 2026 })
    (periodPoint "2026-02")
  expect t "a slashed month and year" (notNull { month: 2, year: notNull 2026 })
    (periodPoint "02/2026")
  expect t "a comma between month and year" (notNull { month: 2, year: notNull 2026 })
    (periodPoint "February, 2026")
  expect t "a year alone names no month" null (periodPoint "2026")
  expect t "words that name no month are no end" null (periodPoint "sometime")

  expect t "?year= names its year" (Just 2021) (landingYear "2021")
  expect t "?year= ignores surrounding space, as Number does" (Just 2021) (landingYear " 2021 ")
  expect t "an empty ?year= names no year" Nothing (landingYear "")
  expect t "a fractional ?year= names no year" Nothing (landingYear "2021.5")
  expect t "a non-number ?year= names no year" Nothing (landingYear "latest")
  expect t "a year below one names no year" Nothing (landingYear "-3")
  expect t "an exponent reads the way Number reads it" (Just 1000) (landingYear "1e3")

  let
    june = { year: 2023, month: 6, endYear: 2023, endMonth: 8 }
    fall = { year: 2023, month: 9, endYear: 2024, endMonth: 3 }
    ai = { year: 2023, month: 9, endYear: 2023, endMonth: 11 }
    termPeriods = Array.mapMaybe identity
      [ info 2023 "Jun" (Just "Aug")
      , info 2023 "Sep" (Just "Mar 2024")
      , info 2023 "Sep" (Just "Nov")
      ]
  expect t "no spot names no period" false (sameSpot null june)
  expect t "a spot names its own period" true (sameSpot (notNull june) june)
  expect t "a spot a month off names another period" false
    (sameSpot (notNull (june { month = 7 })) june)
  expect t "a spot a year off names another period" false
    (sameSpot (notNull (june { year = 2022 })) june)
  expect t "two periods opening in the same month are different periods" false
    (sameSpot (notNull fall) ai)
  expect t "a period's key names both its ends" "2023-9-2024-3" (spotKey fall)
  expect t "periods opening in the same month get different keys" true (spotKey fall /= spotKey ai)

  expect t "?period= spotlights the period opening that month in the landed year" (notNull june)
    (requestedSpot (notNull 2023) "jun" termPeriods)
  expect t "?period= keeps the landed year over one it writes" (notNull june)
    (requestedSpot (notNull 2023) "Jun 2021" termPeriods)
  expect t "?period= picks the first period, in page order, opening that month" (notNull fall)
    (requestedSpot (notNull 2023) "sep" termPeriods)
  expect t "?period= naming a month nothing opens in spotlights nothing" null
    (requestedSpot (notNull 2023) "feb" termPeriods)
  expect t "?period= without a landed year spotlights nothing" null
    (requestedSpot null "jun" termPeriods)
  expect t "no ?period= spotlights nothing" null (requestedSpot (notNull 2023) "" termPeriods)

  expect t "a tap spotlights a period when none is" (notNull june) (togglePick null june)
  expect t "a tap on the spotlit period lets it go" null (togglePick (notNull june) june)
  expect t "a tap on another period moves the spotlight" (notNull june)
    (togglePick (notNull fall) june)
  expect t "a tap on a period opening the same month as the spotlit one moves the spotlight"
    (notNull ai)
    (togglePick (notNull fall) ai)

  expect t "the skip link focuses the last year for the end of the rail" (Just 2022)
    (_.year <$> landedColumn rail (-1))
  expect t "the skip link focuses the landed year" (Just 2019) (_.year <$> landedColumn rail 0)
  expect t "a column past the rail is none" Nothing (_.year <$> landedColumn rail 9)
  expect t "an empty rail has nowhere to focus" Nothing (_.year <$> landedColumn [] (-1))

  expect t "the panel grows from the bar's rect as a scale of the viewport"
    { opacity: 1.0, x: 40.0, y: 12.0, scaleX: 0.5, scaleY: 0.1 }
    ( poseFrom { left: 40.0, top: 12.0, width: 720.0, height: 90.0 }
        { width: 1440.0, height: 900.0 }
    )

  expect t "a kernel opening with the sweep sweeps" true (kernelFor true false (pure 0)).sweep
  expect t "reduced motion holds the sweep back" false (kernelFor true true (pure 0)).sweep
  expect t "reduced motion is passed on to the kernel" true (kernelFor true true (pure 0)).reduced
  expect t "a kernel opening at rest does not sweep" false (kernelFor false false (pure 0)).sweep

  let
    body =
      [ { id: "intro", from: null }
      , { id: "june", from: notNull "Jun 2023" }
      , { id: "note", from: null }
      , { id: "sept", from: notNull "2023-09" }
      , { id: "june-again", from: notNull "june" }
      , { id: "garbled", from: notNull "someday" }
      ]
    ids month = _.id <$> startingIn _.from month body
  expect t "a month keeps only the periods that open in it" [ "june", "june-again" ] (ids 6)
  expect t "a month read another way still matches" [ "sept" ] (ids 9)
  expect t "a month no period opens in keeps the whole body" (_.id <$> body) (ids 3)
  expect t "an empty body stays empty" 0
    (length (startingIn _.from 6 (Array.filter (const false) body)))
