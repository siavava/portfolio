-- | Checks for the PBD chain's pure pieces: the links and the resting
-- | chain under its pin, the prediction step, pair projection (weighted
-- | by inverse mass, skipping two pins), the implied velocity, the
-- | runaway test, strain and its tint, the swing's kick, and the status
-- | line — plus the visualizer's point: more Gauss-Seidel sweeps leave a
-- | loaded chain less stretched.
module Test.Components.PbdViz (suite) where

import Prelude

import App.Components.PbdViz
  ( Particle
  , chainLinks
  , chainNote
  , chainPredicted
  , chainProjected
  , chainRunaway
  , chainSegments
  , chainStrain
  , chainVelocity
  , restChain
  , swungBy
  )
import App.Utils.JsMath (hypot)
import Data.Array (all, foldl, head, index, last, length, range, updateAt, zipWith)
import Data.Array as Array
import Data.Maybe (Maybe(..), fromMaybe, isNothing)
import Data.Number (abs, infinity)
import Effect (Effect)
import Test.Harness (Tally, expect)

near :: Number -> Number -> Boolean
near a b = abs (a - b) < 1.0e-9

free :: Number -> Number -> Particle
free x y = { x, y, vx: 0.0, vy: 0.0, w: 1.0, pinned: false }

pin :: Number -> Number -> Particle
pin x y = { x, y, vx: 0.0, vy: 0.0, w: 0.0, pinned: true }

dist :: Particle -> Particle -> Number
dist a b = hypot (b.x - a.x) (b.y - a.y)

sweep :: Array Particle -> Array Particle
sweep ps = foldl project ps chainLinks
  where
  project acc c = fromMaybe acc do
    a <- index acc c.a
    b <- index acc c.b
    pair <- chainProjected a b c.rest
    withA <- updateAt c.a pair.a acc
    updateAt c.b pair.b withA

peakStrain :: Array Particle -> Number
peakStrain ps = foldl max 0.0 (Array.mapMaybe strain chainLinks)
  where
  strain c = chainStrain c <$> index ps c.a <*> index ps c.b

substep :: Int -> Array Particle -> Array Particle
substep iters ps = zipWith settle ps solved
  where
  solved = foldl (\acc _ -> sweep acc) (map (\p -> if p.pinned then p else chainPredicted p) ps)
    (range 1 iters)
  settle before p = if p.pinned then p else chainVelocity before p

peakAfterSwing :: Int -> Number
peakAfterSwing iters = (foldl run { ps: swung, peak: 0.0 } (range 1 240)).peak
  where
  swung = Array.mapWithIndex (\i p -> if p.pinned then p else swungBy 1.0 1.0 i p) restChain
  run acc _ =
    let
      next = substep iters acc.ps
    in
      { ps: next, peak: max acc.peak (peakStrain next) }

stroke :: Int -> String
stroke pct =
  "color-mix(in srgb, var(--blue-underline), var(--orange-underline) " <> show pct <> "%)"

