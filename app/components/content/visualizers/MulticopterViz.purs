-- | ## MulticopterViz
-- |
-- | The setup composable behind `MulticopterViz.vue` — a planar two-rotor
-- | craft flown to click waypoints by a cascaded PD controller. The
-- | controller, fixed-step integrator with frame-time accumulator, trail
-- | bookkeeping, and every display string are PureScript; the FFI carries
-- | only the SVG click-to-point transform and the frame loop.
module App.Components.MulticopterViz
  ( Arrow
  , GravityArrow
  , MouseEvt
  , MulticopterBindings
  , Point
  , State
  , controlForces
  , craftBlownUp
  , craftHome
  , craftToStage
  , craftTransformOf
  , flightFrameDelta
  , flightNote
  , gravityArrowAt
  , gravityHeadPoints
  , growTrail
  , hoverThrust
  , integrateCraft
  , nudgedCraft
  , thrustArrow
  , thrustArrowLen
  , thrustHeadPoints
  , trailPointsText
  , useMulticopterViz
  , waypointAt
  ) where

import Prelude

import App.Composables.AfterPaint (useAfterPaint)
import Data.Array as Array
import Data.Function.Uncurried (Fn2, mkFn2)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Data.Number (abs, cos, isFinite, max, min, pi, remainder, sin) as Number
import Data.Number.Format (fixed, toString, toStringWith)
import Data.String (joinWith)
import Effect (Effect, whileE)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, mkEffectFn1, runEffectFn1)
import Vue (Computed, Ref, computed, read, ref, write)

-- | A raw `MouseEvent`. @ts MouseEvent
foreign import data MouseEvt :: Type

foreign import clickPointImpl :: EffectFn1 MouseEvt (Nullable { x :: Number, y :: Number })

foreign import rafLoopImpl :: EffectFn1 (EffectFn1 Number Unit) (Effect Unit)

-- | The craft's state in world units (m, m/s, rad, rad/s): position,
-- | velocity, tilt, and spin. Positive tilt banks left.
type State = { x :: Number, y :: Number, vx :: Number, vy :: Number, th :: Number, om :: Number }

-- | A world-space point in m, or a stage point in viewBox px.
type Point = { x :: Number, y :: Number }

-- | One thrust arrow in the craft's frame: the shaft runs from y = -5 up
-- | to `y2` at column `x`, the head polygon caps it, and the force label
-- | sits at (`labelX`, `labelY`).
type Arrow =
  { x :: Number
  , y2 :: Number
  , headPoints :: String
  , labelX :: Number
  , labelY :: Number
  }

-- | The gravity arrow below the center of mass: shaft from `y1` to `y2`
-- | (its x is `comX`), and the "mg" label at (`labelX`, `labelY`).
type GravityArrow =
  { y1 :: Number
  , y2 :: Number
  , labelX :: Number
  , labelY :: Number
  }

type MulticopterBindings =
  { -- | Canvas viewBox width in px.
    "W" :: Number
  -- | Canvas viewBox height in px.
  , "H" :: Number
  -- | Arrowhead length in px, shared by every force arrow.
  , "HEAD" :: Number
  -- | Ground line y in viewBox px.
  , groundPx :: Number
  -- | Rotor-arm half-length in px.
  , armPx :: Number
  -- | Waypoint marker position in viewBox px.
  , targetPx :: Ref { x :: Number, y :: Number }
  -- | Center of mass x in viewBox px (anchors the gravity arrow).
  , comX :: Ref Number
  -- | Center of mass y in viewBox px (anchors the gravity arrow).
  , comY :: Ref Number
  -- | The translate/rotate transform placing the craft group.
  , craftTransform :: Ref String
  -- | Left thrust-arrow length in px, scaled from f1.
  , leftLen :: Ref Number
  -- | Right thrust-arrow length in px, scaled from f2.
  , rightLen :: Ref Number
  -- | The left (f1) thrust arrow's geometry.
  , leftArrow :: Computed Arrow
  -- | The right (f2) thrust arrow's geometry.
  , rightArrow :: Computed Arrow
  -- | The gravity arrow's geometry, following the center of mass.
  , gravityArrow :: Computed GravityArrow
  -- | Left rotor rect x in the craft's frame.
  , rotorLeftX :: Number
  -- | Right rotor rect x in the craft's frame.
  , rotorRightX :: Number
  -- | Polyline `points` of the recent flight path.
  , trailPoints :: Ref String
  -- | Gravity-arrow arrowhead polygon points.
  , gHead :: Ref String
  -- | Thrust arrowhead polygon points, tip at the given (x, y).
  , head :: Fn2 Number Number String
  -- | Status line — direction, tilt, and the two rotor forces.
  , note :: Ref String
  -- | Click handler: set the waypoint from the click position.
  , flyTo :: EffectFn1 MouseEvt Unit
  -- | Kick the craft (alternating side) to show the recovery.
  , nudge :: Effect Unit
  -- | Home the craft and clear the trail.
  , reset :: Effect Unit
  }

