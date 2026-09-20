-- | ## Timeline
-- |
-- | The setup composable behind `Timeline.vue`: the year columns the rail
-- | draws, the eased sweep that opens on the earliest year and lands on the
-- | latest, and the numeric policy the rail kernel calls back into once per
-- | frame. The SFC keeps the content query, the template refs, and one call
-- | here; the DOM listeners and per-frame writes live behind the FFI edge.
-- |
-- | The sweep is deliberately non-linear. `smoothstep` alone would race past
-- | the sparse early years, so progress is raised to an exponent solved so
-- | that the first `headSpan` columns take `introHold` of the run: the view
-- | lingers where the story starts, then accelerates through the years that
-- | carry weight.
module App.Components.Timeline
  ( Column
  , DomElement
  , FadeInput
  , RailKernel
  , TimelineArgs
  , TimelineBindings
  , Tuning
  , columnsFor
  , decayVelocity
  , introDelays
  , introExponent
  , introProgress
  , markerOpacity
  , setup
  ) where

import Prelude

import Data.Array (elem, init, length, mapWithIndex, range, scanl, singleton, take, (!!), (:))
import Data.Foldable (maximum, minimum, sum, traverse_)
import Data.Function.Uncurried (Fn1, Fn2, mkFn1, mkFn2)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Nullable (Nullable, toMaybe)
import Data.Number (asin, log, pow, sin)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import Vue (Computed, Ref, computed, onMounted, onUnmounted, read, ref, write)

-- | An `HTMLElement` — opaque here; only the FFI touches it. @ts HTMLElement
foreign import data DomElement :: Type

-- | Installs the horizontal rail: wheel, drag, and keyboard listeners plus
-- | the per-frame transform and opacity writes, driven by the kernel's
-- | callbacks. A no-op teardown comes back when the element is not the
-- | layout in play at this width.
foreign import startRailImpl :: EffectFn2 DomElement RailKernel (Effect Unit)

-- | Installs the narrow-viewport sweep: scrolls its own container from the
-- | first year to the last while entries fade in. Returns the teardown.
foreign import startColumnImpl :: EffectFn2 DomElement RailKernel (Effect Unit)

-- | Locks document scrolling while the overlay is up; returns the unlock.
foreign import lockScrollImpl :: Effect (Effect Unit)

-- | Adds a window `keydown` listener for Escape; returns the remove thunk.
foreign import onEscapeImpl :: EffectFn1 (Effect Unit) (Effect Unit)

-- | Whether the viewer asked for reduced motion. SSR counts as reduced, so
-- | server-rendered markup never animates (`@/ffi/reduced-motion`).
foreign import prefersReducedMotionImpl :: Effect Boolean

-- | Vue's `nextTick` with a callback, result discarded.
foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit

-- | Total sweep duration in ms, and the fraction of it spent on the first
-- | `headSpan` columns.
railMs :: Number
railMs = 1900.0

introHold :: Number
introHold = 0.32

headSpan :: Int
headSpan = 5

-- | Rail geometry in px: a year with entries is wide enough to set prose at
-- | the reading measure; a year without one is a bare tick. The last column
-- | carries extra padding so the sweep does not end flush against the edge.
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
-- | sweep reach this column?", which is what a column's fade-in waits on.
smoothstepInv :: Number -> Number
smoothstepInv y = 0.5 - sin (asin (1.0 - 2.0 * clamp 0.0 1.0 y) / 3.0)

-- | The exponent that spends `introHold` of the run on the first `headSpan`
-- | columns: solve `smoothstep(introHold) ^ e = head / total` for `e`. Falls
-- | back to a plausible curve when the rail is degenerate — empty, or with
-- | all of its width inside the head.
introExponent :: Array Number -> Number
introExponent sizes =
  let
    total = sum sizes
    share = if total <= 0.0 then 0.0 else sum (take headSpan sizes) / total
    gate = smoothstep introHold
  in
    if share <= 0.0 || gate <= 0.0 || gate >= 1.0 then 2.6
    else log share / log gate

-- | How far through the rail the sweep has travelled, 0 to 1, after
-- | `elapsed` ms.
introProgress :: Array Number -> Number -> Number
introProgress sizes elapsed =
  clamp 0.0 1.0 (pow (smoothstep (elapsed / railMs)) (introExponent sizes))

-- | The cumulative extent before each column — where along the rail it
-- | starts.
offsets :: Array Number -> Array Number
offsets sizes = 0.0 : fromMaybe [] (init (scanl (+) 0.0 sizes))

-- | When the sweep arrives at each column, in ms. A column's fade-in runs at
-- | this delay, so it resolves exactly as the rail reaches it instead of on
-- | a stagger that drifts out of step with the motion.
introDelays :: Array Number -> Array Number
introDelays sizes =
  let
    total = sum sizes
    exponent = introExponent sizes
    arrival at =
      if total <= 0.0 || exponent <= 0.0 then 0.0
      else railMs * smoothstepInv (pow (at / total) (1.0 / exponent))
  in
    map arrival (offsets sizes)

type Column =
  { -- | The calendar year this column marks.
    year :: Int
  -- | True when the year has an entry to show; empty years are bare ticks.
  , filled :: Boolean
  -- | Column width on the rail, in px.
  , width :: Number
  -- | `animation-delay` for this column's fade-in, in ms.
  , delay :: Number
  }

