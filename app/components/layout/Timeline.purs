-- | ## Timeline
-- |
-- | The setup composable behind `Timeline.vue`: the year columns the rail
-- | draws, the periods laid across them, the eased sweep that opens on the
-- | earliest year and lands on the requested (or latest) one, and the
-- | numeric policy the rail and column kernels call back into once per
-- | frame. It also reads the route — the year to land on and the period to
-- | light — decides how the panel enters, and knows the way out. The
-- | footer's light switch rides along: the color toggle, with the label and
-- | icon that say which way it flips. The SFC keeps the content query, the
-- | template refs, the route, router and store handles, and one call here;
-- | the DOM listeners and per-frame writes live behind the FFI edge.
-- |
-- | The sweep is deliberately non-linear. `smoothstep` alone would race past
-- | the sparse early years, so progress is raised to an exponent solved so
-- | that the first `headSpan` columns take `introHold` of the run — never
-- | less time than a plain `smoothstep` gives them: the view lingers where
-- | the story starts, then accelerates through the years that carry weight.
-- | A sweep with only a short way to go runs shorter, and each column fades
-- | in as the sweep brings it into view rather than on a schedule drawn for
-- | the full rail.
module App.Components.Timeline
  ( Column
  , DomElement
  , FadeInput
  , Folding
  , HoverStep(..)
  , Node
  , PanelPose
  , PanelSpring
  , PeriodControls
  , PeriodInfo
  , Point
  , Pointer
  , RailKernel
  , RailSpan
  , RouteHandle
  , RouterHandle
  , Run
  , Running
  , Spot
  , SweepPlan
  , TimelineArgs
  , TimelineBindings
  , TimelineDoc
  , Tuning
  , WheelInput
  , YearDoc
  , YearRow
  , columnTakesWheel
  , columnsFor
  , decayVelocity
  , foldedKeys
  , hoverStep
  , followTo
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
  , onlyPeriod
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
  , setup
  , smoothstep
  , smoothstepInv
  , spotKey
  , spotOf
  , startingIn
  , stepTarget
  , targetIndex
  , themeAriaFor
  , togglePick
  ) where

import Prelude

import App.Stores.Timeline (Rect)
import App.Utils.ThemeIcon (themeIconFor)
import Data.Array
  ( concatMap
  , elem
  , filter
  , find
  , findIndex
  , findLastIndex
  , findMap
  , init
  , last
  , length
  , mapMaybe
  , mapWithIndex
  , null
  , range
  , scanl
  , sortBy
  , take
  , (!!)
  , (:)
  )
import Data.Foldable (maximum, minimum, sum, traverse_)
import Data.Function.Uncurried (Fn1, Fn2, Fn3, Fn5, mkFn1, mkFn2, mkFn3, mkFn5)
import Data.Int (fromString, toNumber) as Int
import Data.Maybe (Maybe(..), fromMaybe, isJust, isNothing, maybe)
import Data.Nullable (Nullable, notNull, toMaybe, toNullable)
import Data.Nullable (null) as Nullable
import Data.Number (abs, asin, log, pow, sin, sqrt)
import Data.String (Pattern(..), Replacement(..), replaceAll, split, take, toLower, trim) as String
import Data.String.CodeUnits (take) as CodeUnits
import Data.Traversable (traverse)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Timer (TimeoutId, clearTimeout, setTimeout)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , mkEffectFn1
  , mkEffectFn2
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  )
import Vue
  ( Computed
  , Ref
  , computed
  , onMounted
  , onUnmounted
  , provide
  , read
  , ref
  , shallowRef
  , watchGetter
  , watchRef
  , write
  )

-- | An `HTMLElement` — opaque here; only the FFI touches it. @ts HTMLElement
foreign import data DomElement :: Type

-- | A node in a year's body — a period block, a paragraph, text. Opaque
-- | here; the FFI reads and rewrites it. @ts import("minimark").MinimarkNode
foreign import data Node :: Type

-- | One year's page as the content query returns it — opaque here; the FFI
-- | reads its year and its body, and the template renders it whole.
-- | @ts import("@nuxt/content").TimelineCollectionItem
foreign import data TimelineDoc :: Type

-- | The current route, whose query names the year to land on and the
-- | period to light. @ts import("vue-router").RouteLocationNormalizedLoaded
foreign import data RouteHandle :: Type

-- | The router, for leaving the timeline. @ts import("vue-router").Router
foreign import data RouterHandle :: Type

foreign import docYearImpl :: TimelineDoc -> Int

foreign import docNodesImpl :: TimelineDoc -> Array Node

foreign import queryFirstImpl :: EffectFn2 RouteHandle String String

foreign import wholeNumberImpl :: String -> Nullable Int

foreign import cameFromImpl :: Effect Boolean

foreign import routerBackImpl :: EffectFn1 RouterHandle Unit

foreign import routerPushImpl :: EffectFn2 RouterHandle String Unit

foreign import viewportImpl :: Effect { width :: Number, height :: Number }

foreign import startRailImpl :: EffectFn2 DomElement RailKernel Running

foreign import startColumnImpl :: EffectFn2 DomElement RailKernel Running

foreign import periodStartImpl :: Node -> Nullable String

foreign import periodEndImpl :: Node -> Nullable String

foreign import periodBlocksImpl :: Node -> Int

foreign import revealPeriodImpl :: EffectFn3 DomElement String Boolean Unit

foreign import revealOpenImpl :: EffectFn2 DomElement Boolean Unit

foreign import focusYearImpl :: EffectFn2 DomElement Int Unit

foreign import focusQuietlyImpl :: EffectFn1 DomElement Unit

foreign import lockScrollImpl :: Effect (Effect Unit)

foreign import onEscapeImpl :: EffectFn1 (Effect Unit) (Effect Unit)

foreign import onPressAwayImpl :: EffectFn1 DomElement (Effect Unit)

foreign import useMediaQueryImpl :: EffectFn1 String (Ref Boolean)

foreign import prefersReducedMotionImpl :: Effect Boolean

foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit

-- | Timeline.vue's styles break on the same ranges; keep the two in sync.
narrowQuery :: String
narrowQuery = "(width <= 900px), (height <= 560px)"

