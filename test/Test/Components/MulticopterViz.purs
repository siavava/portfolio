-- | Checks for the multicopter's pure flight model: the controller holds
-- | a hover with an even split, banks toward a waypoint by pushing
-- | harder on the far rotor, caps its bank and its rotor forces, and
-- | brings the craft to rest on the waypoint; the integrator stops the
-- | craft at the walls and the floor; the sim flags an unrecoverable
-- | state; and the stage mapping, waypoint clamp, arrows, trail, frame
-- | budget, and status line read the way the canvas draws them.
module Test.Components.MulticopterViz (suite) where

import Prelude

import App.Components.MulticopterViz
  ( Point
  , State
  , controlForces
  , craftBlownUp
  , craftHome
  , craftToStage
  , craftTransformOf
  , flightFrameDelta
  , flightNote
  , gravityHeadPoints
  , growTrail
  , hoverThrust
  , integrateCraft
  , nudgedCraft
  , thrustArrowLen
  , thrustHeadPoints
  , trailPointsText
  , waypointAt
  )
import Data.Array (head, length, range, replicate)
import Data.Foldable (foldl)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Number (abs, infinity, nan)
import Effect (Effect)
import Test.Harness (Tally, expect)

near :: Number -> Number -> Boolean
near a b = abs (a - b) < 1.0e-9

fly :: Point -> State -> State
fly target st = integrateCraft (controlForces st target) st

flyFor :: Int -> Point -> State -> State
flyFor n target st = foldl (\s _ -> fly target s) st (range 1 n)

home :: Point
home = { x: 0.0, y: 2.6 }

still :: State
still = craftHome

