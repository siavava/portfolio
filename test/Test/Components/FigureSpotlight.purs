-- | Checks for the figure spotlight overlay: its class follows the colour
-- | mode, dark only for "dark"; and spotlighted media is sized to fill the
-- | width it is given unless that makes it taller than allowed, when the
-- | height is filled instead — aspect kept, sides rounded to whole pixels,
-- | and media with no usable aspect left alone.
module Test.Components.FigureSpotlight (suite) where

import Prelude

import App.Components.FigureSpotlight (fittedSize, modeClassFor)
import Data.Maybe (Maybe(..))
import Data.Nullable (toMaybe)
import Data.Number (infinity, nan)
import Effect (Effect)
import Test.Harness (Tally, expect)

fit :: Number -> Number -> Number -> Maybe { width :: Int, height :: Int }
fit aspect maxW maxH = toMaybe (fittedSize aspect maxW maxH)

suite :: Tally -> Effect Unit
suite t = do
  expect t "dark mode wears the dark overlay" "dark-mode" (modeClassFor "dark")
  expect t "light mode wears the light overlay" "light-mode" (modeClassFor "light")
  expect t "any other mode wears the light overlay" [ "light-mode", "light-mode", "light-mode" ]
    (map modeClassFor [ "system", "", "Dark" ])

  expect t "a wide figure fills the width" (Just { width: 880, height: 440 }) (fit 2.0 880.0 528.0)
  expect t "a square figure too tall for the width fills the height"
    (Just { width: 528, height: 528 })
    (fit 1.0 880.0 528.0)
  expect t "a tall figure fills the height" (Just { width: 264, height: 528 }) (fit 0.5 880.0 528.0)
  expect t "a figure that exactly fits both keeps the full width"
    (Just { width: 800, height: 400 })
    (fit 2.0 800.0 400.0)
  expect t "sides are rounded to whole pixels" (Just { width: 100, height: 33 })
    (fit 3.0 100.0 528.0)
  expect t "half a pixel rounds up" (Just { width: 101, height: 51 }) (fit 2.0 101.0 528.0)
  expect t "a figure with no aspect is left alone" Nothing (fit 0.0 880.0 528.0)
  expect t "an unmeasurable aspect is left alone" Nothing (fit nan 880.0 528.0)
  expect t "an infinite aspect is left alone" Nothing (fit infinity 880.0 528.0)