reducedQuery :: String
reducedQuery = "(prefers-reduced-motion: reduce)"

-- | A pose of the panel for motion-v: its opacity, its offset from the
-- | viewport's top left in px, and its scale on each axis.
type PanelPose =
  { opacity :: Number
  , x :: Number
  , y :: Number
  , scaleX :: Number
  , scaleY :: Number
  }

-- | A motion-v transition: a spring, and how it springs.
type PanelSpring =
  { "type" :: String
  , stiffness :: Number
  , damping :: Number
  , mass :: Number
  }

panelTo :: PanelPose
panelTo = { opacity: 1.0, x: 0.0, y: 0.0, scaleX: 1.0, scaleY: 1.0 }

panelMove :: PanelSpring
panelMove = { "type": "spring", stiffness: 290.0, damping: 22.0, mass: 0.75 }

contentHoldMs :: Int
contentHoldMs = 260

railMs :: Number
railMs = 1900.0

introHold :: Number
introHold = 0.35

headSpan :: Int
headSpan = 2

maxExponent :: Number
maxExponent = 2.6

shortestShare :: Number
shortestShare = 0.45

revealAt :: Number
revealAt = 0.8

openingStagger :: Number
openingStagger = 0.3

followRate :: Number
followRate = 0.28

filledWidth :: Number
filledWidth = 290.0

emptyWidth :: Number
emptyWidth = 80.0

tailPad :: Number
tailPad = 70.0

-- | `smoothstep` — the S-curve that eases the sweep in and out.
smoothstep :: Number -> Number
smoothstep x =
  let
    n = clamp 0.0 1.0 x
  in
    n * n * (3.0 - 2.0 * n)

-- | The exact inverse of `smoothstep` on [0, 1]. Answers "when does the
-- | sweep reach this point?", which is what a column's fade-in waits on.
smoothstepInv :: Number -> Number
smoothstepInv y = 0.5 - sin (asin (1.0 - 2.0 * clamp 0.0 1.0 y) / 3.0)

-- | The exponent that spends `introHold` of the run on the first `headSpan`
-- | columns: solve `smoothstep(introHold) ^ e = head / total` for `e`, held
-- | at 1 or more — below 1 the curve would race through the head instead
-- | of holding it — and no steeper than `maxExponent`. A degenerate rail,
-- | empty or all head, gets a plausible curve.
introExponent :: Array Number -> Number
introExponent sizes =
  let
    total = sum sizes
    share = if total <= 0.0 then 0.0 else sum (take headSpan sizes) / total
    gate = smoothstep introHold
  in
    if share <= 0.0 || gate <= 0.0 || gate >= 1.0 then maxExponent
    else clamp 1.0 maxExponent (log share / log gate)

-- | How far through its travel a sweep of `duration` ms has come, 0 to 1,
-- | after `elapsed` ms.
introProgress :: Array Number -> Number -> Number -> Number
introProgress sizes duration elapsed
  | duration <= 0.0 = 1.0
  | otherwise = clamp 0.0 1.0 (pow (smoothstep (elapsed / duration)) (introExponent sizes))

-- | The cumulative extent before each column — where along the rail it
-- | starts.
offsets :: Array Number -> Array Number
offsets sizes = 0.0 : fromMaybe [] (init (scanl (+) 0.0 sizes))

type SweepPlan =
  { -- | How long the sweep runs, in ms.
    duration :: Number
  -- | When each column fades in, in ms from the start.
  , delays :: Array Number
  }

-- | The sweep from rest to `end` along a rail of `sizes`, with `gutter`
-- | before the first column and `viewport` of it on screen, where a full
-- | sweep travels `full`. It runs shorter the less ground it covers, and
-- | each column fades in as the sweep brings its leading edge `revealAt`
-- | of the way into view; the columns in view from the start come in left
-- | to right over its opening, and one it never reaches waits out the run.
planSweep :: Array Number -> Number -> Number -> Number -> Number -> SweepPlan
planSweep sizes gutter viewport full end =
  let
    ground = if full <= 0.0 then 1.0 else min 1.0 (abs end / full)
    duration = railMs * clamp shortestShare 1.0 (sqrt ground)
    exponent = introExponent sizes
    reach = viewport * revealAt
    arrival share = duration * smoothstepInv (pow share (1.0 / exponent))
    delay offset =
      let
        travel = gutter + offset - reach
      in
        if travel <= 0.0 then
          duration * openingStagger *
            (if reach <= 0.0 then 0.0 else clamp 0.0 1.0 ((gutter + offset) / reach))
        else if end > 0.0 && travel < end then arrival (travel / end)
        else duration
  in
    { duration, delays: map delay (offsets sizes) }

type Column =
  { -- | The calendar year this column marks.
    year :: Int
  -- | True when the year has an entry to show; empty years are bare ticks.
  , filled :: Boolean
  -- | Column width on the rail, in px — the year's span plus, on the last
  -- | column, the tail padding.
  , width :: Number
  -- | The width that stands for the year itself, in px: where a month
  -- | falls along the rail is a fraction of this.
  , span :: Number
  }

-- | Every year from the earliest entry to the latest, gaps included — the
-- | empty stretches are the point, since they show the shape of a life
-- | rather than a list of jobs.
columnsFor :: Array Int -> Array Column
columnsFor years = case minimum years, maximum years of
  Just first, Just final -> build (range first final)
  _, _ -> []
  where
  build span =
    let
      count = length span
      column index year =
        let
          yearSpan = if elem year years then filledWidth else emptyWidth
        in
          { year
          , filled: elem year years
          , width: yearSpan + (if index == count - 1 then tailPad else 0.0)
          , span: yearSpan
          }
    in
      mapWithIndex column span

-- | The column a requested year lands on, or -1 for the end of the rail.
targetIndex :: Array Column -> Nullable Int -> Int
targetIndex columns wanted = case toMaybe wanted of
  Just year -> fromMaybe (-1) (findIndex (\column -> column.year == year) columns)
  Nothing -> -1

