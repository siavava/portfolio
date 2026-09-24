-- | Cases for the pure SVG passes of the build-time TikZ renderer,
-- | recorded from the TypeScript `transformers/tikz/svg.ts` before the
-- | move: the colour classification table (black, white, near-white, each
-- | hue boundary, the soft variants, rejected lengths, uppercase), black
-- | ink, presentation attributes into `style` (including the `$&`
-- | replacement-string quirk), and viewBox padding with `NaN` tokens.
module Test.Transformers.TikzSvg (suite) where

import Prelude

import App.Transformers.Tikz.Svg
  ( classifyColor
  , inlineSvgStyles
  , padViewBox
  , postProcessSvg
  , themeBlackInk
  , themeColors
  )
import Data.Foldable (for_)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Test.Harness (Tally, expect)

type ColorCase = { hex :: String, expected :: Maybe String }

colorCases :: Array ColorCase
colorCases =
  [ { hex: "#000", expected: Just "var(--tk-line)" }
  , { hex: "#000000", expected: Just "var(--tk-line)" }
  , { hex: "#fff", expected: Just "var(--tk-bg)" }
  , { hex: "#ffffff", expected: Just "var(--tk-bg)" }
  , { hex: "#f9f9f9", expected: Just "var(--tk-bg)" }
  , { hex: "#f7f7f7", expected: Just "var(--tk-soft-neutral)" }
  , { hex: "#f5f5f5", expected: Just "var(--tk-soft-neutral)" }
  , { hex: "#808080", expected: Just "var(--tk-line)" }
  , { hex: "#333", expected: Just "var(--tk-line)" }
  , { hex: "#cc5500", expected: Just "var(--tk-hi)" }
  , { hex: "#cc5400", expected: Just "var(--tk-warn)" }
  , { hex: "#556600", expected: Just "var(--tk-good)" }
  , { hex: "#aacc00", expected: Just "var(--tk-soft-good)" }
  , { hex: "#abcc00", expected: Just "var(--tk-soft-hi)" }
  , { hex: "#00bbcc", expected: Just "var(--tk-accent)" }
  , { hex: "#00bccc", expected: Just "var(--tk-good)" }
  , { hex: "#3300cc", expected: Just "var(--tk-alt)" }
  , { hex: "#3200cc", expected: Just "var(--tk-accent)" }
  , { hex: "#ff0077", expected: Just "var(--tk-warn)" }
  , { hex: "#ff0078", expected: Just "var(--tk-alt)" }
  , { hex: "#cc0000", expected: Just "var(--tk-warn)" }
  , { hex: "#00cc00", expected: Just "var(--tk-good)" }
  , { hex: "#0000cc", expected: Just "var(--tk-accent)" }
  , { hex: "#aaffaa", expected: Just "var(--tk-soft-good)" }
  , { hex: "#ffff99", expected: Just "var(--tk-soft-hi)" }
  , { hex: "#99ccff", expected: Just "var(--tk-soft-accent)" }
  , { hex: "#ffaacc", expected: Just "var(--tk-soft-warn)" }
  , { hex: "#ccaaff", expected: Just "var(--tk-soft-alt)" }
  , { hex: "#ff9966", expected: Just "var(--tk-soft-warn)" }
  , { hex: "#FF0000", expected: Just "var(--tk-warn)" }
  , { hex: "#AbC", expected: Just "var(--tk-soft-accent)" }
  , { hex: "#abcd", expected: Nothing }
  , { hex: "#abcde", expected: Nothing }
  , { hex: "#12", expected: Nothing }
  , { hex: "#1234567", expected: Nothing }
  , { hex: "fff", expected: Just "var(--tk-bg)" }
  , { hex: "#f0f", expected: Just "var(--tk-alt)" }
  ]

composite :: String
composite =
  "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"20\" viewBox=\"0 0 40 20\">\n<g stroke=\"#000\" stroke-width=\"0.4\" fill=\"#cc5500\">\n<path d=\"M0 0L1 1\" fill=\"black\" stroke-dasharray=\"2 1\" style=\"opacity:1\"/>\n</g>\n</svg>"

