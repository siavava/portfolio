-- | Checks for the orbit visualizer's pure policy: the planets start
-- | spread by the golden angle, the note names the rate mode, the true
-- | mode runs each planet at a rate inverse to its period while the
-- | idealized mode compresses the spread without reordering it, a frame's
-- | time step starts at zero and is capped after a stall, and a planet
-- | advances at its rate while its angle stays within one turn.
module Test.Components.OrbitViz (suite) where

import Prelude

import App.Components.OrbitViz
  ( Planet
  , advancePlanet
  , goldenPhase
  , initialPlanets
  , orbitFrameDt
  , orbitNote
  , orbitRate
  )
import Data.Array (all, length, mapWithIndex, zipWith)
import Data.Array as Array
import Data.Maybe (fromMaybe)
import Data.Number (abs, pi, pow)
import Effect (Effect)
import Test.Harness (Tally, expect)

near :: Number -> Number -> Boolean
near a b = abs (a - b) < 1.0e-9

turn :: Number
turn = 2.0 * pi

planet :: Number -> Number -> Planet
planet period angle = { name: "test", r: 56.0, period, size: 3.0, angle }

withinTurn :: Number -> Boolean
withinTurn a = a >= 0.0 && a < turn

decreasing :: Array Number -> Boolean
decreasing xs = all identity (zipWith (>) xs (fromMaybe [] (Array.tail xs)))

suite :: Tally -> Effect Unit
suite t = do
  expect t "the first planet starts at angle zero" 0.0 (goldenPhase 0)
  expect t "the second planet starts one golden angle round" 2.399963 (goldenPhase 1)
  expect t "a phase past a full turn wraps back into it" true
    (near (3.0 * 2.399963 - turn) (goldenPhase 3))
  expect t "every starting phase lies within one turn" true
    (all (withinTurn <<< goldenPhase) [ 0, 1, 2, 3, 4, 5, 6, 7 ])

  expect t "the roster holds the six planets, innermost first"
    [ "mercury", "venus", "earth", "mars", "jupiter", "saturn" ]
    (map _.name initialPlanets)
  expect t "the orbits widen outward" true (decreasing (map (negate <<< _.r) initialPlanets))
  expect t "the periods lengthen outward" true
    (decreasing (map (\p -> 1.0 / p.period) initialPlanets))
  expect t "each planet is seeded at its golden-angle phase"
    (mapWithIndex (\i _ -> goldenPhase i) initialPlanets)
    (map _.angle initialPlanets)

  expect t "the true mode explains its ratios"
    "true ratios — angular speed ∝ 1 / orbital period"
    (orbitNote "true")
  expect t "the idealized mode explains its compression"
    "idealized — the range compressed so every orbit stays visible"
    (orbitNote "ideal")
  expect t "any other mode reads as idealized" (orbitNote "ideal") (orbitNote "")

  let
    earth = planet 1.0 0.0
    mercury = planet 0.24 0.0
    saturn = planet 29.45 0.0
  expect t "a one-year orbit runs at the base rate in the true mode" 0.35 (orbitRate "true" earth)
  expect t "a one-year orbit runs at the base rate in the idealized mode" 0.35
    (orbitRate "ideal" earth)
  expect t "the true rate is inverse to the period" true
    (near 0.35 (orbitRate "true" mercury * 0.24))
  expect t "the idealized rate is the base rate times the period ratio to the 0.35" true
    (near (0.35 * pow (1.0 / 29.45) 0.35) (orbitRate "ideal" saturn))
  let
    spread mode = orbitRate mode mercury / orbitRate mode saturn
  expect t "the idealized mode compresses the spread between the fastest and slowest" true
    (spread "ideal" < spread "true")
  expect t "the idealized mode keeps inner planets faster" true
    (decreasing (map (orbitRate "ideal") initialPlanets))
  expect t "the true mode keeps inner planets faster" true
    (decreasing (map (orbitRate "true") initialPlanets))

  expect t "the first frame has no time step" 0.0 (orbitFrameDt 0.0 1234.5)
  expect t "a frame's time step is the stamp gap in seconds" true
    (near 0.016 (orbitFrameDt 1000.0 1016.0))
  expect t "a stalled frame is capped at 0.05 s" 0.05 (orbitFrameDt 1000.0 4000.0)
  expect t "the cap is inclusive of an exact 50 ms frame" 0.05 (orbitFrameDt 1000.0 1050.0)

  expect t "a zero time step leaves a planet in place" (planet 1.0 1.0)
    (advancePlanet "true" 0.0 (planet 1.0 1.0))
  expect t "a planet advances by its rate times the time step" true
    (near 0.35 (advancePlanet "true" 1.0 earth).angle)
  expect t "a planet crossing a full turn wraps back into it" true
    (near 0.25 (advancePlanet "true" 1.0 (planet 1.0 (turn - 0.1))).angle)
  expect t "advancing keeps everything but the angle"
    { name: "test", r: 56.0, period: 1.0, size: 3.0 }
    ( (\p -> { name: p.name, r: p.r, period: p.period, size: p.size })
        (advancePlanet "ideal" 0.05 earth)
    )
  expect t "advancing preserves the roster's length" (length initialPlanets)
    (length (map (advancePlanet "ideal" 0.05) initialPlanets))
