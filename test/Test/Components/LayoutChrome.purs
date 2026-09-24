-- | Checks for the layout chrome's pure cores: the error page's scene
-- | geometry (the rings, the spokes' angles and unit vectors, where each
-- | spoke ends as the outer ring grows), the one-decimal rounding of the
-- | stray node's coordinates, and the page's words for a 404 and for
-- | anything else. Expected numbers were computed with the original
-- | TypeScript's formulas in bun: `220 + ux * r * 1.1`, `+n.toFixed(1)`.
-- | Where the stray node lands for its two rolls: across the upper
-- | half-disc from 15° to 165°, from 84 out to 200, never above the
-- | viewBox's top margin (y ≥ 25); and the page's class for the color
-- | mode. Then the footer's light switch — its words gated on mount exactly as
-- | the template's `mounted && isDark ? … : …` was — and the past-version
-- | hosts, stripped as `url.replace("https://", "")` stripped them.
module Test.Components.LayoutChrome (suite) where

import Prelude

import App.Components.AppFooter (footerAriaFor, footerLabelFor, versionHost)
import App.Components.ErrorPage
  ( Spoke
  , errorDetailFor
  , errorHeadingFor
  , errorModeClassFor
  , errorStatusWordFor
  , ringTargets
  , roundTenth
  , spokeTip
  , spokes
  , strayAt
  )
import Data.Array (all, concatMap, length, (!!))
import Data.Maybe (Maybe(..))
import Data.Nullable (notNull, null)
import Data.Number (abs, atan2, pi, sqrt)
import Effect (Effect)
import Test.Harness (Tally, expect)

spoke16 :: Spoke
spoke16 = { deg: 16, ux: 0.9612616959383189, uy: 0.27563735581699916 }

spoke64 :: Spoke
spoke64 = { deg: 64, ux: 0.43837114678907746, uy: 0.8987940462991669 }

spoke164 :: Spoke
spoke164 = { deg: 164, ux: -0.9612616959383187, uy: 0.27563735581699966 }