suite :: Tally -> Effect Unit
suite t = do
  for_ colorCases \{ hex, expected } ->
    expect t ("classifyColor " <> hex) expected (classifyColor hex)
  expect t "themeBlackInk: short and long hex, keyword"
    "<path fill=\"currentColor\" stroke=\"currentColor\"/><g stroke=\"currentColor\">"
    (themeBlackInk "<path fill=\"#000\" stroke=\"#000000\"/><g stroke=\"black\">")
  expect t "themeBlackInk: other colours and quoting untouched"
    "<path fill=\"#0000\" stroke='black' fill=\"BLACK\" fill=\"#111\"/>"
    (themeBlackInk "<path fill=\"#0000\" stroke='black' fill=\"BLACK\" fill=\"#111\"/>")
  expect t "themeBlackInk: word boundary after a hyphen"
    "<g data-fill=\"currentColor\" xfill=\"black\">"
    (themeBlackInk "<g data-fill=\"black\" xfill=\"black\">")
  expect t "themeColors: recolours fill and stroke"
    "<path fill=\"var(--tk-hi)\" stroke=\"var(--tk-accent)\"/><rect fill=\"var(--tk-bg)\"/>"
    (themeColors "<path fill=\"#cc5500\" stroke=\"#0000cc\"/><rect fill=\"#ffffff\"/>")
  expect t "themeColors: leaves unclassifiable and non-hex paint"
    "<path fill=\"#abcd\" stroke=\"currentColor\" fill=\"none\" stop-color=\"#ff0000\"/>"
    ( themeColors
        "<path fill=\"#abcd\" stroke=\"currentColor\" fill=\"none\" stop-color=\"#ff0000\"/>"
    )
  expect t "themeColors: three-digit and uppercase"
    "<g fill=\"var(--tk-warn)\" stroke=\"var(--tk-soft-good)\">"
    (themeColors "<g fill=\"#F00\" stroke=\"#aaFFaa\">")
  expect t "inlineSvgStyles: no attributes" "<svg><g></g></svg>"
    (inlineSvgStyles "<svg><g></g></svg>")
  expect t "inlineSvgStyles: self-closing tag"
    "<path d=\"M0 0\" style=\"stroke-width:0.4;fill-rule:evenodd\"/>"
    (inlineSvgStyles "<path d=\"M0 0\" stroke-width=\"0.4\" fill-rule=\"evenodd\"/>")
  expect t "inlineSvgStyles: self-closing with space" "<path style=\"stroke-linecap:round\" />"
    (inlineSvgStyles "<path stroke-linecap=\"round\" />")
  expect t "inlineSvgStyles: non-presentation hyphenated attributes kept"
    "<g data-foo-bar=\"x\" font-size=\"10\" style=\"stroke-linecap:round\">"
    (inlineSvgStyles "<g stroke-linecap=\"round\" data-foo-bar=\"x\" font-size=\"10\">")
  expect t "inlineSvgStyles: only non-presentation attributes"
    "<text font-family=\"cmr10\" font-size=\"10\">x</text>"
    (inlineSvgStyles "<text font-family=\"cmr10\" font-size=\"10\">x</text>")
  expect t "inlineSvgStyles: merge without trailing semicolon"
    "<path style=\"fill:red;stroke-width:2\">"
    (inlineSvgStyles "<path style=\"fill:red\" stroke-width=\"2\">")
  expect t "inlineSvgStyles: merge with trailing semicolon and space"
    "<path style=\"fill:red;stroke-width:2;stroke-opacity:.5\">"
    (inlineSvgStyles "<path style=\"fill:red; \" stroke-width=\"2\" stroke-opacity=\".5\">")
  expect t "inlineSvgStyles: merge into empty style" "<path style=\";clip-rule:nonzero\">"
    (inlineSvgStyles "<path style=\"\" clip-rule=\"nonzero\">")
  expect t "inlineSvgStyles: replacement pattern in a value"
    "<path style=\"a;stroke-dasharray: style=\"a\"\">"
    (inlineSvgStyles "<path stroke-dasharray=\"$&\" style=\"a\">")
  expect t "inlineSvgStyles: dollar patterns in a value" "<path style=\"b;stroke-dasharray:$1 $ \">"
    (inlineSvgStyles "<path stroke-dasharray=\"$1 $$ $'\" style=\"b;\">")
  expect t "inlineSvgStyles: dollar value without style" "<path style=\"stroke-dasharray:$&\">"
    (inlineSvgStyles "<path stroke-dasharray=\"$&\">")
  expect t "inlineSvgStyles: attributes across a newline"
    "<path\n  d=\"M0 0\" style=\"stroke-miterlimit:10\">"
    (inlineSvgStyles "<path\n  stroke-miterlimit=\"10\"\n  d=\"M0 0\">")
  expect t "inlineSvgStyles: closing tags and text untouched"
    "<g style=\"stroke-width:1\"><text x=\"1\">stroke-width=\"3\"</text></g>"
    (inlineSvgStyles "<g stroke-width=\"1\"><text x=\"1\">stroke-width=\"3\"</text></g>")
  expect t "inlineSvgStyles: every presentation attribute"
    "<path style=\"stroke-width:1;stroke-miterlimit:2;stroke-linecap:butt;stroke-linejoin:miter;stroke-dasharray:1 2;stroke-dashoffset:3;stroke-opacity:0.5;fill-rule:nonzero;fill-opacity:0.2;clip-rule:evenodd\"/>"
    ( inlineSvgStyles
        "<path stroke-width=\"1\" stroke-miterlimit=\"2\" stroke-linecap=\"butt\" stroke-linejoin=\"miter\" stroke-dasharray=\"1 2\" stroke-dashoffset=\"3\" stroke-opacity=\"0.5\" fill-rule=\"nonzero\" fill-opacity=\"0.2\" clip-rule=\"evenodd\"/>"
    )
  expect t "padViewBox: normal"
    "<svg width=\"106.000\" height=\"56.000\" viewBox=\"-3 -3 106.000 56.000\"><g/></svg>"
    (padViewBox 3.0 "<svg width=\"100\" height=\"50\" viewBox=\"0 0 100 50\"><g/></svg>")
  expect t "padViewBox: negative origin"
    "<svg viewBox=\"-13.5 -6 26.000 16.000\" width=\"26.000\" height=\"16.000\">"
    (padViewBox 3.0 "<svg viewBox=\"-10.5 -3 20 10\" width=\"20\" height=\"10\">")
  expect t "padViewBox: fractional"
    "<svg width=\"18.345\" height=\"12.789\" viewBox=\"-1.5 -0.75 18.345 12.789\">"
    (padViewBox 3.0 "<svg width=\"12.345\" height=\"6.789\" viewBox=\"1.5 2.25 12.345 6.789\">")
  expect t "padViewBox: unit suffix blocks the size rescale"
    "<svg width=\"12pt\" height=\"6pt\" viewBox=\"-3 -3 18.000 12.000\">"
    (padViewBox 3.0 "<svg width=\"12pt\" height=\"6pt\" viewBox=\"0 0 12 6\">")
  expect t "padViewBox: zero width" "<svg viewBox=\"0 0 0 10\" width=\"0\">"
    (padViewBox 3.0 "<svg viewBox=\"0 0 0 10\" width=\"0\">")
  expect t "padViewBox: negative height" "<svg viewBox=\"0 0 5 -10\">"
    (padViewBox 3.0 "<svg viewBox=\"0 0 5 -10\">")
  expect t "padViewBox: lone dot is NaN" "<svg viewBox=\"0 0 . 10\" width=\"1\">"
    (padViewBox 3.0 "<svg viewBox=\"0 0 . 10\" width=\"1\">")
  expect t "padViewBox: double decimal point is NaN" "<svg viewBox=\"0 0 1.2.3 4\">"
    (padViewBox 3.0 "<svg viewBox=\"0 0 1.2.3 4\">")
  expect t "padViewBox: NaN origin still pads"
    "<svg viewBox=\"NaN NaN 16.000 16.000\" width=\"16.000\" height=\"16.000\">"
    (padViewBox 3.0 "<svg viewBox=\". 1.2.3 10 10\" width=\"10\" height=\"10\">")
  expect t "padViewBox: missing width and height" "<svg viewBox=\"-3 -3 16.000 26.000\">"
    (padViewBox 3.0 "<svg viewBox=\"0 0 10 20\">")
  expect t "padViewBox: no viewBox" "<svg width=\"10\" height=\"10\">"
    (padViewBox 3.0 "<svg width=\"10\" height=\"10\">")
  expect t "padViewBox: only the first svg tag"
    "<svg viewBox=\"-3 -3 16.000 16.000\" width=\"16.000\"><svg viewBox=\"0 0 10 10\" width=\"10\"></svg></svg>"
    ( padViewBox 3.0
        "<svg viewBox=\"0 0 10 10\" width=\"10\"><svg viewBox=\"0 0 10 10\" width=\"10\"></svg></svg>"
    )
  expect t "padViewBox: stroke-width matches width first"
    "<svg stroke-width=\"3.200\" width=\"10\" height=\"16.000\" viewBox=\"-3 -3 16.000 16.000\">"
    (padViewBox 3.0 "<svg stroke-width=\"2\" width=\"10\" height=\"10\" viewBox=\"0 0 10 10\">")
  expect t "padViewBox: tabs between numbers" "<svg viewBox=\"-3 -3 16.000 16.000\">"
    (padViewBox 3.0 "<svg viewBox=\"0\t0  10\n10\">")
  expect t "padViewBox: leading-zero and trailing-dot numbers"
    "<svg viewBox=\"4 -2.5 16.000 10.000\" width=\"16.000\" height=\"10.000\">"
    (padViewBox 3.0 "<svg viewBox=\"007 .5 10. 4\" width=\"10.\" height=\"4\">")
  expect t "padViewBox: zero pad"
    "<svg viewBox=\"1 2 3.000 4.000\" width=\"3.000\" height=\"4.000\">"
    (padViewBox 0.0 "<svg viewBox=\"1 2 3 4\" width=\"3\" height=\"4\">")
  expect t "padViewBox: fractional pad"
    "<svg viewBox=\"-5.5 -5.5 12.000 14.000\" width=\"24.000\" height=\"14.000\">"
    (padViewBox 5.5 "<svg viewBox=\"0 0 1 3\" width=\"2\" height=\"3\">")
  expect t "padViewBox: no svg tag" "<g viewBox=\"0 0 10 10\">"
    (padViewBox 3.0 "<g viewBox=\"0 0 10 10\">")
  expect t "postProcessSvg: the whole pass in order"
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"46.000\" height=\"26.000\" viewBox=\"-3 -3 46.000 26.000\">\n<g stroke=\"currentColor\" fill=\"var(--tk-hi)\" style=\"stroke-width:0.4\">\n<path d=\"M0 0L1 1\" fill=\"currentColor\" style=\"opacity:1;stroke-dasharray:2 1\"/>\n</g>\n</svg>"
    (postProcessSvg composite)
