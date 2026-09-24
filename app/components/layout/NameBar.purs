-- | ## NameBar
-- |
-- | The setup composable behind `NameBar.vue`: the slab across the top of
-- | a page that opens the timeline. Under a fine pointer it leans a little
-- | toward wherever the pointer rests; pressed, it hands the timeline store
-- | its rect and the scroll it was clicked at so the panel can grow out of
-- | it; when the panel docks back it takes the landing with a quick squash
-- | and gets focus back — quietly. While a bio target previews a year the
-- | bar answers with it in its location slot. The SFC keeps the prop
-- | macro, the template ref, the route, router and store handles, plus one
-- | call here.
module App.Components.NameBar
  ( BarInstance
  , Drift
  , MouseEvt
  , NameBarArgs
  , NameBarBindings
  , Pose
  , Press
  , Rect
  , Spring
  , Squash
  , driftToward
  , setup
  , squash
  , squashMs
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Timer (setTimeout)
import Effect.Uncurried (EffectFn1, EffectFn3, mkEffectFn1, runEffectFn1, runEffectFn3)
import Vue (Computed, Ref, computed, read, ref, watchGetter, write)

-- | The bar's `<Motion>` component instance, as its template ref holds
-- | it. @ts import("vue").ComponentPublicInstance
foreign import data BarInstance :: Type

-- | An `HTMLElement` — opaque here; only the FFI touches it. @ts HTMLElement
foreign import data DomElement :: Type

-- | A raw `MouseEvent`. @ts MouseEvent
foreign import data MouseEvt :: Type

-- | A `MediaQueryList`, live: it answers for the viewport as it is now.
-- | @ts MediaQueryList
foreign import data MediaQuery :: Type

-- | A pose for motion-v's `:animate`. @ts import("motion-v").Options["animate"]
foreign import data Pose :: Type

-- | motion-v's live reduced-motion preference: false on the server, then
-- | the viewer's `prefers-reduced-motion`. @ts import("vue").Ref<boolean>
foreign import data ReducedMotion :: Type

-- | A composable, so it must run in setup.
foreign import useReducedMotionImpl :: Effect ReducedMotion

foreign import reducedNowImpl :: EffectFn1 ReducedMotion Boolean

foreign import barElementImpl :: EffectFn1 (Nullable BarInstance) (Nullable DomElement)

foreign import focusQuietlyImpl :: EffectFn1 DomElement Unit

foreign import matchMediaImpl :: EffectFn1 String MediaQuery

foreign import mediaMatchesImpl :: EffectFn1 MediaQuery Boolean

foreign import targetRectImpl :: EffectFn1 MouseEvt Rect

foreign import clientPointImpl :: EffectFn1 MouseEvt { x :: Number, y :: Number }

foreign import scrollYImpl :: Effect Number

foreign import driftPoseImpl :: Drift -> Pose

foreign import squashPoseImpl :: Squash -> Pose

-- | A viewport rect, as `getBoundingClientRect` reports it — the shape of
-- | the timeline store's `Rect`, spelled out here so the generated
-- | declaration can name it: a synonym from another module comes out as
-- | `unknown`, which the store's `begin` would not take.
type Rect = { left :: Number, top :: Number, width :: Number, height :: Number }

-- | How far the bar has leaned toward the pointer, in px.
type Drift = { x :: Number, y :: Number }

-- | The pose the bar is pressed into.
type Press = { scale :: Number }

-- | A motion-v spring transition.
type Spring =
  { "type" :: String
  , stiffness :: Number
  , damping :: Number
  , mass :: Number
  }

-- | A keyframed squash-and-release, with its own timing.
type Squash =
  { x :: Number
  , y :: Number
  , scaleX :: Array Number
  , scaleY :: Array Number
  , transition :: { duration :: Number, times :: Array Number, ease :: String }
  }

-- | Hover motion is translation only: scaling the wide slab shimmers its text.
pressed :: Press
pressed = { scale: 0.996 }

spring :: Spring
spring = { "type": "spring", stiffness: 300.0, damping: 24.0, mass: 0.6 }

-- | The docking slab's impact: squashed flat and released as the timeline
-- | lands back in the bar. It sets the bar square, dropping any drift.
squash :: Squash
squash =
  { x: 0.0
  , y: 0.0
  , scaleX: [ 1.0, 0.985, 1.0 ]
  , scaleY: [ 1.0, 0.94, 1.0 ]
  , transition: { duration: 0.3, times: [ 0.0, 0.35, 1.0 ], ease: "easeOut" }
  }

-- | How long the squash holds the bar's pose, in ms — just past its
-- | 0.3 s run.
squashMs :: Int
squashMs = 320

finePointerQuery :: String
finePointerQuery = "(min-width: 901px) and (hover: hover)"

driftX :: Number
driftX = 10.0

driftY :: Number
driftY = 6.0

still :: Drift
still = { x: 0.0, y: 0.0 }

-- | How far the bar leans toward a pointer at `point` over a slab at
-- | `rect`: nothing at the slab's center, half of `driftX`/`driftY` at
-- | its edges, in the pointer's direction.
driftToward :: Rect -> { x :: Number, y :: Number } -> Drift
driftToward rect point =
  { x: ((point.x - rect.left) / rect.width - 0.5) * driftX
  , y: ((point.y - rect.top) / rect.height - 0.5) * driftY
  }

timelinePath :: String
timelinePath = "/timeline"

type NameBarArgs =
  { -- | Template ref to the bar's `<Motion>` component.
    bar :: Ref (Nullable BarInstance)
  -- | Reads the current route's path.
  , path :: Effect String
  -- | Reads the store's landing count, bumped each time the panel docks
  -- | back into the bar.
  , landings :: Effect Int
  -- | Reads the year a bio target is previewing, if any.
  , focusYear :: Effect (Nullable Int)
  -- | The store's `begin`: the rect the panel grows from, the scroll the
  -- | bar was clicked at, and the route it sits on.
  , begin :: EffectFn3 Rect Number String Unit
  -- | Navigate to the timeline.
  , navigate :: Effect Unit
  }

type NameBarBindings =
  { -- | The `:while-press` pose.
    pressed :: Press
  -- | The `:transition` the bar's moves ride.
  , spring :: Spring
  -- | The bar's `:animate` pose: the landing squash while it plays,
  -- | otherwise the drift toward the pointer.
  , barPose :: Computed Pose
  -- | Whether the timeline is up, so the bar steps out of sight beneath it.
  , showing :: Computed Boolean
  -- | Focus came home with a landing: the ring and the hover cue wait
  -- | until focus moves on.
  , quiet :: Ref Boolean
  -- | The year a bio target is previewing, shown in place of the location.
  , answer :: Computed (Nullable Int)
  -- | The pointer moved over the bar: lean toward it.
  , onDrift :: EffectFn1 MouseEvt Unit
  -- | The pointer left: settle back.
  , onDriftEnd :: Effect Unit
  -- | The bar lost focus: a quiet focus is over.
  , onBlur :: Effect Unit
  -- | The bar was pressed: hand the store where the panel grows from, then
  -- | go to the timeline.
  , openTimeline :: EffectFn1 MouseEvt Unit
  }

-- | Wires the name bar: the drift toward a fine pointer, the squash and
-- | quiet focus return when the timeline docks — the drift and the squash
-- | held back when the viewer asks for reduced motion — and the press that
-- | opens the timeline out of the bar's own rect.
setup :: NameBarArgs -> Effect NameBarBindings
setup args = do
  reducedMotion <- useReducedMotionImpl
  drift <- ref still
  pulse <- ref false
  quiet <- ref false
  pointerQuery <- Ref.new (Nothing :: Maybe MediaQuery)

  let
    -- Asked on first drift, not in setup: setup also runs on the server.
    finePointer = do
      cached <- Ref.read pointerQuery
      query <- case cached of
        Just query -> pure query
        Nothing -> do
          query <- runEffectFn1 matchMediaImpl finePointerQuery
          Ref.write (Just query) pointerQuery
          pure query
      runEffectFn1 mediaMatchesImpl query

    onDrift = mkEffectFn1 \event -> do
      reduced <- runEffectFn1 reducedNowImpl reducedMotion
      unless reduced do
        fine <- finePointer
        when fine do
          rect <- runEffectFn1 targetRectImpl event
          point <- runEffectFn1 clientPointImpl event
          write drift (driftToward rect point)

    openTimeline = mkEffectFn1 \event -> do
      rect <- runEffectFn1 targetRectImpl event
      scroll <- scrollYImpl
      path <- args.path
      runEffectFn3 args.begin rect scroll path
      args.navigate

  void $ watchGetter args.landings \_ _ -> do
    element <- runEffectFn1 barElementImpl =<< read args.bar
    case toMaybe element of
      Just el -> do
        write quiet true
        runEffectFn1 focusQuietlyImpl el
      Nothing -> pure unit
    reduced <- runEffectFn1 reducedNowImpl reducedMotion
    unless reduced do
      write pulse true
      void $ setTimeout squashMs (write pulse false)

  barPose <- computed do
    pulsing <- read pulse
    if pulsing then pure (squashPoseImpl squash)
    else driftPoseImpl <$> read drift

  showing <- computed ((_ == timelinePath) <$> args.path)
  answer <- computed args.focusYear

  pure
    { pressed
    , spring
    , barPose
    , showing
    , quiet
    , answer
    , onDrift
    , onDriftEnd: write drift still
    , onBlur: write quiet false
    , openTimeline
    }