suite :: Tally -> Effect Unit
suite t = do
  expect t "each rotor carries half the weight at hover" 4.905 hoverThrust
  expect t "the craft starts level and at rest at home"
    { x: 0.0, y: 2.6, vx: 0.0, vy: 0.0, th: 0.0, om: 0.0 }
    craftHome

  let
    hover = controlForces craftHome home
  expect t "at the waypoint, both rotors give hover thrust"
    { f1: hoverThrust, f2: hoverThrust }
    hover
  expect t "hover thrust holds the craft exactly still" craftHome (integrateCraft hover craftHome)

  let
    right = controlForces craftHome { x: 5.0, y: 2.6 }
    left = controlForces craftHome { x: -5.0, y: 2.6 }
  expect t "to fly right, the left rotor pushes harder" true (right.f1 > right.f2)
  expect t "to fly left, the right rotor pushes harder" true (left.f2 > left.f1)
  expect t "left and right mirror each other" { f1: left.f2, f2: left.f1 } right
  expect t "a right bank tips the craft clockwise (negative tilt)" true
    ((integrateCraft right craftHome).th < 0.0)

  let
    up = controlForces craftHome { x: 0.0, y: 5.0 }
    down = controlForces craftHome { x: 0.0, y: 1.0 }
  expect t "to climb, the collective exceeds the weight" true (up.f1 + up.f2 > 9.81)
  expect t "to descend, the collective falls short of the weight" true
    (down.f1 + down.f2 < 9.81)
  expect t "straight up, the rotors share the thrust evenly" up.f1 up.f2

  let
    diving = still { y = 0.2, vy = -10.0 }
    soaring = still { y = 9.0, vy = 10.0 }
  expect t "a rotor never exceeds 18 N" { f1: 18.0, f2: 18.0 }
    (controlForces diving { x: 0.0, y: 9.2 })
  expect t "a rotor never pulls (thrust floors at 0)" { f1: 0.0, f2: 0.0 }
    (controlForces soaring { x: 0.0, y: 0.6 })
  let
    capped = controlForces (still { th = -0.5 }) { x: 100.0, y: 2.6 }
  expect t "the requested bank is capped at 0.5 rad, so a full bank needs no more torque" true
    (near capped.f1 capped.f2)
  let
    steep = controlForces (still { th = 1.5, om = -30.0 / 6.3 }) home
  expect t "a steep bank divides the collective by the 0.3 cosine floor" true
    (near (9.81 / 0.3) (steep.f1 + steep.f2))

  let
    afterOne = flyFor 120 { x: 5.0, y: 2.6 } craftHome
    settled = flyFor 2400 { x: 5.0, y: 4.0 } craftHome
  expect t "a second toward a waypoint on the right carries the craft right" true
    (afterOne.x > 0.0 && afterOne.vx > 0.0)
  expect t "the controller brings the craft onto the waypoint" true
    (abs (settled.x - 5.0) < 0.15 && abs (settled.y - 4.0) < 0.15)
  expect t "the controller brings the craft to rest level" true
    (abs settled.vx < 0.05 && abs settled.vy < 0.05 && abs settled.th < 0.01)

  let
    unpowered = { f1: 0.0, f2: 0.0 }
  expect t "without thrust, gravity accelerates the craft down" true
    (near (-9.81 / 120.0) (integrateCraft unpowered craftHome).vy)
  expect t "a stronger right rotor spins the craft counter-clockwise" true
    ((integrateCraft { f1: 4.0, f2: 6.0 } craftHome).om > 0.0)
  expect t "the right wall stops the craft dead" { x: 10.8, vx: 0.0 }
    ((\s -> { x: s.x, vx: s.vx }) (integrateCraft hover (still { x = 10.79, vx = 10.0 })))
  expect t "the left wall stops the craft dead" { x: -10.8, vx: 0.0 }
    ((\s -> { x: s.x, vx: s.vx }) (integrateCraft hover (still { x = -10.79, vx = -10.0 })))
  expect t "the floor stops the craft dead" { y: 0.2, vy: 0.0 }
    ((\s -> { y: s.y, vy: s.vy }) (integrateCraft unpowered (still { y = 0.2, vy = -5.0 })))

  expect t "a level craft is fine" false (craftBlownUp craftHome)
  expect t "a craft spun past 40 rad has blown up" true (craftBlownUp (still { th = 41.0 }))
  expect t "spinning either way counts" true (craftBlownUp (still { th = -41.0 }))
  expect t "a non-finite tilt has blown up" true (craftBlownUp (still { th = nan }))
  expect t "a non-finite height has blown up" true (craftBlownUp (still { y = infinity }))

  expect t "a nudge drops, shoves, spins and banks the craft toward its side"
    { x: 0.0, y: 2.6, vx: 2.2, vy: -2.6, th: 0.45, om: 2.6 }
    (nudgedCraft 1.0 craftHome)
  expect t "a nudge the other way mirrors the sideways parts"
    { x: 0.0, y: 2.6, vx: -2.2, vy: -2.6, th: -0.45, om: -2.6 }
    (nudgedCraft (-1.0) craftHome)

  let
    stageHome = craftToStage home
  expect t "home sits mid-stage" 320.0 stageHome.x
  expect t "home sits 2.6 m (72.8 px) above the stage origin" true (near 208.8 stageHome.y)
  expect t "the world origin sits at 88% of the stage height" { x: 320.0, y: 281.6 }
    (craftToStage { x: 0.0, y: 0.0 })
  expect t "a click sets the waypoint under it" true
    ((\p -> near p.x 1.0 && near p.y 5.0) (waypointAt { x: 348.0, y: 141.6 }))
  expect t "a click past the left wall is clamped inside it" (-10.3)
    (waypointAt { x: 0.0, y: 141.6 }).x
  expect t "a click past the right wall is clamped inside it" 10.3
    (waypointAt { x: 640.0, y: 141.6 }).x
  expect t "a click below the floor is clamped above it" 0.6
    (waypointAt { x: 320.0, y: 320.0 }).y
  expect t "a click near the top is clamped below the ceiling" 9.2
    (waypointAt { x: 320.0, y: 0.0 }).y

  expect t "a level craft at home is placed unrotated" "translate(320.00,208.80) rotate(0.00)"
    (craftTransformOf craftHome)
  expect t "a right bank rotates the craft clockwise on screen"
    "translate(320.00,208.80) rotate(5.73)"
    (craftTransformOf (still { th = -0.1 }))

  expect t "a thrust arrow is at least the head plus 2 px" 9.0 (thrustArrowLen 0.0)
  expect t "a thrust arrow grows 3.2 px per newton" 57.6 (thrustArrowLen 18.0)
  expect t "a thrust arrowhead opens down from its tip" "-4,7 4,7 0,0" (thrustHeadPoints 0.0 0.0)
  expect t "the gravity arrowhead points down 34 px below the center of mass"
    "316,127 324,127 320,134"
    (gravityHeadPoints 320.0 100.0)

  expect t "an empty trail draws nothing" "" (trailPointsText [])
  expect t "a trail is drawn in stage px to one decimal" "320.0,281.6 348.0,253.6"
    (trailPointsText [ { x: 0.0, y: 0.0 }, { x: 1.0, y: 1.0 } ])
  let
    full = map (\i -> { x: 0.0, y: toNumber i }) (range 1 150)
    grown = growTrail full { x: 0.0, y: 999.0 }
  expect t "a trail grows while short" 3
    (length (growTrail (replicate 2 { x: 0.0, y: 0.0 }) { x: 1.0, y: 1.0 }))
  expect t "a full trail keeps 150 points" 150 (length grown)
  expect t "a full trail drops its oldest point" (Just 2.0) (map _.y (head grown))

  expect t "the first frame adds nothing to the step budget" 0.0 (flightFrameDelta 0.0 5000.0)
  expect t "a frame adds its gap in seconds" true (near 0.02 (flightFrameDelta 1000.0 1020.0))
  expect t "a stalled frame adds at most 0.05 s" 0.05 (flightFrameDelta 1000.0 9000.0)

  expect t "on the waypoint, the note says it is holding"
    "holding at waypoint · f1=4.9 f2=4.9 — click to fly somewhere else"
    (flightNote craftHome home hoverThrust hoverThrust)
  expect t "within 0.15 m still counts as holding" true
    (flightNote craftHome { x: 0.1, y: 2.7 } 1.0 1.0 == flightNote craftHome home 1.0 1.0)
  expect t "off to the right, the note says flying right with the tilt"
    "flying right · tilt 0° · f1=6.0 f2=3.8"
    (flightNote craftHome { x: 5.0, y: 2.6 } 6.0 3.75)
  expect t "off to the left, the note says flying left" "flying left · tilt -6° · f1=4.0 f2=5.0"
    (flightNote (still { th = -0.1 }) { x: -5.0, y: 2.6 } 4.0 5.0)
  expect t "a positive tilt carries a plus sign" "flying left · tilt +6° · f1=4.0 f2=5.0"
    (flightNote (still { th = 0.1 }) { x: -5.0, y: 2.6 } 4.0 5.0)
  expect t "straight below, the note says easing down" "easing down · tilt 0° · f1=4.0 f2=4.0"
    (flightNote craftHome { x: 0.0, y: 1.0 } 4.0 4.0)
  expect t "straight above, the note says climbing" "climbing · tilt 0° · f1=6.0 f2=6.0"
    (flightNote craftHome { x: 0.0, y: 5.0 } 6.0 6.0)