w :: Number
w = 640.0

h :: Number
h = 320.0

scale :: Number
scale = 28.0

originX :: Number
originX = w / 2.0

originY :: Number
originY = h * 0.88

armLen :: Number
armLen = 1.15

craftMass :: Number
craftMass = 1.0

gravity :: Number
gravity = 9.81

inertia :: Number
inertia = 0.5

dt :: Number
dt = 1.0 / 120.0

thrustMax :: Number
thrustMax = 18.0

trailCap :: Int
trailCap = 150

homeX :: Number
homeX = 0.0

homeY :: Number
homeY = 2.6

armPx :: Number
armPx = armLen * scale

headLen :: Number
headLen = 7.0

waypointNote :: String
waypointNote = "click anywhere to set a waypoint"

-- | A thrust arrowhead polygon with its tip at (x, y), opening
-- | downward.
thrustHeadPoints :: Number -> Number -> String
thrustHeadPoints x y =
  toString (x - 4.0) <> "," <> toString (y + headLen) <> " "
    <> toString (x + 4.0)
    <> ","
    <> toString (y + headLen)
    <> " "
    <> toString x
    <> ","
    <> toString y

-- | A thrust arrow's geometry at column `x` for a shaft `len` px long,
-- | its label at `labelX`. Each coordinate keeps the operand order of
-- | the template expression it replaced (`-5 - len + HEAD`), so the
-- | floats land bit-identical.
thrustArrow :: Number -> Number -> Number -> Arrow
thrustArrow x len labelX =
  { x
  , y2: (-5.0) - len + headLen
  , headPoints: thrustHeadPoints x ((-5.0) - len)
  , labelX
  , labelY: (-12.0) - len
  }

-- | The gravity arrow's geometry under a center of mass at (comX, comY),
-- | in the template's original operand order.
gravityArrowAt :: Number -> Number -> GravityArrow
gravityArrowAt comX comY =
  { y1: comY + 8.0
  , y2: comY + 34.0 - headLen
  , labelX: comX + 6.0
  , labelY: comY + 32.0
  }

-- | The gravity arrowhead polygon under a center of mass at (cx, cy),
-- | its tip 34px below and opening upward.
gravityHeadPoints :: Number -> Number -> String
gravityHeadPoints cx cy =
  let
    y = cy + 34.0
  in
    toString (cx - 4.0) <> "," <> toString (y - headLen) <> " "
      <> toString (cx + 4.0)
      <> ","
      <> toString (y - headLen)
      <> " "
      <> toString cx
      <> ","
      <> toString y

-- | Each rotor's share of the craft's weight — the hover thrust.
hoverThrust :: Number
hoverThrust = craftMass * gravity / 2.0

-- | At rest at home, level.
craftHome :: State
craftHome = { x: homeX, y: homeY, vx: 0.0, vy: 0.0, th: 0.0, om: 0.0 }

-- | World point (m, y up) → stage point (px, y down).
craftToStage :: Point -> Point
craftToStage p = { x: originX + p.x * scale, y: originY - p.y * scale }

-- | A clicked stage point → the waypoint it sets, clamped inside the
-- | walls and between the floor and the ceiling.
waypointAt :: Point -> Point
waypointAt pt =
  { x: clamp (-10.3) 10.3 ((pt.x - originX) / scale)
  , y: clamp 0.6 9.2 ((originY - pt.y) / scale)
  }

