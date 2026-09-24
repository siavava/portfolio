-- | ## Svg
-- |
-- | Pure SVG-string transforms over node-tikzjax output, run after the
-- | text runs are outlined (`outlineText`, which needs the fonts, stays
-- | in `transformers/tikz/svg.ts`): pad the viewBox, route black ink
-- | through `currentColor`, recolour baked-in hex fills and strokes to
-- | theme variables, and inline presentation attributes as `style`.
-- | @ts-internal
module App.Transformers.Tikz.Svg
  ( classifyColor
  , inlineSvgStyles
  , padViewBox
  , postProcessSvg
  , themeBlackInk
  , themeColors
  ) where

import Prelude

import Data.Array (elem, foldl, index, mapWithIndex, snoc)
import Data.Array.NonEmpty as NEA
import Data.Int (hexadecimal, toNumber)
import Data.Int as Int
import Data.Int.Bits (and, shr)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Number (abs, isNaN, remainder)
import Data.Number as Number
import Data.Number.Format (fixed, toString, toStringWith)
import Data.String (Pattern(..), Replacement(..), joinWith)
import Data.String as String
import Data.String.CodeUnits as CU
import Data.String.Regex (Regex, match, replace, replace', split)
import Data.String.Regex.Flags (global, noFlags)
import Data.String.Regex.Unsafe (unsafeRegex)

-- | JS `Number(s)`, not `Data.Number.fromString` (`parseFloat`, which reads `"1.2.3"` as `1.2`).
foreign import jsNumberImpl :: String -> Number

-- | The whole post-processing pass, in the renderer's order: pad the
-- | viewBox by 3 units, theme black ink, theme hex colours, then inline
-- | presentation attributes.
postProcessSvg :: String -> String
postProcessSvg = inlineSvgStyles <<< themeColors <<< themeBlackInk <<< padViewBox 3.0

blackInk :: Regex
blackInk = unsafeRegex "\\b(stroke|fill)=\"(?:#000(?:000)?|black)\"" global

-- | Routes black `stroke`/`fill` (`#000`, `#000000`, `black`) through
-- | `currentColor`, so default ink follows the page's text colour.
themeBlackInk :: String -> String
themeBlackInk = replace blackInk "$1=\"currentColor\""

-- | Classifies one `#rgb`/`#rrggbb` colour as a theme CSS variable, so a
-- | figure stays legible in light and dark mode. node-tikzjax flattens
-- | TikZ colours to hex; the hue picks a bucket (accent, good, warn, hi,
-- | alt, neutral for low saturation) and a luminance above 0.62 picks the
-- | translucent `soft` variant over the solid stroke colour. Pure white
-- | (a label backing that masks the line behind some text) maps to
-- | `--tk-bg`, the figure's surface colour, so it follows the colour mode
-- | instead of staying a glaring white box on a dark background. `Nothing`
-- | for any other length (4 or 5 digits). The first `#` is dropped and the
-- | rest read as hex digits; the original's `parseInt` would also have
-- | read a leading run of hex digits out of a non-hex tail, which the
-- | `#[0-9a-fA-F]{3,6}` pattern feeding this never produces.
classifyColor :: String -> Maybe String
classifyColor hex = do
  n <- if CU.length digits == 6 then Int.fromStringAs hexadecimal digits else Nothing
  pure (classify n)
  where
  stripped = String.replace (Pattern "#") (Replacement "") hex
  digits
    | CU.length stripped == 3 = joinWith "" (map doubled (String.split (Pattern "") stripped))
    | otherwise = stripped
  doubled c = c <> c

classify :: Int -> String
classify n = result
  where
  result
    | maxC > 0.97 && d < 0.02 = "var(--tk-bg)"
    | lum > 0.62 = variable "soft-neutral" ("soft-" <> bucket)
    | otherwise = variable "line" bucket
  variable neutral hued = "var(--tk-" <> (if bucket == "neutral" then neutral else hued) <> ")"
  channel shift = toNumber (and (shr n shift) 255) / 255.0
  r = channel 16
  g = channel 8
  b = channel 0
  maxC = Number.max r (Number.max g b)
  minC = Number.min r (Number.min g b)
  d = maxC - minC
  light = (maxC + minC) / 2.0
  lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
  sat = if d == 0.0 then 0.0 else d / (1.0 - abs (2.0 * light - 1.0))
  sector
    | maxC == r = remainder ((g - b) / d) 6.0
    | maxC == g = (b - r) / d + 2.0
    | otherwise = (r - g) / d + 4.0
  hue = if d == 0.0 then 0.0 else remainder (remainder (sector * 60.0) 360.0 + 360.0) 360.0
  bucket
    | sat < 0.15 = "neutral"
    | hue >= 185.0 && hue < 255.0 = "accent"
    | hue >= 70.0 && hue < 185.0 = "good"
    | hue >= 25.0 && hue < 70.0 = "hi"
    | hue >= 255.0 && hue < 332.0 = "alt"
    | otherwise = "warn"

hexPaint :: Regex
hexPaint = unsafeRegex "\\b(fill|stroke)=\"(#[0-9a-fA-F]{3,6})\"" global

-- | Maps every baked-in hex `fill`/`stroke` to its theme variable (see
-- | `classifyColor`); a colour it cannot classify is left as written.
-- | `currentColor` and `none` never match. The variables (`--tk-*`) are
-- | defined per mode on `.tikz-diagram-rendered svg`.
themeColors :: String -> String
themeColors = replace' hexPaint recolour
  where
  recolour whole = case _ of
    [ Just prop, Just hex ] -> case classifyColor hex of
      Just mapped -> prop <> "=\"" <> mapped <> "\""
      Nothing -> whole
    _ -> whole

cssPresentation :: Array String
cssPresentation =
  [ "stroke-width"
  , "stroke-miterlimit"
  , "stroke-linecap"
  , "stroke-linejoin"
  , "stroke-dasharray"
  , "stroke-dashoffset"
  , "stroke-opacity"
  , "fill-rule"
  , "fill-opacity"
  , "clip-rule"
  ]

openTag :: Regex
openTag = unsafeRegex "<([a-zA-Z][\\w-]*)((?:\\s[^<>]*?)?)(\\s*\\/?)>" global

hyphenatedAttr :: Regex
hyphenatedAttr = unsafeRegex "\\s+([a-z]+(?:-[a-z]+)+)=\"([^\"]*)\"" global

styleAttrCapture :: Regex
styleAttrCapture = unsafeRegex "\\sstyle=\"([^\"]*)\"" noFlags

styleAttr :: Regex
styleAttr = unsafeRegex "\\sstyle=\"[^\"]*\"" noFlags

trailingSemi :: Regex
trailingSemi = unsafeRegex "\\s*;?\\s*$" noFlags

-- | Moves each tag's presentation attributes (`stroke-width`,
-- | `fill-rule`, …) into its inline `style`, merged after any existing
-- | declarations (normalized to end in one `;`). Tags without such
-- | attributes are left byte-for-byte. As in the original, the merged
-- | style is spliced in as a JS replacement string, so a `$&`-style
-- | pattern inside an attribute value is expanded.
inlineSvgStyles :: String -> String
inlineSvgStyles = replace' openTag retag
  where
  retag whole = case _ of
    [ Just tag, Just attrs, Just tail ] | attrs /= "" -> case presentationStyles attrs of
      [] -> whole
      styles ->
        "<" <> tag <> mergeStyle (joinWith ";" styles) (dropPresentation attrs) <> tail <> ">"
    _ -> whole
  dropPresentation = replace' hyphenatedAttr \m groups -> case groups of
    [ Just name, _ ] | name `elem` cssPresentation -> ""
    _ -> m
  mergeStyle decls rest = case match styleAttrCapture rest of
    Just groups ->
      let
        prev = replace trailingSemi ";" (fromMaybe "" (join (NEA.index groups 1)))
      in
        replace styleAttr (" style=\"" <> prev <> decls <> "\"") rest
    Nothing -> rest <> " style=\"" <> decls <> "\""

