-- | Golden cases for the smoke visualizer's theme color parser, recorded
-- | from the original `parseColor` in the pre-port FFI. Malformed hex
-- | yields NaN channels (not the fallback), so each channel is compared
-- | as `Maybe Number` with `Nothing` standing for NaN. Plus the note the
-- | confinement toggle leaves after a reset.
module Test.Components.SmokeViz (suite) where

import Prelude

import App.Components.SmokeViz (confineNote, smokeColor)
import Data.Maybe (Maybe(..))
import Data.Number (isNaN)
import Effect (Effect)
import Test.Harness (Tally, expect)

channels :: Array Number -> Array (Maybe Number)
channels = map \n -> if isNaN n then Nothing else Just n

fallback :: Array Number
fallback = [ 7.0, 8.0, 9.0 ]

suite :: Tally -> Effect Unit
suite t = do
  let
    color label input expected =
      expect t ("smokeColor " <> label) expected (channels (smokeColor input fallback))

  color "#fff" "#fff" [ Just 255.0, Just 255.0, Just 255.0 ]
  color "#1a2b3c" "#1a2b3c" [ Just 26.0, Just 43.0, Just 60.0 ]
  color "#1a2b3c80 ignores alpha" "#1a2b3c80" [ Just 26.0, Just 43.0, Just 60.0 ]

  color "#abcd (short third pair)" "#abcd" [ Just 171.0, Just 205.0, Nothing ]
  color "#0x1234 (\"0x\" pair)" "#0x1234" [ Nothing, Just 18.0, Just 52.0 ]
  color "# alone" "#" [ Nothing, Nothing, Nothing ]
  color "# ab (space doubled)" "# ab" [ Nothing, Just 170.0, Just 187.0 ]
  color "#zzz (non-hex)" "#zzz" [ Nothing, Nothing, Nothing ]

  color "rgb(20, 20, 22)" "rgb(20, 20, 22)" [ Just 20.0, Just 20.0, Just 22.0 ]
  color "rgba drops alpha" "rgba(1.5,2,3,0.4)" [ Just 1.5, Just 2.0, Just 3.0 ]
  color "oklch read as-is" "oklch(0.5 0.1 200)" [ Just 0.5, Just 0.1, Just 200.0 ]
  color "color(srgb …) first three" "color(srgb 1 2 3 4)" [ Just 1.0, Just 2.0, Just 3.0 ]

  color "empty string" "" [ Just 7.0, Just 8.0, Just 9.0 ]
  color "hsl(1 2) (two runs)" "hsl(1 2)" [ Just 7.0, Just 8.0, Just 9.0 ]

  color "light --study-surface-sunken" "#f5f5f3" [ Just 245.0, Just 245.0, Just 243.0 ]
  color "dark --study-surface-sunken" "#141416" [ Just 20.0, Just 20.0, Just 22.0 ]
  color "light --blue-underline" "rgba(76, 116, 185, 1)" [ Just 76.0, Just 116.0, Just 185.0 ]
  color "dark --blue-underline" "rgba(120, 160, 220, 1)" [ Just 120.0, Just 160.0, Just 220.0 ]

  expect t "with confinement on, the note says the plume keeps its curl"
    "vorticity confinement on — the plume keeps its curl"
    (confineNote true)
  expect t "with confinement off, the note says the swirl damps away"
    "vorticity confinement off — small-scale swirl damps away"
    (confineNote false)
