-- | Checks for the mass-spring strand's pure pieces: the spring roster
-- | (structural links, then softer bend springs), the pre-stretched
-- | hanging chain whose structural springs balance gravity exactly, the
-- | Hooke-plus-damping spring force, the damped warm-up step, the two
-- | integrators (semi-implicit moves by the new velocity, explicit by the
-- | old), the escape test, the tail kick, and the strain tint on each
-- | drawn segment.
module Test.Components.MassSpringViz (suite) where

import Prelude

import App.Components.MassSpringViz
  ( Mass
  , hangingStrand
  , kickedTail
  , massEscaped
  , settleStep
  , springForce
  , springLengths
  , stepMass
  , strandRestNote
  , strandSegments
  , strandSprings
  )
import Data.Array (all, filter, index, length, range, take)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..))
import Data.Number (abs, nan)
import Effect (Effect)
import Test.Harness (Tally, expect)

near :: Number -> Number -> Boolean
near a b = abs (a - b) < 1.0e-9

mass :: Number -> Number -> Mass
mass x y = { x, y, vx: 0.0, vy: 0.0 }

structural :: { a :: Int, b :: Int, rest :: Number, k :: Number, bend :: Boolean }
structural = { a: 0, b: 1, rest: 28.0, k: 200.0, bend: false }

netOn :: Int -> Maybe { fx :: Number, fy :: Number }
netOn i = do
  above <- index hangingStrand (i - 1)
  here <- index hangingStrand i
  let
    up = springForce structural above here
    downward = case index hangingStrand (i + 1) of
      Just below -> springForce structural here below
      Nothing -> { fx: 0.0, fy: 0.0 }
  pure { fx: downward.fx - up.fx, fy: 220.0 + downward.fy - up.fy }

tintOf :: Number -> Array String
tintOf len = map _.stroke (strandSegments [] [ mass 0.0 0.0, mass 0.0 len ])

stroke :: Int -> String
stroke pct =
  "color-mix(in srgb, var(--blue-underline), var(--orange-underline) " <> show pct <> "%)"