suite :: Tally -> Effect Unit
suite t = do
  expect t "the rings rest at 66, 126 and 186" [ 66.0, 126.0, 186.0 ] ringTargets

  expect t "seven spokes fan out" 7 (length spokes)
  expect t "the spokes are keyed by their angles" [ 16, 38, 64, 88, 112, 138, 164 ]
    (map _.deg spokes)
  expect t "the first spoke's unit vector matches the original" (Just spoke16) (spokes !! 0)
  expect t "the middle spoke's unit vector matches the original" (Just spoke64) (spokes !! 2)
  expect t "the last spoke's unit vector matches the original" (Just spoke164) (spokes !! 6)
  expect t "every spoke is a unit vector" true
    (all (\s -> abs (s.ux * s.ux + s.uy * s.uy - 1.0) < 1.0e-12) spokes)
  expect t "every spoke points into the upper half-disc" true (all (\s -> s.uy > 0.0) spokes)

  expect t "before the outer ring starts, a spoke ends at the center" { x: 220.0, y: 220.0 }
    (spokeTip 0.0 spoke64)
  expect t "a spoke ends a tenth past the settled outer ring"
    { x: 309.6907366330453, y: 36.106738127190425 }
    (spokeTip 186.0 spoke64)
  expect t "a shallow spoke ends far right" { x: 416.67414298898007, y: 163.60459699984196 }
    (spokeTip 186.0 spoke16)
  expect t "a spoke past the vertical ends left of center"
    { x: 23.325857011019963, y: 163.60459699984187 }
    (spokeTip 186.0 spoke164)
  expect t "the scene's own spoke ends where the original drew it"
    (Just { x: 227.14043702533172, y: 15.524636791892988 })
    (spokeTip 186.0 <$> spokes !! 3)
  expect t "a spoke tracks the outer ring mid-spring"
    { x: 280.75824094496613, y: 95.42714518293545 }
    (spokeTip 126.0 spoke64)

  expect t "roundTenth drops a hundredth below the half" 118.0 (roundTenth 118.04)
  expect t "roundTenth keeps toFixed's binary rounding at .05" 118.0 (roundTenth 118.05)
  expect t "roundTenth rounds up past the half" 12.4 (roundTenth 12.36)
  expect t "roundTenth leaves a whole number alone" 86.0 (roundTenth 86.0)
  expect t "roundTenth rounds a negative away from zero at the half" (-3.3) (roundTenth (-3.25))
  expect t "roundTenth rounds a small half up" 0.1 (roundTenth 0.05)
  expect t "roundTenth carries into the next whole" 200.0 (roundTenth 199.99)
  expect t "roundTenth flattens a tiny value to zero" 0.0 (roundTenth 1.0e-9)

  expect t "the lowest rolls put the stray at 15°, just outside the inner ring"
    { x: 301.1, y: 198.3 }
    (strayAt 0.0 0.0)
  expect t "straight up, the stray reaches the top margin and no further" { x: 220.0, y: 25.0 }
    (strayAt 0.5 1.0)
  expect t "the highest rolls put the stray at 165°, out at 200" { x: 26.8, y: 168.2 }
    (strayAt 1.0 1.0)
  let
    rolls = [ 0.0, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.999 ]
    strays = concatMap (\spin -> map (strayAt spin) rolls) rolls
    fromCenter p = sqrt ((p.x - 220.0) * (p.x - 220.0) + (220.0 - p.y) * (220.0 - p.y))
    degrees p = atan2 (220.0 - p.y) (p.x - 220.0) * 180.0 / pi
  expect t "the stray never rises past the viewBox's top margin" true
    (all (\p -> p.y >= 25.0) strays)
  expect t "the stray always sits between the inner ring and 200 out" true
    (all (\p -> fromCenter p >= 83.9 && fromCenter p <= 200.1) strays)
  expect t "the stray always sits in the upper half-disc, 15° to 165°" true
    (all (\p -> degrees p >= 14.9 && degrees p <= 165.1) strays)
  expect t "the stray's coordinates are rounded to a tenth" true
    (all (\p -> p.x == roundTenth p.x && p.y == roundTenth p.y) strays)

  expect t "a dark color mode classes the page dark" "dark-mode" (errorModeClassFor "dark")
  expect t "a light color mode classes the page light" "light-mode" (errorModeClassFor "light")
  expect t "any other mode falls back to light" "light-mode" (errorModeClassFor "sepia")

  expect t "a 404 is off the map" "Off the map." (errorHeadingFor true)
  expect t "anything else broke" "Something broke." (errorHeadingFor false)
  expect t "a 404's meta word" "not found" (errorStatusWordFor true)
  expect t "any other error's meta word" "error" (errorStatusWordFor false)

  expect t "a missing message falls back to the stock line" "An unexpected error occurred."
    (errorDetailFor null)
  expect t "an empty message falls back too, as || did" "An unexpected error occurred."
    (errorDetailFor (notNull ""))
  expect t "a message is shown as it is" "Boom" (errorDetailFor (notNull "Boom"))
  expect t "a blank-but-not-empty message is kept, as || did" " " (errorDetailFor (notNull " "))

  let
    switchCases =
      [ { mounted: false, dark: false }
      , { mounted: false, dark: true }
      , { mounted: true, dark: false }
      , { mounted: true, dark: true }
      ]
  expect t "the light switch reads lights off until mounted and dark"
    [ "lights off", "lights off", "lights off", "lights on" ]
    (map (\c -> footerLabelFor c.mounted c.dark) switchCases)
  expect t "the light switch's name follows the same gate"
    [ "lights off — switch to dark mode"
    , "lights off — switch to dark mode"
    , "lights off — switch to dark mode"
    , "lights on — switch to light mode"
    ]
    (map (\c -> footerAriaFor c.mounted c.dark) switchCases)

  expect t "a past version's host drops its https scheme" "v1.amittai.studio"
    (versionHost "https://v1.amittai.studio")
  expect t "only the first https:// goes, as String#replace did" "https://v2.amittai.studio"
    (versionHost "https://https://v2.amittai.studio")
  expect t "an http address keeps its scheme" "http://v3.amittai.studio"
    (versionHost "http://v3.amittai.studio")
  expect t "an https:// mid-string is stripped too" "see v1.amittai.studio"
    (versionHost "see https://v1.amittai.studio")
  expect t "the scheme match is case-sensitive" "HTTPS://v1.amittai.studio"
    (versionHost "HTTPS://v1.amittai.studio")
  expect t "an empty address stays empty" "" (versionHost "")
  expect t "a bare scheme strips to nothing" "" (versionHost "https://")