-- | Every year from the earliest entry to the latest, gaps included — the
-- | empty stretches are the point, since they show the shape of a life
-- | rather than a list of jobs. Widths and fade delays come along, since
-- | both follow from the same filled/empty split.
columnsFor :: Array Int -> Array Column
columnsFor years = case minimum years, maximum years of
  Just first, Just final -> build (range first final)
  _, _ -> []
  where
  build span =
    let
      count = length span
      sized index year =
        (if elem year years then filledWidth else emptyWidth)
          + (if index == count - 1 then tailPad else 0.0)
      widths = mapWithIndex sized span
      delays = introDelays widths
      column index year =
        { year
        , filled: elem year years
        , width: fromMaybe emptyWidth (widths !! index)
        , delay: fromMaybe 0.0 (delays !! index)
        }
    in
      mapWithIndex column span

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
  { -- | Total sweep duration in ms.
    railMs :: Number
  -- | How long the sweep holds at the end before handing back control.
  , settleMs :: Number
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
  -- | Where the year labels pin once the track scrolls under them, in px.
  , pinInset :: Number
  -- | Fraction of the rail an arrow key moves.
  , keyStep :: Number
  }

-- | The rail's feel, in one place: every constant the kernel reads.
tuning :: Tuning
tuning =
  { railMs
  , settleMs: 500.0
  , wheelGain: 1.4
  , dragGain: 1.0
  , touchGain: 1.15
  , flingFloor: 0.08
  , stopFloor: 0.025
  , axisSlop: 8.0
  , pinInset: 20.0
  , keyStep: 0.05
  }

type RailKernel =
  { -- | Per-column fade delays for the measured column extents.
    delays :: Fn1 (Array Number) (Array Number)
  -- | Sweep progress (0 to 1) for those extents at `elapsed` ms.
  , progress :: Fn2 (Array Number) Number Number
  -- | A column's opacity for its current position on the rail.
  , opacity :: Fn1 FadeInput Number
  -- | Fling velocity after a frame of the given length.
  , decay :: Fn2 Number Number Number
  -- | Clamp a scroll offset into [0, limit].
  , clampTo :: Fn2 Number Number Number
  -- | True when the sweep should be skipped and the rail opened at rest on
  -- | the latest year.
  , reduced :: Boolean
  -- | Every constant the rail's feel depends on.
  , tuning :: Tuning
  }

-- | The pure policy the FFI kernel calls back into — no DOM and no state,
-- | just the arithmetic deciding where the rail sits and how bright each
-- | column is.
kernelFor :: Boolean -> RailKernel
kernelFor reduced =
  { delays: mkFn1 introDelays
  , progress: mkFn2 introProgress
  , opacity: mkFn1 markerOpacity
  , decay: mkFn2 decayVelocity
  , clampTo: mkFn2 \limit value -> clamp 0.0 limit value
  , reduced
  , tuning
  }

type TimelineArgs =
  { -- | Reads the years that have entries, in any order.
    years :: Effect (Array Int)
  -- | Template ref to the wide-viewport rail section.
  , rail :: Ref (Nullable DomElement)
  -- | Template ref to the narrow-viewport scroller.
  , column :: Ref (Nullable DomElement)
  }

type TimelineBindings =
  { -- | Whether the overlay is showing.
    open :: Ref Boolean
  -- | True once mounted on the client — gates the teleported overlay so SSR
  -- | markup never contains it.
  , mounted :: Ref Boolean
  -- | Every year on the rail, filled and empty alike.
  , columns :: Computed (Array Column)
  -- | Opens the overlay and starts the sweep.
  , show :: Effect Unit
  -- | Closes the overlay and tears the sweep down.
  , hide :: Effect Unit
  }

-- | Wires the timeline overlay: the year columns, open/close state with
-- | Escape and scroll-lock, and the sweep that runs once the overlay has
-- | painted. Both layouts are started; whichever one this width does not
-- | render hands back a no-op teardown, so a breakpoint crossed while the
-- | overlay is open still has a live kernel waiting on the other side.
setup :: TimelineArgs -> Effect TimelineBindings
setup args = do
  open <- ref false
  mounted <- ref false
  columns <- computed (columnsFor <$> args.years)
  running <- Ref.new ([] :: Array (Effect Unit))
  release <- Ref.new ([] :: Array (Effect Unit))

  onMounted (write mounted true)

  let
    runAll cell = do
      pending <- Ref.read cell
      Ref.write [] cell
      traverse_ identity pending

    startSweep = runEffectFn1 nextTickImpl do
      kernel <- kernelFor <$> prefersReducedMotionImpl
      wide <- toMaybe <$> read args.rail
      narrow <- toMaybe <$> read args.column
      rail <- case wide of
        Just section -> singleton <$> runEffectFn2 startRailImpl section kernel
        Nothing -> pure []
      stack <- case narrow of
        Just scroller -> singleton <$> runEffectFn2 startColumnImpl scroller kernel
        Nothing -> pure []
      Ref.write (rail <> stack) running

    hide = whenM (read open) do
      write open false
      runAll running
      runAll release

    show = unlessM (read open) do
      write open true
      unlock <- lockScrollImpl
      unbind <- runEffectFn1 onEscapeImpl hide
      Ref.write [ unlock, unbind ] release
      startSweep

  onUnmounted (runAll running *> runAll release)

  pure { open, mounted, columns, show, hide }