placedAt :: Number -> Number -> Number -> Number -> Number
placedAt gutter viewport anchor offset = gutter + offset - viewport * anchor

-- | The rail's scroll limit: far enough that the last year sits centred
-- | with the empty half of the viewport after it. The sweep overshoots the
-- | rail's natural end on purpose, so the latest year lands mid-screen
-- | rather than against the edge.
scrollLimit :: Array Number -> Number -> Number -> Number
scrollLimit sizes gutter viewport = case last (offsets sizes) of
  Just offset -> max 0.0 (placedAt gutter viewport 0.5 offset)
  Nothing -> 0.0

-- | The rail's scroll floor, the mirror of `scrollLimit`: as far back as
-- | the track can be pushed for the first year to sit centred, the empty
-- | half of the viewport before it. Negative — the track past its start —
-- | and never above zero.
scrollFloor :: Number -> Number -> Number
scrollFloor gutter viewport = min 0.0 (placedAt gutter viewport 0.5 0.0)

-- | Where a rail of `sizes` rests with column `target` (the last for -1)
-- | placed `anchor` of the way along the viewport — ½ centres it on the
-- | horizontal rail, 0 sets it at the top of the vertical column — held
-- | between the first and last columns' own resting places.
landing :: Array Number -> Number -> Number -> Number -> Int -> Number
landing sizes gutter viewport anchor target =
  let
    placed = placedAt gutter viewport anchor
    floor = min 0.0 (placed 0.0)
    limit = maybe 0.0 (max 0.0 <<< placed) (last (offsets sizes))
    index = if target < 0 then length sizes - 1 else target
  in
    maybe limit (clamp floor limit <<< placed) (offsets sizes !! index)

-- | Where an arrow key takes the centred rail from `at`: the next year's
-- | resting place in the direction of `step`, or `at` itself at either end.
stepTarget :: Array Number -> Number -> Number -> Number -> Int -> Number
stepTarget sizes gutter viewport at step =
  let
    stops = mapWithIndex (\index _ -> landing sizes gutter viewport 0.5 index) sizes
    ahead = find (_ > at + 1.0) stops
    behind = findLastIndex (_ < at - 1.0) stops >>= (stops !! _)
  in
    fromMaybe at (if step > 0 then ahead else behind)

-- | One frame of the wheel's easing: `at` closes `followRate` of the way to
-- | `goal` per 60 Hz frame, re-based on the frame that actually elapsed so
-- | the glide takes the same time at any refresh rate.
followTo :: Number -> Number -> Number -> Number
followTo at goal frameMs = goal - (goal - at) * pow (1.0 - followRate) (frameMs / 16.67)

monthNames :: Array String
monthNames =
  [ "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec" ]

monthWords :: Array String
monthWords =
  [ "January"
  , "February"
  , "March"
  , "April"
  , "May"
  , "June"
  , "July"
  , "August"
  , "September"
  , "October"
  , "November"
  , "December"
  ]

-- | A month written any of the usual ways — `Jun`, `June`, `6` — as its
-- | number, 1 to 12.
monthNumber :: String -> Maybe Int
monthNumber raw =
  let
    text = String.toLower (String.trim raw)
  in
    case Int.fromString text of
      Just n | n >= 1 && n <= 12 -> Just n
      _ -> (_ + 1) <$> findIndex (_ == CodeUnits.take 3 text) monthNames

-- | The three-letter label a period shows for a month.
monthLabel :: String -> String
monthLabel raw = case monthNumber raw of
  Just n -> fromMaybe raw (monthNames !! (n - 1))
  Nothing -> String.take 3 (String.trim raw)

-- | One end of a period: its month, and its year when that is not the year
-- | the period belongs to — the way a run past New Year is written.
type Point =
  { month :: Int
  , year :: Nullable Int
  }

-- | Reads an end of a period written any of the usual ways — `Feb`,
-- | `Feb 2026`, `2026-02`, `02/2026`; null when no month can be found.
periodPoint :: String -> Nullable Point
periodPoint raw =
  let
    loosen = String.replaceAll (String.Pattern "-") (String.Replacement " ")
      <<< String.replaceAll (String.Pattern "/") (String.Replacement " ")
      <<< String.replaceAll (String.Pattern ",") (String.Replacement " ")
    words = filter (_ /= "") (String.split (String.Pattern " ") (loosen raw))
    year = findMap (\word -> Int.fromString word >>= \n -> if n >= 1000 then Just n else Nothing)
      words
    month = findMap monthNumber words
  in
    toNullable ((\m -> { month: m, year: toNullable year }) <$> month)

-- | A period read whole: where it starts and ends, how many months it ran,
-- | and the two ways of saying so.
type PeriodInfo =
  { -- | The year and month it began.
    year :: Int
  , month :: Int
  -- | The year and month it ran to — the same as the start for one month.
  , endYear :: Int
  , endMonth :: Int
  -- | How many months it covers, both ends included.
  , months :: Int
  -- | What its head shows: `jun`, `jun – sep`, `sep 2020 – jun 2024`.
  , label :: String
  -- | What a screen reader says instead: `June`, `June to September`,
  -- | `September 2020 to June 2024`.
  , spoken :: String
  }

-- | Reads a period of year `home` from its `from` and `to` as written. An
-- | end without a year that falls before the start ran past New Year; a
-- | run into another year names both years, so the reader is never left to
-- | guess which one the opening month belongs to.
periodInfo :: Int -> String -> Nullable String -> Nullable PeriodInfo
periodInfo home from to = toNullable do
  start <- toMaybe (periodPoint from)
  let
    year = fromMaybe home (toMaybe start.year)
    begins = year * 12 + start.month - 1
    ends = case toMaybe to >>= toMaybe <<< periodPoint of
      Just close ->
        let
          closeYear = fromMaybe (if close.month < start.month then year + 1 else year)
            (toMaybe close.year)
        in
          max begins (closeYear * 12 + close.month - 1)
      Nothing -> begins
    endYear = ends `div` 12
    endMonth = ends `mod` 12 + 1
    months = ends - begins + 1
    short n = fromMaybe "" (monthNames !! (n - 1))
    long n = fromMaybe "" (monthWords !! (n - 1))
    crosses = endYear /= year
    say name joint
      | months <= 1 = name start.month
      | crosses = name start.month <> " " <> show year <> joint <> name endMonth <> " " <> show
          endYear
      | otherwise = name start.month <> joint <> name endMonth
  pure
    { year
    , month: start.month
    , endYear
    , endMonth
    , months
    , label: say short " – "
    , spoken: say long " to "
    }

