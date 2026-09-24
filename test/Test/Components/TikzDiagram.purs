-- | Checks for the client-side TikZ figure's pure decisions: the caption
-- | is the fence meta with its first `centered` flag (a whole word) taken
-- | out, null when nothing is left; a fill is tagged light only when it is
-- | a visible `rgb()`/`rgba()` colour whose relative luminance is above
-- | 0.62; and the SVG's width becomes its `max-width`, in pixels when bare.
module Test.Components.TikzDiagram (suite) where

import Prelude

import App.Components.TikzDiagram (isLightFill, luminance, svgMaxWidth, tikzCaption)
import Data.Maybe (Maybe(..))
import Data.Nullable (notNull, null, toMaybe)
import Data.Number (abs)
import Effect (Effect)
import Test.Harness (Tally, expect)

caption :: String -> Maybe String
caption meta = toMaybe (tikzCaption (notNull meta))

near :: Number -> Number -> Boolean
near a b = abs (a - b) < 1.0e-9

suite :: Tally -> Effect Unit
suite t = do
  expect t "no meta, no caption" Nothing (toMaybe (tikzCaption null))
  expect t "an empty meta has no caption" Nothing (caption "")
  expect t "a meta that is only the layout flag has no caption" Nothing (caption "centered")
  expect t "the flag before the caption is taken out" (Just "A two-state DFA")
    (caption "centered A two-state DFA")
  expect t "the flag after the caption is taken out" (Just "A two-state DFA")
    (caption "A two-state DFA centered")
  expect t "a caption alone is kept, trimmed" (Just "Figure 1") (caption "  Figure 1  ")
  expect t "only the first flag is taken out" (Just "centered") (caption "centered centered")
  expect t "a word merely containing the flag is not it" (Just "an uncentered layout")
    (caption "an uncentered layout")

  expect t "black has no luminance" true (near 0.0 (luminance 0.0 0.0 0.0))
  expect t "white has full luminance" true (near 1.0 (luminance 255.0 255.0 255.0))
  let
    red = luminance 255.0 0.0 0.0
    green = luminance 0.0 255.0 0.0
    blue = luminance 0.0 0.0 255.0
  expect t "green weighs most, blue least" true (green > red && red > blue)

  expect t "white is light" true (isLightFill "rgb(255, 255, 255)")
  expect t "black is not light" false (isLightFill "rgb(0, 0, 0)")
  expect t "a pale grey is light" true (isLightFill "rgb(200, 200, 200)")
  expect t "a mid grey is not light" false (isLightFill "rgb(128, 128, 128)")
  expect t "a grey just over the threshold is light" true (isLightFill "rgb(159, 159, 159)")
  expect t "a grey just under the threshold is not" false (isLightFill "rgb(158, 158, 158)")
  expect t "pure green reads light, pure red and blue do not"
    [ true, false, false ]
    (map isLightFill [ "rgb(0, 255, 0)", "rgb(255, 0, 0)", "rgb(0, 0, 255)" ])
  expect t "yellow is light" true (isLightFill "rgb(255, 255, 0)")
  expect t "a half-transparent white is still light" true
    (isLightFill "rgba(255, 255, 255, 0.5)")
  expect t "a fully transparent white is not" false (isLightFill "rgba(255, 255, 255, 0)")
  expect t "a fully transparent white written 0.0 is not" false
    (isLightFill "rgba(255, 255, 255, 0.0)")
  expect t "channels without spaces are read" true (isLightFill "rgb(255,255,255)")
  expect t "no fill is not light" false (isLightFill "none")
  expect t "a hex colour is not read" false (isLightFill "#ffffff")
  expect t "a colour with too few channels is not read" false (isLightFill "rgb(255, 255)")
  expect t "space-separated channels are not read" false (isLightFill "rgb(255 255 255)")
  expect t "an empty fill is not light" false (isLightFill "")

  expect t "a bare width becomes pixels" "300px" (svgMaxWidth "300")
  expect t "a bare fractional width becomes pixels" "412.5px" (svgMaxWidth "412.5")
  expect t "a width in points keeps its unit" "300pt" (svgMaxWidth "300pt")
  expect t "a width in ems keeps its unit" "12.5em" (svgMaxWidth "12.5em")
  expect t "a percentage keeps its unit" "100%" (svgMaxWidth "100%")
  expect t "a unit is recognised in any case" "300PX" (svgMaxWidth "300PX")
