-- | Checks for the PBD cloth's pure pieces: the grid indexing, the
-- | warp/weft links and the diagonal shear floors, the pinned resting
-- | grid, the gust envelope, the wind-and-gravity prediction (nothing
-- | reaches the pinned row, the gust shoves along its direction and
-- | lifts, the breeze sways), pair projection, the compression floors,
-- | self-contact, the implied velocity, the runaway test, the strain tint,
-- | and the status line — plus the stiffness control: more sweeps hold
-- | a gusted cloth tighter.
module Test.Components.PbdClothViz (suite) where

import Prelude

import App.Components.PbdClothViz
  ( Particle
  , Wind
  , clothLinks
  , clothNote
  , clothPredicted
  , clothProjected
  , clothRest
  , clothRunaway
  , clothSegments
  , clothShears
  , clothStrain
  , clothVelocity
  , compressionFloor
  , contactPush
  , gustEnvelope
  )
import App.Utils.JsMath (hypot)
import Data.Array
  ( all
  , drop
  , foldl
  , head
  , index
  , length
  , mapWithIndex
  , range
  , take
  , updateAt
  , zipWith
  )
import Data.Array as Array
import Data.Maybe (Maybe(..), fromMaybe, isNothing)
import Data.Number (abs, infinity, sin, sqrt2)
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

calm :: Wind
calm = { blowing: false, envelope: 0.0, dir: 1.0, phase: 0.0, time: 0.0 }

gusting :: Number -> Wind
gusting dir = { blowing: true, envelope: 1.0, dir, phase: 0.0, time: 0.0 }

corner :: Particle
corner = free 200.0 290.0

stroke :: Int -> String
stroke pct =
  "color-mix(in srgb, var(--blue-underline), var(--orange-underline) " <> show pct <> "%)"

sweep :: Array Particle -> Array Particle
sweep ps = foldl project ps clothLinks
  where
  project acc c = fromMaybe acc do
    a <- index acc c.a
    b <- index acc c.b
    pair <- clothProjected a b c.rest
    withA <- updateAt c.a pair.a acc
    updateAt c.b pair.b withA

peakStrain :: Array Particle -> Number
peakStrain ps = foldl max 0.0 (Array.mapMaybe strain clothLinks)
  where
  strain c = clothStrain c <$> index ps c.a <*> index ps c.b

underGust :: Int -> { ps :: Array Particle, peak :: Number }
underGust iters = foldl run { ps: clothRest, peak: 0.0 } (range 1 120)
  where
  run acc _ =
    let
      moved = mapWithIndex (\i p -> if p.pinned then p else clothPredicted (gusting 1.0) i p) acc.ps
      solved = foldl (\ps _ -> sweep ps) moved (range 1 iters)
      next = zipWith (\before p -> if p.pinned then p else clothVelocity before p) acc.ps solved
    in
      { ps: next, peak: max acc.peak (peakStrain next) }