-- | The periods starting in the given month, alone — or the whole body
-- | when none does, so a slip in the bio previews the year rather than
-- | nothing.
onlyPeriod :: Int -> Array Node -> Array Node
onlyPeriod = startingIn periodStartImpl

-- | `onlyPeriod` over any node shape, given how to read a node's opening
-- | end (null for a node that is not a period).
startingIn :: forall node. (node -> Nullable String) -> Int -> Array node -> Array node
startingIn startOf month nodes = case filter startsIn nodes of
  [] -> nodes
  found -> found
  where
  startsIn node =
    (_.month <$> (toMaybe (startOf node) >>= toMaybe <<< periodPoint)) == Just month

-- | A year's page as the timeline reads it: its year and body nodes.
type YearDoc =
  { year :: Int
  , nodes :: Array Node
  }

periodsOf :: Array YearDoc -> Array PeriodInfo
periodsOf = concatMap \doc -> mapMaybe (periodOf doc.year) doc.nodes
  where
  periodOf year node = toMaybe (periodStartImpl node) >>= \from ->
    toMaybe (periodInfo year from (periodEndImpl node))

-- | The keys of the periods with more to say than a headline: their first
-- | paragraph is the headline, and anything after it is held back on the
-- | rail until the period is picked.
foldedKeys :: Array YearDoc -> Array String
foldedKeys = concatMap \doc -> mapMaybe (folded doc.year) doc.nodes
  where
  folded year node = do
    from <- toMaybe (periodStartImpl node)
    info <- toMaybe (periodInfo year from (periodEndImpl node))
    if periodBlocksImpl node > 1 then Just (spotKey (spotOf info)) else Nothing

-- | A period as a run of months: where it starts and ends, both also
-- | counted in months from year zero, and the key naming it in the DOM.
type Run =
  { year :: Int
  , month :: Int
  , endYear :: Int
  , endMonth :: Int
  , start :: Int
  , stop :: Int
  , key :: String
  }

-- | Every period as a run, longest first — the order both layouts draw
-- | them on their one line, so a shorter run lying over a longer one draws
-- | on top and takes the pointer where they overlap.
runsOf :: Array PeriodInfo -> Array Run
runsOf = sortBy longestFirst <<< map toRun
  where
  toRun info =
    { year: info.year
    , month: info.month
    , endYear: info.endYear
    , endMonth: info.endMonth
    , start: info.year * 12 + info.month - 1
    , stop: info.endYear * 12 + info.endMonth - 1
    , key: spotKey (spotOf info)
    }
  longestFirst a b = compare (b.stop - b.start) (a.stop - a.start) <> compare a.start b.start

-- | A period's span on the rail, in px along the whole row of columns.
type RailSpan =
  { year :: Int
  , month :: Int
  , endYear :: Int
  , endMonth :: Int
  , key :: String
  , left :: Number
  , width :: Number
  }

-- | Every period's span on the rail: from its first month in its own
-- | column to the end of its last month in whichever column that falls —
-- | a run past New Year keeps going across the columns after it — in the
-- | runs' own order, longest first.
railSpans :: Array Column -> Array Run -> Array RailSpan
railSpans columns runs = mapMaybe place runs
  where
  starts = offsets (map _.width columns)
  total = sum (map _.width columns)
  edge year month = do
    index <- findIndex (\column -> column.year == year) columns
    column <- columns !! index
    offset <- starts !! index
    pure (offset + Int.toNumber (month - 1) / 12.0 * column.span)
  place run = do
    left <- edge run.year run.month
    let
      right = fromMaybe total (edge (run.stop `div` 12) (run.stop `mod` 12 + 2))
    pure
      { year: run.year
      , month: run.month
      , endYear: run.endYear
      , endMonth: run.endMonth
      , key: run.key
      , left
      , width: max 1.0 (right - left - 1.0)
      }

type FadeInput =
  { -- | The column's left edge, relative to the rail viewport.
    left :: Number
  -- | The column's width in px.
  , width :: Number
  -- | The rail viewport's width in px.
  , viewport :: Number
  -- | How far the track has been scrolled, in px.
  , translate :: Number
  -- | True for touch pointers, which get gentler edge fades.
  , coarse :: Boolean
  }

-- | A column's opacity: it dissolves as it slides under the pinned label
-- | gutter on the left and as it runs off the right edge. The entry fade
-- | tightens to whatever the column has actually travelled, so years already
-- | on screen at rest are never dimmed by a fade they never entered. Touch
-- | viewports keep any column at least half on screen fully lit — there is
-- | no hover there to bring one back.
markerOpacity :: FadeInput -> Number
markerOpacity input =
  let
    exitSpan = if input.coarse then 72.0 else 200.0
    entrySpan = if input.coarse then 160.0 else 400.0
    center = input.left + input.width / 2.0
    entry = min (input.left + input.translate) entrySpan
    entering
      | input.left >= entry = 1.0
      | input.left <= 0.0 || entry <= 0.0 = 0.0
      | otherwise = input.left / entry
    leaving = (input.viewport - center) / exitSpan
    faded = if center > input.viewport - exitSpan then min entering leaving else entering
    onScreen = min (input.left + input.width) (input.viewport - 12.0) - max input.left 72.0
    mostlyVisible = input.width > 0.0 && onScreen / input.width >= 0.5
  in
    if input.coarse && mostlyVisible then 1.0 else clamp 0.0 1.0 faded

-- | Fling decay: 0.94 per 60 Hz frame, re-based on the frame that actually
-- | elapsed so a dropped frame coasts the same distance as a smooth one.
decayVelocity :: Number -> Number -> Number
decayVelocity velocity frameMs = velocity * pow 0.94 (frameMs / 16.67)

