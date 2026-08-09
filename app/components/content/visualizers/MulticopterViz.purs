-- | ## MulticopterViz
-- |
-- | The setup composable behind `MulticopterViz.vue` — a planar two-rotor
-- | craft flown to click waypoints by a cascaded PD controller. The
-- | controller, fixed-step integrator with frame-time accumulator, trail
-- | bookkeeping, and every display string are PureScript; the FFI carries
-- | only the SVG click-to-point transform and the frame loop.
module App.Components.MulticopterViz
  ( MouseEvt
  , MulticopterBindings
  , useMulticopterViz
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
import Vue (Ref, ref, write)

-- | A raw `MouseEvent`. @ts MouseEvent
foreign import data MouseEvt :: Type

foreign import clickPointImpl :: EffectFn1 MouseEvt (Nullable { x :: Number, y :: Number })
foreign import rafLoopImpl :: EffectFn1 (EffectFn1 Number Unit) (Effect Unit)

type State = { x :: Number, y :: Number, vx :: Number, vy :: Number, th :: Number, om :: Number }

type MulticopterBindings =
  { "W" :: Number
  , "H" :: Number
  , "HEAD" :: Number
  , groundPx :: Number
  , armPx :: Number
  , targetPx :: Ref { x :: Number, y :: Number }
  , comX :: Ref Number
  , comY :: Ref Number
  , craftTransform :: Ref String
  , leftLen :: Ref Number
  , rightLen :: Ref Number
  , trailPoints :: Ref String
  , gHead :: Ref String
  , head :: Fn2 Number Number String
  , note :: Ref String
  , flyTo :: EffectFn1 MouseEvt Unit
  , nudge :: Effect Unit
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

headPoints :: Number -> Number -> String
headPoints x y =
  toString (x - 4.0) <> "," <> toString (y + headLen) <> " "
    <> toString (x + 4.0)
    <> ","
    <> toString (y + headLen)
    <> " "
    <> toString x
    <> ","
    <> toString y

gHeadPoints :: Number -> Number -> String
gHeadPoints cx cy =
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

useMulticopterViz :: Effect MulticopterBindings
useMulticopterViz = do
  s <- Ref.new { x: homeX, y: homeY, vx: 0.0, vy: 0.0, th: 0.0, om: 0.0 }
  target <- Ref.new { x: homeX, y: homeY }
  f1 <- Ref.new (craftMass * gravity / 2.0)
  f2 <- Ref.new (craftMass * gravity / 2.0)
  trail <- Ref.new ([] :: Array { x :: Number, y :: Number })
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

  let
    syncTarget = do
      t <- Ref.read target
      write targetPx { x: originX + t.x * scale, y: originY - t.y * scale }

    syncCraft = do
      st <- Ref.read s
      fa <- Ref.read f1
      fb <- Ref.read f2
      let
        cx = originX + st.x * scale
        cy = originY - st.y * scale
      write comX cx
      write comY cy
      write craftTransform
        ( "translate(" <> toStringWith (fixed 2) cx <> "," <> toStringWith (fixed 2) cy
            <> ") rotate("
            <> toStringWith (fixed 2) (-st.th * 180.0 / Number.pi)
            <> ")"
        )
      write leftLen (Number.max (headLen + 2.0) (fa * 3.2))
      write rightLen (Number.max (headLen + 2.0) (fb * 3.2))
      write gHead (gHeadPoints cx cy)

    syncTrail = do
      points <- Ref.read trail
      write trailPoints $ joinWith " " $ points <#> \p ->
        toStringWith (fixed 1) (originX + p.x * scale) <> ","
          <> toStringWith (fixed 1) (originY - p.y * scale)

    reset = do
      Ref.write { x: homeX, y: homeY, vx: 0.0, vy: 0.0, th: 0.0, om: 0.0 } s
      Ref.write { x: homeX, y: homeY } target
      Ref.write (craftMass * gravity / 2.0) f1
      Ref.write (craftMass * gravity / 2.0) f2
      Ref.write [] trail
      write note waypointNote
      syncTarget
      syncCraft
      syncTrail

    control = do
      st <- Ref.read s
      t <- Ref.read target
      let
        axDes = clamp (-6.0) 6.0 (1.6 * (t.x - st.x) - 2.0 * st.vx)
        thDes = clamp (-0.5) 0.5 (-axDes / gravity)
        ayDes = 5.0 * (t.y - st.y) - 3.4 * st.vy
        c = Number.cos st.th
        rawThrust = craftMass * (gravity + ayDes) / (if Number.abs c < 0.3 then 0.3 else c)
        thrust = Number.max 0.0 (Number.min (2.0 * thrustMax) rawThrust)
        tauDes = -20.0 * (st.th - thDes) - 6.3 * st.om
        delta = inertia * tauDes / armLen
      Ref.write (Number.max 0.0 (Number.min thrustMax (thrust / 2.0 - delta / 2.0))) f1
      Ref.write (Number.max 0.0 (Number.min thrustMax (thrust / 2.0 + delta / 2.0))) f2

    stepOnce = do
      control
      st <- Ref.read s
      fa <- Ref.read f1
      fb <- Ref.read f2
      let
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
      Ref.write { x: wallRight.x, y: floorHit.y, vx: wallRight.vx, vy: floorHit.vy, th, om } s
      when (not (Number.isFinite floorHit.y) || not (Number.isFinite th) || Number.abs th > 40.0)
        reset

    describe = do
      st <- Ref.read s
      t <- Ref.read target
      fa <- Ref.read f1
      fb <- Ref.read f2
      let
        dx = t.x - st.x
        dy = st.y - t.y
        deg = st.th * 180.0 / Number.pi
      if Number.abs dx > 0.15 || Number.abs dy > 0.15 then do
        let
          dirText =
            if Number.abs dx > 0.15 then (if dx > 0.0 then "flying right" else "flying left")
            else if dy > 0.0 then "easing down"
            else "climbing"
        write note
          ( dirText <> " · tilt " <> (if deg > 0.0 then "+" else "")
              <> toStringWith (fixed 0) deg
              <> "° · f1="
              <> toStringWith (fixed 1) fa
              <> " f2="
              <> toStringWith (fixed 1) fb
          )
      else
        write note
          ( "holding at waypoint · f1=" <> toStringWith (fixed 1) fa <> " f2="
              <> toStringWith (fixed 1) fb
              <> " — click to fly somewhere else"
          )

    flyTo event = do
      point <- toMaybe <$> runEffectFn1 clickPointImpl event
      case point of
        Nothing -> pure unit
        Just pt -> do
          Ref.write
            { x: clamp (-10.3) 10.3 ((pt.x - originX) / scale)
            , y: clamp 0.6 9.2 ((originY - pt.y) / scale)
            }
            target
          write note "waypoint set — banking toward it"
          syncTarget

    nudge = do
      d <- Ref.read ndir
      st <- Ref.read s
      Ref.write
        (st { vy = st.vy - 2.6, vx = st.vx + d * 2.2, om = st.om + d * 2.6, th = st.th + d * 0.45 })
        s
      Ref.write (-d) ndir
      write note "disturbance applied — watch the thrust arrows split"
      syncCraft

    tick timestamp = do
      previous <- Ref.read lastTime
      let base = if previous == 0.0 then timestamp else previous
      Ref.modify_ (_ + Number.min 0.05 ((timestamp - base) / 1000.0)) acc
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
        grown <- Ref.modify (\points -> Array.snoc points { x: st.x, y: st.y }) trail
        when (Array.length grown > trailCap) (Ref.modify_ (Array.drop 1) trail)
        syncTrail
      describe
      syncCraft

  syncTarget
  syncCraft
  syncTrail

  resume <- runEffectFn1 rafLoopImpl (mkEffectFn1 tick)
  runEffectFn1 useAfterPaint resume

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
    , trailPoints
    , gHead
    , head: mkFn2 headPoints
    , note
    , flyTo: mkEffectFn1 flyTo
    , nudge
    , reset
    }