suite :: Tally -> Effect Unit
suite t = do
  expect t "the grid is laid out row-major, 13 to a row"
    [ Just { x: 440.0, y: 150.0 }, Just { x: 200.0, y: 170.0 } ]
    (map (map (\p -> { x: p.x, y: p.y }) <<< index clothRest) [ 12, 13 ])

  expect t "the cloth has 96 warp and 91 weft links" 187 (length clothLinks)
  expect t "links join grid neighbors at 20px" true
    (all (\c -> c.rest == 20.0 && (c.b == c.a + 1 || c.b == c.a + 13)) clothLinks)
  expect t "links are pushed right then down, per cell" [ { a: 0, b: 1 }, { a: 0, b: 13 } ]
    (map (\c -> { a: c.a, b: c.b }) (take 2 clothLinks))
  expect t "every quad has both diagonals as shear floors" 168 (length clothShears)
  expect t "shear floors rest at the diagonal length" true
    (all (\c -> c.rest == 20.0 * sqrt2) clothShears)
  expect t "the first quad's diagonals cross it" [ { a: 0, b: 14 }, { a: 1, b: 13 } ]
    (map (\c -> { a: c.a, b: c.b }) (take 2 clothShears))

  expect t "the cloth has 104 particles" 104 (length clothRest)
  expect t "the top row is pinned" true (all _.pinned (take 13 clothRest))
  expect t "every lower particle is free, with unit inverse mass" true
    (all (\p -> not p.pinned && p.w == 1.0) (drop 13 clothRest))
  expect t "the grid is centred, its top at 150px" (Just (pin 200.0 150.0)) (head clothRest)
  expect t "the bottom-right corner sits a full grid away" (Just (free 440.0 290.0))
    (index clothRest 103)
  expect t "a resting cloth carries no strain" 0.0 (peakStrain clothRest)
  expect t "a resting cloth is drawn all blue" true
    (all (_ == stroke 0) (map _.stroke (clothSegments clothRest)))
  expect t "every link is drawn" 187 (length (clothSegments clothRest))

  expect t "a fresh gust blows at full strength" 1.0 (gustEnvelope 2.2)
  expect t "a gust fades linearly" 0.5 (gustEnvelope 1.1)
  expect t "a spent gust is still" 0.0 (gustEnvelope 0.0)
  expect t "an overspent gust is still" 0.0 (gustEnvelope (-0.1))

  let
    topFree = free 200.0 150.0
    atTop = clothPredicted (gusting 1.0) 0 topFree
  expect t "the top row feels neither gust nor breeze, only gravity" true
    (atTop.vx == 0.0 && near atTop.vy (500.0 / 120.0 * 0.999))
  let
    still = clothPredicted calm 91 corner
    east = clothPredicted (gusting 1.0) 91 corner
    west = clothPredicted (gusting (-1.0)) 91 corner
  expect t "the breeze sways the bottom row" true
    (near still.vx (20.0 * sin 2.1 / 120.0 * 0.999))
  expect t "a gust shoves the bottom row along its direction" true
    (east.vx > still.vx && west.vx < still.vx)
  expect t "a gust lifts the bottom row" true (east.vy < still.vy)
  expect t "a spent gust is no gust" still
    (clothPredicted { blowing: true, envelope: 0.0, dir: 1.0, phase: 0.0, time: 0.0 } 91 corner)
  expect t "a particle moves along its new velocity" true
    (near east.x (corner.x + east.vx / 120.0) && near east.y (corner.y + east.vy / 120.0))

  expect t "projecting two free particles moves each half the error" true
    ( map (\r -> near r.a.y 2.5 && near r.b.y 17.5)
        (clothProjected (free 0.0 0.0) (free 0.0 20.0) 15.0) == Just true
    )
  expect t "projecting against a pin moves only the free particle" true
    ( map (\r -> r.a.y == 0.0 && near r.b.y 15.0)
        (clothProjected (pin 0.0 0.0) (free 0.0 20.0) 15.0) == Just true
    )
  expect t "two pins are never projected" true
    (isNothing (clothProjected (pin 0.0 0.0) (pin 0.0 20.0) 15.0))

  let
    diagonal = { a: 0, b: 1, rest: 20.0 * sqrt2 }
    link = { a: 0, b: 1, rest: 20.0 }
  expect t "a diagonal squashed below 45% is pushed back out to it" (Just true)
    ( map (\r -> near (dist r.a r.b) (0.45 * 20.0 * sqrt2))
        (compressionFloor 0.45 diagonal (free 0.0 0.0) (free 0.0 10.0))
    )
  expect t "a diagonal above its floor is left alone" true
    (isNothing (compressionFloor 0.45 diagonal (free 0.0 0.0) (free 0.0 14.0)))
  expect t "a link squashed below 75% is pushed back out to it" (Just true)
    ( map (\r -> near (dist r.a r.b) 15.0)
        (compressionFloor 0.75 link (free 0.0 0.0) (free 0.0 14.0))
    )
  expect t "a stretched link is no business of the floor" true
    (isNothing (compressionFloor 0.75 link (free 0.0 0.0) (free 0.0 30.0)))

  expect t "particles closer than 13px are pushed apart to it" (Just true)
    (map (\r -> near (dist r.a r.b) 13.0) (contactPush (free 0.0 0.0) (free 5.0 0.0)))
  expect t "particles exactly 13px apart are left alone" true
    (isNothing (contactPush (free 0.0 0.0) (free 13.0 0.0)))
  expect t "two pinned particles never collide" true
    (isNothing (contactPush (pin 0.0 0.0) (pin 1.0 0.0)))

  expect t "the implied velocity is the displacement over the step" true
    ( (\p -> near p.vx 120.0 && near p.vy (-240.0))
        (clothVelocity (free 0.0 0.0) (free 1.0 (-2.0)))
    )
  expect t "a particle in range is fine" false (clothRunaway (free 320.0 160.0))
  expect t "a particle beyond 4000px has run away" true (clothRunaway (free 0.0 4001.0))
  expect t "a non-finite particle has run away" true (clothRunaway (free infinity 0.0))

  expect t "strain is stretch over rest length" true
    (near 0.1 (clothStrain link (free 0.0 0.0) (free 0.0 22.0)))
  expect t "7.5% strain tints halfway" [ stroke 50 ]
    (map _.stroke (clothSegments [ free 0.0 0.0, free 21.5 0.0 ]))
  expect t "15% strain tints fully orange" [ stroke 100 ]
    (map _.stroke (clothSegments [ free 0.0 0.0, free 23.0 0.0 ]))

  expect t "the note says when a gust is blowing"
    "iterations: 3 · max stretch 12.3% · gust blowing"
    (clothNote 3 0.123 2.0)
  expect t "the note falls back to the breeze" "iterations: 1 · max stretch 0.0% · ambient breeze"
    (clothNote 1 0.0 0.0)

  let
    strains = map (_.peak <<< underGust) [ 1, 2, 4, 8 ]
  expect t "a gust strains the cloth" true ((underGust 1).peak > 0.0)
  expect t "each doubling of the sweeps holds a gusted cloth tighter" true
    (all identity (zipWith (>) strains (drop 1 strains)))
  expect t "a gust blows the cloth along its direction" true
    (map _.x (index (underGust 4).ps 97) > map _.x (index clothRest 97))
  expect t "the pinned row never moves" (take 13 clothRest) (take 13 (underGust 4).ps)