type Tuning =
  { -- | How long after the sweep lands its entering classes are stripped.
    settleMs :: Number
  -- | How long into the sweep input starts to cut it short; before that
  -- | the opening plays out.
  , interruptAfterMs :: Number
  -- | Wheel delta multiplier.
  , wheelGain :: Number
  -- | Drag-to-scroll multiplier for mouse pointers.
  , dragGain :: Number
  -- | Drag-to-scroll multiplier for touch, which expects a little lead.
  , touchGain :: Number
  -- | Below this speed (px/ms) a release does not fling at all.
  , flingFloor :: Number
  -- | Below this speed a running fling stops.
  , stopFloor :: Number
  -- | How far a touch must travel before its axis is locked in, in px.
  , axisSlop :: Number
  -- | How long after a year's text last took the wheel the gesture is
  -- | still its own, in ms.
  , wheelHoldMs :: Number
  }

tuning :: Tuning
tuning =
  { settleMs: 100.0
  , interruptAfterMs: 550.0
  , wheelGain: 1.4
  , dragGain: 1.0
  , touchGain: 1.15
  , flingFloor: 0.08
  , stopFloor: 0.025
  , axisSlop: 8.0
  , wheelHoldMs: 180.0
  }

-- | A wheel event over a year's text, with where that text is scrolled.
type WheelInput =
  { deltaX :: Number
  , deltaY :: Number
  , scrollTop :: Number
  , clientHeight :: Number
  , scrollHeight :: Number
  -- | How long since this year's text last took the wheel, in ms.
  , idle :: Number
  -- | How long since the rail last took the wheel, in ms.
  , railIdle :: Number
  }

-- | Whether a wheel event scrolls the year's text under it rather than the
-- | rail: when it runs mostly up or down over text too long for the rail,
-- | and the text can still move that way. A gesture keeps to whichever
-- | took its first event: sweeping the rail sideways never snags on a
-- | long year sliding under the pointer, and the tail of a flick down a
-- | year stops at its bottom instead of carrying the rail off.
columnTakesWheel :: WheelInput -> Boolean
columnTakesWheel input
  | input.railIdle < tuning.wheelHoldMs = false
  | otherwise = vertical && overflows && (held || movable)
      where
      vertical = abs input.deltaY > abs input.deltaX
      overflows = input.scrollHeight - input.clientHeight > 1.0
      held = input.idle < tuning.wheelHoldMs
      movable
        | input.deltaY > 0.0 = input.scrollTop + input.clientHeight < input.scrollHeight - 1.0
        | otherwise = input.scrollTop > 0.0

type RailKernel =
  { -- | The sweep for the measured extents, gutter, viewport, full travel,
    -- | and end.
    plan :: Fn5 (Array Number) Number Number Number Number SweepPlan
  -- | Sweep progress (0 to 1) for those extents and a duration, at
  -- | `elapsed` ms.
  , progress :: Fn3 (Array Number) Number Number Number
  -- | A column's opacity for its current position on the rail.
  , opacity :: Fn1 FadeInput Number
  -- | Fling velocity after a frame of the given length.
  , decay :: Fn2 Number Number Number
  -- | One frame of the eased glide from a position toward a goal.
  , follow :: Fn3 Number Number Number Number
  -- | Clamp a scroll offset into [floor, limit].
  , clampTo :: Fn3 Number Number Number Number
  -- | The scroll floor for the gutter before the first column and the
  -- | viewport extent.
  , scrollFloor :: Fn2 Number Number Number
  -- | The scroll limit for the measured extents, the same gutter, and the
  -- | same viewport extent.
  , scrollLimit :: Fn3 (Array Number) Number Number Number
  -- | Where a column rests, placed a share of the way along the viewport.
  , landing :: Fn5 (Array Number) Number Number Number Int Number
  -- | Where an arrow key takes the rail.
  , step :: Fn5 (Array Number) Number Number Number Int Number
  -- | Whether a wheel event scrolls the year's text under it instead.
  , takesWheel :: Fn1 WheelInput Boolean
  -- | Reads the column to land on, or -1 for the end of the rail — read
  -- | live, since a prerendered page learns its query only after mount.
  , target :: Effect Int
  -- | True to open with the sweep; false lands at rest.
  , sweep :: Boolean
  -- | True when the viewer asked for reduced motion: every move is
  -- | instant.
  , reduced :: Boolean
  -- | Every constant the rail's feel depends on.
  , tuning :: Tuning
  }

-- | The pure policy the FFI kernels call back into — no DOM and no state,
-- | just the arithmetic deciding where the rail sits and how bright each
-- | column is.
kernelFor :: Boolean -> Boolean -> Effect Int -> RailKernel
kernelFor sweep reduced target =
  { plan: mkFn5 planSweep
  , progress: mkFn3 introProgress
  , opacity: mkFn1 markerOpacity
  , decay: mkFn2 decayVelocity
  , follow: mkFn3 followTo
  , clampTo: mkFn3 clamp
  , scrollFloor: mkFn2 scrollFloor
  , scrollLimit: mkFn3 scrollLimit
  , landing: mkFn5 landing
  , step: mkFn5 stepTarget
  , takesWheel: mkFn1 columnTakesWheel
  , target
  , sweep: sweep && not reduced
  , reduced
  , tuning
  }

-- | A started kernel: its teardown, the move to a target that arrived
-- | late, and the hand-over that ends its sweep where it is.
type Running =
  { stop :: Effect Unit
  , retarget :: Effect Unit
  , interrupt :: Effect Unit
  }

-- | What the footer's light switch says it does: turn the lights on when
-- | the page is dark, off when it is light.
themeAriaFor :: Boolean -> String
themeAriaFor dark =
  if dark then "lights on — switch to light mode" else "lights off — switch to dark mode"

-- | A period named by where it starts and where it ends: several periods
-- | can open in the same month — a term's courses, say — but not run the
-- | same stretch.
type Spot =
  { year :: Int
  , month :: Int
  , endYear :: Int
  , endMonth :: Int
  }