presentationStyles :: String -> Array String
presentationStyles attrs = foldl keep [] (mapWithIndex { i: _, chunk: _ } chunks)
  where
  chunks = split hyphenatedAttr attrs
  keep acc { i, chunk: name }
    | i `mod` 3 == 1 && name `elem` cssPresentation =
        snoc acc (name <> ":" <> fromMaybe "" (index chunks (i + 1)))
    | otherwise = acc

svgRootTag :: Regex
svgRootTag = unsafeRegex "<svg\\b[^>]*>" noFlags

viewBoxAttr :: Regex
viewBoxAttr =
  unsafeRegex "viewBox=\"(-?[\\d.]+)\\s+(-?[\\d.]+)\\s+(-?[\\d.]+)\\s+(-?[\\d.]+)\"" noFlags

widthAttr :: Regex
widthAttr = unsafeRegex "\\bwidth=\"([\\d.]+)\"" noFlags

heightAttr :: Regex
heightAttr = unsafeRegex "\\bheight=\"([\\d.]+)\"" noFlags

-- | Grows the first `<svg>` tag's viewBox by `pad` on every side, so
-- | strokes on the bounding box are not clipped, and scales its `width`
-- | and `height` attributes by the same factor to keep the drawing's
-- | scale. A tag whose viewBox is missing, or whose viewBox width or
-- | height is not a positive number, is left alone. The explicit `isNaN`
-- | keeps the guard independent of how `>` compiles on `NaN`.
padViewBox :: Number -> String -> String
padViewBox pad = replace' svgRootTag \tag _ -> fromMaybe tag (padded tag)
  where
  padded tag = do
    groups <- match viewBoxAttr tag
    let
      group k = fromMaybe "" (join (NEA.index groups k))
      x = jsNumberImpl (group 1)
      y = jsNumberImpl (group 2)
      w = jsNumberImpl (group 3)
      h = jsNumberImpl (group 4)
      nw = w + 2.0 * pad
      nh = h + 2.0 * pad
      newViewBox = "viewBox=\""
        <> toString (x - pad)
        <> " "
        <> toString (y - pad)
        <> " "
        <> fixed3 nw
        <> " "
        <> fixed3 nh
        <> "\""
    if isNaN w || isNaN h || not (w > 0.0 && h > 0.0) then Nothing
    else Just
      ( tag
          # String.replace (Pattern (group 0)) (Replacement newViewBox)
          # rescale widthAttr "width" (\wd -> wd * nw / w)
          # rescale heightAttr "height" (\ht -> ht * nh / h)
      )
  rescale attr name scaled = replace' attr \_ sizes ->
    name <> "=\"" <> fixed3 (scaled (jsNumberImpl (fromMaybe "" (join (index sizes 0))))) <> "\""
  fixed3 = toStringWith (fixed 3)