suite :: Tally -> Effect Unit
suite t = do
  expect t "the strand has 7 structural and 6 bend springs" { structural: 7, bend: 6 }
    { structural: length (filter (not <<< _.bend) strandSprings)
    , bend: length (filter _.bend strandSprings)
    }
  expect t "structural springs join neighbors at 28px rest, stiffness 200" true
    ( all (\s -> s.b == s.a + 1 && s.rest == 28.0 && s.k == 200.0)
        (filter (not <<< _.bend) strandSprings)
    )
  expect t "bend springs skip a mass, at twice the rest length and stiffness 60" true
    (all (\s -> s.b == s.a + 2 && s.rest == 56.0 && s.k == 60.0) (filter _.bend strandSprings))

  expect t "the chain has eight masses" 8 (length hangingStrand)
  expect t "the chain hangs from the anchor" (Just (mass 320.0 50.0)) (index hangingStrand 0)
  expect t "the chain hangs straight down, at rest" true
    (all (\m -> m.x == 320.0 && m.vx == 0.0 && m.vy == 0.0) hangingStrand)
  expect t "each link is pre-stretched by the weight below it (220/200 px per mass)" true
    ( all
        ( \i ->
            map (near (28.0 + toNumber (8 - i) * 1.1))
              (index (springLengths hangingStrand) (i - 1)) == Just true
        )
        (range 1 7)
    )
  expect t "the structural springs balance gravity on every hanging mass" true
    (all (\i -> map (\f -> near f.fx 0.0 && near f.fy 0.0) (netOn i) == Just true) (range 1 7))
  expect t "the bend springs start stretched, hence the warm-up" true
    ( all
        ( \s -> case index hangingStrand s.a, index hangingStrand s.b of
            Just a, Just b -> (springForce s a b).fy > 0.0
            _, _ -> false
        )
        (filter _.bend strandSprings)
    )

  expect t "a spring at rest length exerts nothing" { fx: 0.0, fy: 0.0 }
    (springForce structural (mass 0.0 0.0) (mass 0.0 28.0))
  expect t "a stretched spring pulls its mass toward the other" { fx: 0.0, fy: 400.0 }
    (springForce structural (mass 0.0 0.0) (mass 0.0 30.0))
  expect t "a squashed spring pushes its mass away" { fx: -400.0, fy: 0.0 }
    (springForce structural (mass 0.0 0.0) (mass 26.0 0.0))
  expect t "damping adds 1.6 per px/s of separating speed" true
    (near 16.0 (springForce structural (mass 0.0 0.0) { x: 0.0, y: 28.0, vx: 0.0, vy: 10.0 }).fy)
  expect t "coincident masses exert no force rather than NaN" { fx: 0.0, fy: 0.0 }
    (springForce structural (mass 5.0 5.0) (mass 5.0 5.0))

  let
    gravityOnly = { fx: 0.0, fy: 220.0 }
    settled = settleStep (mass 0.0 0.0) gravityOnly
  expect t "a warm-up step keeps 94% of the new velocity" true
    (near (220.0 / 90.0 * 0.94) settled.vy)
  expect t "a warm-up step moves by the damped velocity" true
    (near (settled.vy / 90.0) settled.y)

  let
    semi = stepMass "semi" (mass 0.0 0.0) gravityOnly
    explicit = stepMass "explicit" (mass 0.0 0.0) gravityOnly
  expect t "both integrators gain the same velocity" semi.vy explicit.vy
  expect t "semi-implicit Euler moves by the new velocity" true (near (semi.vy / 90.0) semi.y)
  expect t "explicit Euler moves by the old velocity" 0.0 explicit.y
  expect t "any mode but semi integrates explicitly" explicit
    (stepMass "anything" (mass 0.0 0.0) gravityOnly)

  expect t "a mass on the canvas has not escaped" false (massEscaped (mass 320.0 160.0))
  expect t "30px past the edge still counts as on" false (massEscaped (mass (-30.0) (-30.0)))
  expect t "a mass past the left margin has escaped" true (massEscaped (mass (-31.0) 160.0))
  expect t "a mass past the right margin has escaped" true (massEscaped (mass 671.0 160.0))
  expect t "a mass past the top margin has escaped" true (massEscaped (mass 320.0 (-31.0)))
  expect t "a mass past the bottom margin has escaped" true (massEscaped (mass 320.0 351.0))
  expect t "a non-finite mass has escaped" true (massEscaped (mass nan 160.0))

  expect t "a kick sends the tail sideways and up" { x: 0.0, y: 0.0, vx: 150.0, vy: -250.0 }
    (kickedTail 1.0 1.0 (mass 0.0 0.0))
  expect t "a kick the other way mirrors sideways only" { x: 0.0, y: 0.0, vx: -120.0, vy: -200.0 }
    (kickedTail (-1.0) 0.8 (mass 0.0 0.0))

  let
    eq = springLengths hangingStrand
    atRest = strandSegments eq hangingStrand
  expect t "every spring is drawn" 13 (length atRest)
  expect t "segments keep the bend flag" (map _.bend strandSprings) (map _.bend atRest)
  expect t "at equilibrium every segment is blue" true (all (_ == stroke 0) (map _.stroke atRest))
  expect t "a segment runs between its masses" (Just { ax: 320.0, ay: 50.0 })
    (map (\s -> { ax: s.ax, ay: s.ay }) (index atRest 0))
  expect t "without an equilibrium length, a segment is tinted against its rest length"
    [ stroke 0 ]
    (tintOf 28.0)
  expect t "an eighth of the rest length stretched tints halfway" [ stroke 50 ] (tintOf 31.5)
  expect t "squashing tints like stretching" [ stroke 50 ] (tintOf 24.5)
  expect t "a quarter of the rest length tints fully orange" [ stroke 100 ] (tintOf 35.0)
  expect t "the tint stops at fully orange" [ stroke 100 ] (tintOf 60.0)
  expect t "springs whose masses are missing are skipped" 1
    (length (strandSegments [] (take 2 hangingStrand)))

  expect t "the resting note invites a comparison"
    "hanging at equilibrium — perturb it and compare integrators"
    strandRestNote