-- | The spot of a period read whole.
spotOf :: forall r. { year :: Int, month :: Int, endYear :: Int, endMonth :: Int | r } -> Spot
spotOf period =
  { year: period.year, month: period.month, endYear: period.endYear, endMonth: period.endMonth }

-- | The key naming a period in the DOM and in the template's lists.
spotKey :: Spot -> String
spotKey spot =
  show spot.year <> "-" <> show spot.month <> "-" <> show spot.endYear <> "-" <> show spot.endMonth

-- | The period a route asks to spotlight: the first, in page order, opening
-- | in the month `?period=` names in the year `?year=` lands on — none
-- | unless both can be read and such a period exists.
requestedSpot :: Nullable Int -> String -> Array PeriodInfo -> Nullable Spot
requestedSpot landed raw periods = toNullable do
  year <- toMaybe landed
  opening <- toMaybe (periodPoint raw)
  spotOf <$> find (\period -> period.year == year && period.month == opening.month) periods

-- | The spotlight after a tap on the period at `spot`: that period, or
-- | none when it already held the spotlight.
togglePick :: Nullable Spot -> Spot -> Nullable Spot
togglePick current spot =
  if sameSpot current spot then Nullable.null else notNull (spotOf spot)

-- | The column the rail landed on for a target index — the last one for
-- | -1 — if there is one.
landedColumn :: Array Column -> Int -> Maybe Column
landedColumn columns index = if index < 0 then last columns else columns !! index

-- | The pose the panel's morph starts from: the name bar's rect, as a
-- | scale of the viewport it will fill.
poseFrom :: Rect -> { width :: Number, height :: Number } -> PanelPose
poseFrom rect view =
  { opacity: 1.0
  , x: rect.left
  , y: rect.top
  , scaleX: rect.width / view.width
  , scaleY: rect.height / view.height
  }

-- | Whether the spot names this period — never, when there is no spot.
sameSpot :: Nullable Spot -> Spot -> Boolean
sameSpot spot period = toMaybe spot == Just (spotOf period)

-- | The year a route's `?year=` names: a whole number above zero, read the
-- | way JavaScript's `Number` reads it. Anything else names no year, and
-- | the sweep runs to the end of the rail.
landingYear :: String -> Maybe Int
landingYear raw = toMaybe (wholeNumberImpl raw) >>= \year ->
  if year > 0 then Just year else Nothing

yearDocOf :: TimelineDoc -> YearDoc
yearDocOf page = { year: docYearImpl page, nodes: docNodesImpl page }

-- | A year's column as the template lays it out: the column itself, with
-- | the year's page when it has one.
type YearRow =
  { year :: Int
  , filled :: Boolean
  , width :: Number
  , span :: Number
  -- | The year's page, rendered in the column; null for an empty year.
  , doc :: Nullable TimelineDoc
  }

rowsFor :: Array TimelineDoc -> Array Column -> Array YearRow
rowsFor pages = map \column ->
  { year: column.year
  , filled: column.filled
  , width: column.width
  , span: column.span
  , doc: toNullable (pageFor column.year)
  }
  where
  pageFor year = findLastIndex (\page -> docYearImpl page == year) pages >>= (pages !! _)

-- | What the timeline hands the periods in its columns, through
-- | `YearSpans` (under `"timeline-controls"`): the heat a hover or focus
-- | reports, the pick a tap makes, and which periods fold to a headline.
type PeriodControls =
  { -- | The pointer or focus came onto this period.
    warm :: EffectFn1 Spot Unit
  -- | And left it.
  , cool :: Effect Unit
  -- | Spotlights the period, or lets it go when it already is.
  , pick :: EffectFn1 Spot Unit
  -- | The keys of the periods with more than a headline.
  , folded :: Computed (Array String)
  -- | The key of the period a resting pointer holds open, if any.
  , rested :: Computed (Nullable String)
  -- | The pointer moved over a period, here: open it once it rests there.
  , peek :: EffectFn2 Spot Pointer Unit
  }

-- | What the rail hands a period that folds to its headline, through
-- | `YearSpans` (under `"timeline-fold"`).
type Folding =
  { folded :: Computed (Array String)
  , rested :: Computed (Nullable String)
  , peek :: EffectFn2 Spot Pointer Unit
  }

-- | Where the pointer is on the page, in px.
type Pointer = { x :: Number, y :: Number }

-- | How long the pointer rests on a folded period before it opens, in ms:
-- | long enough that sweeping across the rail opens nothing on the way.
hoverIntentMs :: Int
hoverIntentMs = 140

-- | How far the pointer must move from where it opened a period before
-- | resting on another can take over, in px: a nudge while reading does
-- | not swap the open period for whatever slid under the pointer.
hoverSlop :: Number
hoverSlop = 12.0

-- | What a pointer moving over a folded period does to the one open by
-- | hover.
data HoverStep
  -- | Nothing: already resting there, or not moved far enough to count.
  = Ignore
  -- | Back on the open period: whatever else it was resting toward, drop.
  | Settle
  -- | Start resting on this period, to open it in place of the open one.
  | Rest

derive instance Eq HoverStep

instance Show HoverStep where
  show Ignore = "Ignore"
  show Settle = "Settle"
  show Rest = "Rest"

-- | Decides a pointer move over the period keyed `key`, at `at`, given the
-- | period open by hover, the one the pointer is resting toward, and where
-- | the pointer stood when the open one opened. Only a move makes the call,
-- | and never a layout shift sliding periods under a still pointer, so the
-- | open period is always the one the pointer last came to rest on.
hoverStep
  :: { rested :: Maybe String, candidate :: Maybe String, anchor :: Maybe Pointer }
  -> String
  -> Pointer
  -> HoverStep
hoverStep state key at
  | state.rested == Just key = Settle
  | maybe false (\from -> pointerTravel from at < hoverSlop) state.anchor = Ignore
  | state.candidate == Just key = Ignore
  | otherwise = Rest

pointerTravel :: Pointer -> Pointer -> Number
pointerTravel from to = sqrt ((to.x - from.x) * (to.x - from.x) + (to.y - from.y) * (to.y - from.y))