-- | The cascaded PD controller: a horizontal error asks for a bank
-- | (clamped to ±0.5 rad), a vertical error for collective thrust
-- | (divided by the tilt's cosine, floored at 0.3), and the attitude
-- | loop splits the collective into the two rotor forces, each clamped
-- | to [0, 18].
controlForces :: State -> Point -> { f1 :: Number, f2 :: Number }
controlForces st t =
  { f1: Number.max 0.0 (Number.min thrustMax (thrust / 2.0 - delta / 2.0))
  , f2: Number.max 0.0 (Number.min thrustMax (thrust / 2.0 + delta / 2.0))
  }
  where
  axDes = clamp (-6.0) 6.0 (1.6 * (t.x - st.x) - 2.0 * st.vx)
  thDes = clamp (-0.5) 0.5 (-axDes / gravity)
  ayDes = 5.0 * (t.y - st.y) - 3.4 * st.vy
  c = Number.cos st.th
  rawThrust = craftMass * (gravity + ayDes) / (if Number.abs c < 0.3 then 0.3 else c)
  thrust = Number.max 0.0 (Number.min (2.0 * thrustMax) rawThrust)
  tauDes = -20.0 * (st.th - thDes) - 6.3 * st.om
  delta = inertia * tauDes / armLen

-- | One fixed 1/120 s semi-implicit Euler step under the two rotor
-- | forces and gravity; the walls at ±10.8 m and the floor at 0.2 m stop
-- | the craft dead along that axis.
integrateCraft :: { f1 :: Number, f2 :: Number } -> State -> State
integrateCraft { f1: fa, f2: fb } st =
  { x: wallRight.x, y: floorHit.y, vx: wallRight.vx, vy: floorHit.vy, th, om }
  where
  sum = fa + fb
  forceX = sum * (-(Number.sin st.th))
  forceY = sum * Number.cos st.th - craftMass * gravity
  tau = armLen * (fb - fa)
  vx = st.vx + dt * forceX / craftMass
  vy = st.vy + dt * forceY / craftMass
  om = st.om + dt * tau / inertia
  x0 = st.x + dt * vx
  y0 = st.y + dt * vy
  th = st.th + dt * om
  wallLeft = if x0 < -10.8 then { x: -10.8, vx: 0.0 } else { x: x0, vx }
  wallRight = if wallLeft.x > 10.8 then { x: 10.8, vx: 0.0 } else wallLeft
  floorHit = if y0 < 0.2 then { y: 0.2, vy: 0.0 } else { y: y0, vy }

-- | A state the sim cannot recover from: non-finite height or tilt, or
-- | more than 40 rad of accumulated tilt.
craftBlownUp :: State -> Boolean
craftBlownUp st =
  not (Number.isFinite st.y) || not (Number.isFinite st.th) || Number.abs st.th > 40.0

-- | The kick `nudge` applies, toward side `d` (±1): a drop, a sideways
-- | shove, a spin, and a bank.
nudgedCraft :: Number -> State -> State
nudgedCraft d st =
  st { vy = st.vy - 2.6, vx = st.vx + d * 2.2, om = st.om + d * 2.6, th = st.th + d * 0.45 }

-- | The craft group's transform: translate to its stage position and
-- | rotate by its tilt in degrees (clockwise on screen for a right
-- | bank), all to two decimals.
craftTransformOf :: State -> String
craftTransformOf st =
  "translate(" <> toStringWith (fixed 2) c.x <> "," <> toStringWith (fixed 2) c.y
    <> ") rotate("
    <> toStringWith (fixed 2) (-st.th * 180.0 / Number.pi)
    <> ")"
  where
  c = craftToStage { x: st.x, y: st.y }

-- | A thrust arrow's shaft length in px for a rotor force: 3.2 px per
-- | newton, never shorter than the head plus 2px.
thrustArrowLen :: Number -> Number
thrustArrowLen f = Number.max (headLen + 2.0) (f * 3.2)

-- | The trail as polyline `points` in stage px, to one decimal.
trailPointsText :: Array Point -> String
trailPointsText points = joinWith " " $ points <#> \p ->
  toStringWith (fixed 1) (originX + p.x * scale) <> ","
    <> toStringWith (fixed 1) (originY - p.y * scale)

-- | The trail with a new point appended, oldest dropped past 150.
growTrail :: Array Point -> Point -> Array Point
growTrail points p =
  let
    grown = Array.snoc points p
  in
    if Array.length grown > trailCap then Array.drop 1 grown else grown

-- | Seconds to add to the step budget for a frame at `timestamp` (ms)
-- | after one at `previous` (0 before the first frame, which adds
-- | nothing), capped at 0.05.
flightFrameDelta :: Number -> Number -> Number
flightFrameDelta previous timestamp =
  let
    base = if previous == 0.0 then timestamp else previous
  in
    Number.min 0.05 ((timestamp - base) / 1000.0)

-- | The status line: the direction of travel and tilt while more than
-- | 0.15 m off the waypoint on either axis, else holding; both rotor
-- | forces to one decimal.
flightNote :: State -> Point -> Number -> Number -> String
flightNote st t fa fb =
  if Number.abs dx > 0.15 || Number.abs dy > 0.15 then
    dirText <> " · tilt " <> (if deg > 0.0 then "+" else "")
      <> toStringWith (fixed 0) deg
      <> "° · f1="
      <> toStringWith (fixed 1) fa
      <> " f2="
      <> toStringWith (fixed 1) fb
  else
    "holding at waypoint · f1=" <> toStringWith (fixed 1) fa <> " f2="
      <> toStringWith (fixed 1) fb
      <> " — click to fly somewhere else"
  where
  dx = t.x - st.x
  dy = st.y - t.y
  deg = st.th * 180.0 / Number.pi
  dirText =
    if Number.abs dx > 0.15 then (if dx > 0.0 then "flying right" else "flying left")
    else if dy > 0.0 then "easing down"
    else "climbing"

-- | Wires the cascaded PD controller and the fixed-step integrator
-- | (frame-time accumulator, up to 240 substeps per frame), starting
-- | after first paint. Binds the SVG display strings and arrow geometry
-- | the template renders, the click-to-waypoint handler, and nudge/reset
-- | actions.
useMulticopterViz :: Effect MulticopterBindings
useMulticopterViz = do
  s <- Ref.new craftHome
  target <- Ref.new { x: homeX, y: homeY }
  f1 <- Ref.new hoverThrust
  f2 <- Ref.new hoverThrust
  trail <- Ref.new ([] :: Array Point)
  ndir <- Ref.new 1.0
  acc <- Ref.new 0.0
  lastTime <- Ref.new 0.0
  frameCount <- Ref.new 0.0

  note <- ref waypointNote
  targetPx <- ref { x: 0.0, y: 0.0 }
  comX <- ref 0.0
  comY <- ref 0.0
  craftTransform <- ref ""
  leftLen <- ref 0.0
  rightLen <- ref 0.0
  trailPoints <- ref ""
  gHead <- ref ""

  leftArrow <- computed do
    len <- read leftLen
    pure (thrustArrow (-armPx) len ((-armPx) - 6.0))
  rightArrow <- computed do
    len <- read rightLen
    pure (thrustArrow armPx len (armPx + 6.0))
  gravityArrow <- computed (gravityArrowAt <$> read comX <*> read comY)

  let
    syncTarget = do
      t <- Ref.read target
      write targetPx (craftToStage t)

    syncCraft = do
      st <- Ref.read s
      fa <- Ref.read f1
      fb <- Ref.read f2
      let c = craftToStage { x: st.x, y: st.y }
      write comX c.x
      write comY c.y
      write craftTransform (craftTransformOf st)
      write leftLen (thrustArrowLen fa)
      write rightLen (thrustArrowLen fb)
      write gHead (gravityHeadPoints c.x c.y)

    syncTrail = do
      points <- Ref.read trail
      write trailPoints (trailPointsText points)

    reset = do
      Ref.write craftHome s
      Ref.write { x: homeX, y: homeY } target
      Ref.write hoverThrust f1
      Ref.write hoverThrust f2
      Ref.write [] trail
      write note waypointNote
      syncTarget
      syncCraft
      syncTrail

    stepOnce = do
      st <- Ref.read s
      t <- Ref.read target
      let forces = controlForces st t
      Ref.write forces.f1 f1
      Ref.write forces.f2 f2
      let next = integrateCraft forces st
      Ref.write next s
      when (craftBlownUp next) reset

    describe = do
      st <- Ref.read s
      t <- Ref.read target
      fa <- Ref.read f1
      fb <- Ref.read f2
      write note (flightNote st t fa fb)

    flyTo event = do
      point <- toMaybe <$> runEffectFn1 clickPointImpl event
      case point of
        Nothing -> pure unit
        Just pt -> do
          Ref.write (waypointAt pt) target
          write note "waypoint set — banking toward it"
          syncTarget

    nudge = do
      d <- Ref.read ndir
      st <- Ref.read s
      Ref.write (nudgedCraft d st) s
      Ref.write (-d) ndir
      write note "disturbance applied — watch the thrust arrows split"
      syncCraft

    tick timestamp = do
      previous <- Ref.read lastTime
      Ref.modify_ (_ + flightFrameDelta previous timestamp) acc
      Ref.write timestamp lastTime
      stepsDone <- Ref.new 0
      whileE
        ( do
            budget <- Ref.read acc
            n <- Ref.read stepsDone
            pure (budget >= dt && n < 240)
        )
        ( do
            stepOnce
            Ref.modify_ (_ - dt) acc
            Ref.modify_ (_ + 1) stepsDone
        )
      frames <- Ref.modify (_ + 1.0) frameCount
      when (Number.remainder frames 3.0 == 0.0) do
        st <- Ref.read s
        Ref.modify_ (\points -> growTrail points { x: st.x, y: st.y }) trail
        syncTrail
      describe
      syncCraft

  syncTarget
  syncCraft
  syncTrail

  resume <- runEffectFn1 rafLoopImpl (mkEffectFn1 tick)
  useAfterPaint resume

  pure
    { "W": w
    , "H": h
    , "HEAD": headLen
    , groundPx: originY + 0.2 * scale
    , armPx
    , targetPx
    , comX
    , comY
    , craftTransform
    , leftLen
    , rightLen
    , leftArrow
    , rightArrow
    , gravityArrow
    , rotorLeftX: (-armPx) - 8.0
    , rotorRightX: armPx - 8.0
    , trailPoints
    , gHead
    , head: mkFn2 thrustHeadPoints
    , note
    , flyTo: mkEffectFn1 flyTo
    , nudge
    , reset
    }