suite :: Tally -> Effect Unit
suite t = do
  expect t "the chain has 15 links between 16 particles" 15 (length chainLinks)
  expect t "links join neighbors at 15px" true
    (all (\c -> c.b == c.a + 1 && c.rest == 15.0) chainLinks)
  expect t "the chain has 16 particles" 16 (length restChain)
  expect t "the first particle is the pin, with no inverse mass" (Just (pin 320.0 38.0))
    (head restChain)
  expect t "every other particle is free, with unit inverse mass" true
    (all (\p -> not p.pinned && p.w == 1.0) (Array.drop 1 restChain))
  expect t "the chain hangs straight down at rest length" (Just (free 320.0 263.0))
    (last restChain)
  expect t "a resting chain carries no strain" 0.0 (peakStrain restChain)

  let
    fallen = chainPredicted (free 0.0 0.0)
  expect t "prediction adds a step of gravity, damped" true
    (near (650.0 / 120.0 * 0.9995) fallen.vy)
  expect t "prediction moves along the new velocity" true (near (fallen.vy / 120.0) fallen.y)
  expect t "prediction damps sideways motion" true
    (near 99.95 (chainPredicted (free 0.0 0.0) { vx = 100.0 }).vx)

  expect t "projecting two free particles moves each half the error" true
    ( map (\r -> near r.a.y 2.5 && near r.b.y 17.5)
        (chainProjected (free 0.0 0.0) (free 0.0 20.0) 15.0) == Just true
    )
  expect t "projecting against a pin moves only the free particle" true
    ( map (\r -> r.a.y == 0.0 && near r.b.y 15.0)
        (chainProjected (pin 0.0 0.0) (free 0.0 20.0) 15.0) == Just true
    )
  expect t "projection lands the pair at the target distance" true
    ( map (\r -> near 15.0 (dist r.a r.b))
        (chainProjected (free 1.0 2.0) (free 13.0 11.0) 15.0) == Just true
    )
  expect t "projection pushes a squashed pair apart" true
    ( map (\r -> near r.a.x (-2.5) && near r.b.x 12.5)
        (chainProjected (free 0.0 0.0) (free 10.0 0.0) 15.0) == Just true
    )
  expect t "two pins are never projected" true
    (isNothing (chainProjected (pin 0.0 0.0) (pin 0.0 20.0) 15.0))

  expect t "the implied velocity is the displacement over the step" true
    ( (\p -> near p.vx 120.0 && near p.vy (-240.0))
        (chainVelocity (free 0.0 0.0) (free 1.0 (-2.0)))
    )

  expect t "a particle in range is fine" false (chainRunaway (free 320.0 160.0))
  expect t "a particle beyond 4000px across has run away" true (chainRunaway (free 4001.0 0.0))
  expect t "a particle beyond 4000px down has run away" true (chainRunaway (free 0.0 (-4001.0)))
  expect t "a non-finite particle has run away" true (chainRunaway (free infinity 0.0))

  let
    link = { a: 0, b: 1, rest: 15.0 }
  expect t "strain is stretch over rest length" true
    (near 0.1 (chainStrain link (free 0.0 0.0) (free 0.0 16.5)))
  expect t "squashing strains like stretching" true
    (near 0.1 (chainStrain link (free 0.0 0.0) (free 0.0 13.5)))
  expect t "a resting chain is drawn all blue" true
    (all (_ == stroke 0) (map _.stroke (chainSegments restChain)))
  expect t "every link is drawn" 15 (length (chainSegments restChain))
  expect t "4% strain tints halfway" [ stroke 50 ]
    (map _.stroke (chainSegments [ free 0.0 0.0, free 0.0 15.6 ]))
  expect t "8% strain tints fully orange" [ stroke 100 ]
    (map _.stroke (chainSegments [ free 0.0 0.0, free 0.0 16.2 ]))
  expect t "the tint stops at fully orange" [ stroke 100 ]
    (map _.stroke (chainSegments [ free 0.0 0.0, free 0.0 30.0 ]))

  let
    rootKick = swungBy 1.0 1.0 0 (free 0.0 0.0)
    tailKick = swungBy 1.0 1.0 15 (free 0.0 0.0)
    backKick = swungBy (-1.0) 1.0 15 (free 0.0 0.0)
  expect t "the swing nudges the root sideways only" { vx: 150.0, vy: 0.0 }
    { vx: rootKick.vx, vy: rootKick.vy }
  expect t "the swing whips the tail hardest, and lifts it" true
    (near 670.0 tailKick.vx && near (-230.0) tailKick.vy)
  expect t "swinging the other way mirrors the sideways kick" true
    (near (-tailKick.vx) backKick.vx && backKick.vy == tailKick.vy)
  expect t "jitter scales the whole kick" true
    ((\p -> near (670.0 * 0.85) p.vx) (swungBy 1.0 0.85 15 (free 0.0 0.0)))

  expect t "one iteration reads as elastic"
    "iterations: 1 · max stretch 5.0% · single sweep — visibly elastic"
    (chainNote 1 0.05)
  expect t "a few iterations read as stiffening" "iterations: 4 · max stretch 1.2% · stiffening"
    (chainNote 4 0.0123)
  expect t "twelve iterations read as rigid" "iterations: 12 · max stretch 0.0% · chain reads rigid"
    (chainNote 12 0.0)

  let
    strains = map peakAfterSwing [ 1, 2, 4, 8, 16 ]
  expect t "each doubling of the sweeps leaves a swung chain stiffer" true
    (all identity (zipWith (>) strains (Array.drop 1 strains)))
  expect t "a single sweep lets a swung chain stretch visibly (over 5%)" true
    (peakAfterSwing 1 > 0.05)
  expect t "twelve sweeps hold a swung chain rigid (under 2%)" true (peakAfterSwing 12 < 0.02)
  expect t "solving never moves the pin" (head restChain)
    (head (foldl (\ps _ -> substep 4 ps) restChain (range 1 60)))
  expect t "twelve sweeps keep a hanging chain near its rest length (under 2%)" true
    (peakStrain (foldl (\ps _ -> substep 12 ps) restChain (range 1 240)) < 0.02)