type TimelineArgs =
  { -- | Reads the years' pages, as the content query returns them.
    docs :: Effect (Array TimelineDoc)
  -- | The current route: `?year=` names the year to land on, and
  -- | `?period=` alongside it the period to light.
  , route :: RouteHandle
  -- | The router, for leaving the timeline.
  , router :: RouterHandle
  -- | Reads the name bar's rect the panel grows out of; null when the
  -- | timeline was opened any other way.
  , origin :: Effect (Nullable Rect)
  -- | Template ref to the page root, where focus rests on open.
  , root :: Ref (Nullable DomElement)
  -- | Template ref to the wide-viewport rail section.
  , rail :: Ref (Nullable DomElement)
  -- | Template ref to the narrow-viewport scroller.
  , column :: Ref (Nullable DomElement)
  -- | The color toggle (`useColorToggle`) the footer's light switch flips.
  -- | Handed in rather than called here: its FFI reaches Nuxt's `#imports`,
  -- | which would keep this module out of the bun-run unit tests.
  , colorToggle :: { isDark :: Computed Boolean, toggle :: Effect Unit }
  }

type TimelineBindings =
  { -- | Every year on the rail, filled and empty alike.
    columns :: Computed (Array Column)
  -- | Every year with its page, for the template to lay out.
  , rows :: Computed (Array YearRow)
  -- | Every period as a run, longest first — the vertical column's marks.
  , runs :: Computed (Array Run)
  -- | Every period's span on the rail.
  , spans :: Computed (Array RailSpan)
  -- | The period under the pointer or focus on the rail, if any.
  , hot :: Ref (Nullable Spot)
  -- | The pointer or focus came onto a period, in its column or its span.
  , warm :: EffectFn1 Spot Unit
  -- | And left it.
  , cool :: Effect Unit
  -- | The period in the spotlight: the one the route asked for until the
  -- | reader picks another.
  , picked :: Computed (Nullable Spot)
  -- | Spotlights the period, or lets it go when it already is.
  , pick :: EffectFn1 Spot Unit
  -- | Spotlights the period and scrolls the column to it.
  , reveal :: EffectFn1 Spot Unit
  -- | The pointer left a year's text on the rail: the period it held open
  -- | there folds again.
  , leave :: Effect Unit
  -- | The skip link: focus moves to the year the timeline landed on.
  , skip :: Effect Unit
  -- | Whether a spot names this period — how the template lights a span
  -- | or a mark that is hot or spotlit.
  , isSpot :: Fn2 (Nullable Spot) Spot Boolean
  -- | Leaves the timeline route: back to whatever opened it when history
  -- | has that, otherwise home. What the close button and Escape do.
  , hide :: Effect Unit
  -- | True when the panel grows out of the name bar's rect; false when it
  -- | rises in with its CSS animation instead.
  , morph :: Computed Boolean
  -- | The pose the morph starts from: the bar's rect, as a scale of the
  -- | viewport. Only read while `morph` holds.
  , panelFrom :: Computed PanelPose
  -- | The pose the morph lands on.
  , panelTo :: PanelPose
  -- | The spring the morph runs on.
  , panelMove :: PanelSpring
  -- | Whether the panel's text is shown; held back while the morph runs.
  , contentVisible :: Ref Boolean
  -- | Whether the applied color mode is dark.
  , isDark :: Computed Boolean
  -- | Flips the persisted color preference between light and dark.
  , toggleColor :: Effect Unit
  -- | The light switch's label, for the mode it switches to.
  , themeAria :: Computed String
  -- | The light switch's icon, for the mode it switches to.
  , themeIcon :: Computed String
  }

-- | Wires the timeline page: the year columns, the periods' runs and spans, the
-- | spotlit and hovered periods, scroll-lock, Escape, and letting go of a
-- | selection on a press away from the text, for as long as it is mounted, and the sweep that runs once the years have painted —
-- | landing on the requested year, and following the route if the year
-- | arrives late. Both layouts are started; the one this size does not
-- | render hands back idle controls. Crossing the breakpoint restarts both
-- | at rest, and so does the set of years changing — the pages can arrive
-- | after mount, and the first time they do, the sweep plays then.
-- |
-- | Opened from the name bar, the slab grows out of the bar's rect. Opened
-- | any other way it rises in with a CSS animation, which the
-- | server-rendered page plays before hydration instead of sitting
-- | invisible until motion-v runs. Its text is visibly squashed mid-morph,
-- | so it waits for the slab to land; with no bar to grow from there is no
-- | morph to wait out.
-- |
-- | The spotlit and hot periods are provided to every period below, and
-- | the controls to each column's `YearSpans`, which hands them on. The
-- | footer's light switch flips the color mode.
setup :: TimelineArgs -> Effect TimelineBindings
setup args = do
  let colorToggle = args.colorToggle
  themeAria <- computed (themeAriaFor <$> read colorToggle.isDark)
  themeIcon <- computed (themeIconFor <$> read colorToggle.isDark)
  landOn <- computed do
    raw <- runEffectFn2 queryFirstImpl args.route "year"
    pure (toNullable (landingYear raw))
  periods <- computed (periodsOf <<< map yearDocOf <$> args.docs)
  focusOn <- computed do
    raw <- runEffectFn2 queryFirstImpl args.route "period"
    year <- read landOn
    requestedSpot year raw <$> read periods
  columns <- computed (columnsFor <<< map docYearImpl <$> args.docs)
  runs <- computed (runsOf <$> read periods)
  folded <- computed (foldedKeys <<< map yearDocOf <$> args.docs)
  spans <- computed (railSpans <$> read columns <*> read runs)
  rows <- computed (rowsFor <$> args.docs <*> read columns)
  -- Follows the route until the reader picks, so the server render — which
  -- reads the pages only after setup — lights the same period the client does.
  chosen <- shallowRef (Nullable.null :: Nullable Spot)
  chose <- shallowRef false
  picked <- computed do
    own <- read chose
    if own then read chosen else read focusOn
  hot <- shallowRef (Nullable.null :: Nullable Spot)
  rested <- shallowRef (Nullable.null :: Nullable String)
  restedKey <- computed (read rested)
  intent <- Ref.new (Nothing :: Maybe TimeoutId)
  candidate <- Ref.new (Nothing :: Maybe String)
  anchor <- Ref.new (Nothing :: Maybe Pointer)
  lastAt <- Ref.new ({ x: 0.0, y: 0.0 } :: Pointer)
  narrow <- runEffectFn1 useMediaQueryImpl narrowQuery
  reduceMotion <- runEffectFn1 useMediaQueryImpl reducedQuery
  opened <- args.origin
  contentVisible <- ref (isNothing (toMaybe opened))
  running <- Ref.new ([] :: Array Running)
  release <- Ref.new ([] :: Array (Effect Unit))
  swept <- Ref.new false

  morph <- computed do
    origin <- args.origin
    case toMaybe origin of
      Just _ -> not <$> read reduceMotion
      Nothing -> pure false

  panelFrom <- computed do
    origin <- args.origin
    case toMaybe origin of
      Just rect -> poseFrom rect <$> viewportImpl
      Nothing -> pure panelTo

  let
    target = targetIndex <$> read columns <*> read landOn

    stopAll = do
      started <- Ref.read running
      Ref.write [] running
      traverse_ _.stop started

    start sweep = runEffectFn1 nextTickImpl do
      years <- read columns
      unless (null years) (Ref.write true swept)
      reduced <- prefersReducedMotionImpl
      let kernel = kernelFor sweep reduced target
      wide <- read args.rail >>= toMaybe >>> traverse \section -> runEffectFn2 startRailImpl section
        kernel
      tall <- read args.column >>= toMaybe >>> traverse \scroller -> runEffectFn2 startColumnImpl
        scroller
        kernel
      Ref.write (maybe [] pure wide <> maybe [] pure tall) running

    warm = mkEffectFn1 \period -> write hot (notNull (spotOf period))

    cool = write hot Nullable.null

    stopIntent = do
      Ref.read intent >>= traverse_ clearTimeout
      Ref.write Nothing intent
      Ref.write Nothing candidate

    clickedOpen = do
      own <- read chose
      (own && _) <<< isJust <<< toMaybe <$> read chosen

    peek = mkEffectFn2 \period at -> do
      Ref.write at lastAt
      let key = spotKey (spotOf period)
      state <- { rested: _, candidate: _, anchor: _ }
        <$> (toMaybe <$> read rested)
        <*> Ref.read candidate
        <*> Ref.read anchor
      case hoverStep state key at of
        Ignore -> pure unit
        Settle -> stopIntent
        Rest -> do
          stopIntent
          clicked <- clickedOpen
          unless clicked do
            Ref.write (Just key) candidate
            pending <- setTimeout hoverIntentMs do
              Ref.write Nothing intent
              Ref.write Nothing candidate
              still <- clickedOpen
              unless still do
                Ref.read lastAt >>= \stood -> Ref.write (Just stood) anchor
                write rested (notNull key)
            Ref.write (Just pending) intent

    leave = do
      stopIntent
      Ref.write Nothing anchor
      write rested Nullable.null

    pick = mkEffectFn1 \period -> do
      current <- read picked
      write chosen (togglePick current period)
      write chose true
      open <- read rested
      when (toMaybe open == Just (spotKey (spotOf period))) (write rested Nullable.null)

    -- End a running sweep first, or its next frame overwrites this scroll.
    reveal = mkEffectFn1 \period -> do
      Ref.read running >>= traverse_ _.interrupt
      write chosen (notNull (spotOf period))
      write chose true
      reduced <- prefersReducedMotionImpl
      read args.column >>= toMaybe >>> traverse_ \scroller ->
        runEffectFn3 revealPeriodImpl scroller (spotKey (spotOf period)) reduced

    skip = do
      index <- target
      landed <- flip landedColumn index <$> read columns
      root <- toMaybe <$> read args.root
      case root, landed of
        Just element, Just column -> runEffectFn2 focusYearImpl element column.year
        _, _ -> pure unit

    hide = do
      back <- cameFromImpl
      if back then runEffectFn1 routerBackImpl args.router
      else runEffectFn2 routerPushImpl args.router "/"

  _ <- watchGetter (read focusOn) \_ _ -> write chose false
  _ <- watchGetter (read picked) \_ _ -> runEffectFn1 nextTickImpl do
    reduced <- read reduceMotion
    read args.rail >>= toMaybe >>> traverse_ \section ->
      runEffectFn2 revealOpenImpl section reduced
  _ <- watchGetter (read landOn) \_ _ -> Ref.read running >>= traverse_ _.retarget
  _ <- watchRef narrow \_ -> stopAll *> start false
  _ <- watchGetter (map _.year <$> read columns) \_ _ -> do
    played <- Ref.read swept
    stopAll *> start (not played)

  onMounted do
    unlock <- lockScrollImpl
    unbind <- runEffectFn1 onEscapeImpl hide
    away <- read args.root >>= toMaybe >>> maybe (pure (pure unit)) (runEffectFn1 onPressAwayImpl)
    Ref.write [ unlock, unbind, away ] release
    read args.root >>= toMaybe >>> traverse_ (runEffectFn1 focusQuietlyImpl)
    start true

  onUnmounted do
    stopIntent
    stopAll
    pending <- Ref.read release
    Ref.write [] release
    traverse_ identity pending

  provide "timeline-focus" picked
  provide "timeline-hot" hot
  provide "timeline-controls"
    ({ warm, cool, pick, folded, rested: restedKey, peek } :: PeriodControls)

  onMounted do
    shown <- read contentVisible
    unless shown do
      reduced <- read reduceMotion
      void (setTimeout (if reduced then 0 else contentHoldMs) (write contentVisible true))

  pure
    { columns
    , rows
    , runs
    , spans
    , hot
    , warm
    , cool
    , picked
    , pick
    , reveal
    , leave
    , skip
    , isSpot: mkFn2 sameSpot
    , hide
    , morph
    , panelFrom
    , panelTo
    , panelMove
    , contentVisible
    , isDark: colorToggle.isDark
    , toggleColor: colorToggle.toggle
    , themeAria
    , themeIcon
    }
