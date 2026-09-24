-- | Locked-down cases for the figure dev-tools' pure core, recorded from
-- | the original TypeScript (`figsvg`, `figcheck`, `figlabels`): path
-- | flattening and vertex walks (relative/absolute commands, implicit
-- | repeats, exponent tokens, truncated paths reading `NaN`), white-fill
-- | occluders under inherited group fills, Liang–Barsky edge cases, the
-- | render harness's document and packages, and every flag the two audits
-- | raise. Numbers compare through `show` so `NaN` stays assertable.
-- |
-- | The geometry helpers underneath are then specified directly: command
-- | letters fold to the absolute kind the walks switch on, the Bézier
-- | starts and ends on its end points, `encloses` gives half a point of
-- | slack, a label frame is a closed axis-aligned path of 3–6 pieces, a
-- | point sits on a frame only alongside one of its edges, and a run's own
-- | frame encloses it within a point without being 30pt larger.
module Test.Transformers.TikzFigAudit (suite) where

import Prelude

import App.Transformers.Tikz.FigAudit
  ( Box
  , Point
  , Run
  , Seg
  , auditTexPackages
  , auditTexSource
  , bezier
  , closedFrame
  , commandKind
  , encloses
  , figcheckFlags
  , framesRun
  , labelOnStrokeHits
  , occluders
  , onFrameEdge
  , pathPoints
  , pathSegments
  , segHitsBox
  )
import Data.Maybe (Maybe(..))
import Data.Number as Number
import Data.String (joinWith)
import Effect (Effect)
import Test.Harness (Tally, expect)

suite :: Tally -> Effect Unit
suite t = do
  pathSegmentCases t
  pathPointCases t
  occluderCases t
  segHitsBoxCases t
  harnessCases t
  figcheckCases t
  labelOnStrokeCases t
  helperCases t

segText :: Seg -> String
segText s = joinWith "," (map show [ s.x1, s.y1, s.x2, s.y2 ])

pointText :: Point -> String
pointText p = joinWith "," (map show [ p.x, p.y ])

boxText :: Box -> String
boxText b = joinWith "," (map show [ b.x, b.y, b.w, b.h ])

run :: Number -> Number -> Number -> Number -> String -> Run
run x y w h t = { x, y, w, h, t }

seg :: Number -> Number -> Number -> Number -> Seg
seg x1 y1 x2 y2 = { x1, y1, x2, y2 }

unitBox :: Box
unitBox = { x: 0.0, y: 0.0, w: 10.0, h: 10.0 }

pathSegmentCases :: Tally -> Effect Unit
pathSegmentCases t = do
  segs "absolute square closes to its start" "M 0 0 L 10 0 L 10 10 Z"
    [ "0.0,0.0,10.0,0.0", "10.0,0.0,10.0,10.0", "10.0,10.0,0.0,0.0" ]
  segs "relative m/l/h/v/z" "m 1 1 l 2 0 h 3 v 4 z"
    [ "1.0,1.0,3.0,1.0", "3.0,1.0,6.0,1.0", "6.0,1.0,6.0,5.0", "6.0,5.0,1.0,1.0" ]
  segs "absolute H and V" "M 5 5 H 10 V 20" [ "5.0,5.0,10.0,5.0", "10.0,5.0,10.0,20.0" ]
  segs "implicit repeat after M continues as L" "M0 0 10 0 10 10"
    [ "0.0,0.0,10.0,0.0", "10.0,0.0,10.0,10.0" ]
  segs "implicit repeat after m continues as l" "m 1 1 2 2 3 3"
    [ "1.0,1.0,3.0,3.0", "3.0,3.0,6.0,6.0" ]
  segs "implicit repeat of L" "M 0 0 L 1 1 2 2" [ "0.0,0.0,1.0,1.0", "1.0,1.0,2.0,2.0" ]
  segs "Z returns to the current subpath start" "M 0 0 L 5 0 M 10 10 L 15 10 Z"
    [ "0.0,0.0,5.0,0.0", "10.0,10.0,15.0,10.0", "15.0,10.0,10.0,10.0" ]
  segs "relative m after a subpath" "M 0 0 L 5 5 m 1 1 l 1 0 z"
    [ "0.0,0.0,5.0,5.0", "6.0,6.0,7.0,6.0", "7.0,6.0,6.0,6.0" ]
  segs "absolute cubic, 8 chords" "M 0 0 C 0 8 8 8 8 0"
    [ "0.0,0.0,0.34375,2.625"
    , "0.34375,2.625,1.25,4.5"
    , "1.25,4.5,2.53125,5.625"
    , "2.53125,5.625,4.0,6.0"
    , "4.0,6.0,5.46875,5.625"
    , "5.46875,5.625,6.75,4.5"
    , "6.75,4.5,7.65625,2.625"
    , "7.65625,2.625,8.0,0.0"
    ]
  segs "relative cubic" "M 1 1 c 0 8 8 8 8 0"
    [ "1.0,1.0,1.34375,3.625"
    , "1.34375,3.625,2.25,5.5"
    , "2.25,5.5,3.53125,6.625"
    , "3.53125,6.625,5.0,7.0"
    , "5.0,7.0,6.46875,6.625"
    , "6.46875,6.625,7.75,5.5"
    , "7.75,5.5,8.65625,3.625"
    , "8.65625,3.625,9.0,1.0"
    ]
  segs "Q is a cubic with the control point doubled" "M 0 0 Q 4 8 8 0"
    [ "0.0,0.0,1.328125,2.625"
    , "1.328125,2.625,2.375,4.5"
    , "2.375,4.5,3.234375,5.625"
    , "3.234375,5.625,4.0,6.0"
    , "4.0,6.0,4.765625,5.625"
    , "4.765625,5.625,5.625,4.5"
    , "5.625,4.5,6.671875,2.625"
    , "6.671875,2.625,8.0,0.0"
    ]
  segs "relative s" "M 0 0 s 4 8 8 0"
    [ "0.0,0.0,1.328125,2.625"
    , "1.328125,2.625,2.375,4.5"
    , "2.375,4.5,3.234375,5.625"
    , "3.234375,5.625,4.0,6.0"
    , "4.0,6.0,4.765625,5.625"
    , "4.765625,5.625,5.625,4.5"
    , "5.625,4.5,6.671875,2.625"
    , "6.671875,2.625,8.0,0.0"
    ]
  segs "T and t read like L and l" "M 0 0 T 4 4 t 1 1" [ "0.0,0.0,4.0,4.0", "4.0,4.0,5.0,5.0" ]
  segs "arc only moves the pen" "M 0 0 A 5 5 0 0 1 10 0 L 10 10" [ "10.0,0.0,10.0,10.0" ]
  segs "relative arc" "M 1 1 a 5 5 0 0 1 10 0 l 0 5" [ "11.0,1.0,11.0,6.0" ]
  segs "compact tokens, trailing lone number" "M0,0L10-5.5.5"
    [ "0.0,0.0,10.0,-5.5", "10.0,-5.5,0.5,NaN" ]
  segs "exponent operands" "M 1e1 2.5e-1 L 2E2 0" [ "10.0,0.25,200.0,0.0" ]
  segs "exponent at a command slot acts as an unknown command" "M 0 0 L 1 1 1e1 5 2 2 L 3 3"
    [ "0.0,0.0,1.0,1.0", "1.0,1.0,3.0,3.0" ]
  segs "leading numbers skipped one by one" "5 6 M 0 0 L 1 1" [ "0.0,0.0,1.0,1.0" ]
  segs "truncated L reads NaN" "M 0 0 L 5" [ "0.0,0.0,5.0,NaN" ]
  segs "truncated M swallows the next command letter" "M 3 L 1 1" [ "3.0,NaN,1.0,1.0" ]
  segs "truncated cubic" "M 0 0 C 1 1 2 2"
    [ "0.0,0.0,NaN,NaN"
    , "NaN,NaN,NaN,NaN"
    , "NaN,NaN,NaN,NaN"
    , "NaN,NaN,NaN,NaN"
    , "NaN,NaN,NaN,NaN"
    , "NaN,NaN,NaN,NaN"
    , "NaN,NaN,NaN,NaN"
    , "NaN,NaN,NaN,NaN"
    ]
  segs "lone Z closes at the origin" "Z" [ "0.0,0.0,0.0,0.0" ]
  segs "empty path" "" []
  segs "no tokens" "none" []
  where
  segs label d expected =
    expect t ("pathSegments: " <> label) expected (map segText (pathSegments d))

pathPointCases :: Tally -> Effect Unit
pathPointCases t = do
  points "absolute square closes to its start" "M 0 0 L 10 0 L 10 10 Z"
    [ "0.0,0.0", "10.0,0.0", "10.0,10.0", "0.0,0.0" ]
  points "relative m/l/h/v/z" "m 1 1 l 2 0 h 3 v 4 z"
    [ "1.0,1.0", "3.0,1.0", "6.0,1.0", "6.0,5.0", "1.0,1.0" ]
  points "absolute H and V" "M 5 5 H 10 V 20" [ "5.0,5.0", "10.0,5.0", "10.0,20.0" ]
  points "implicit repeat after M continues as L" "M0 0 10 0 10 10"
    [ "0.0,0.0", "10.0,0.0", "10.0,10.0" ]
  points "implicit repeat after m continues as l" "m 1 1 2 2 3 3"
    [ "1.0,1.0", "3.0,3.0", "6.0,6.0" ]
  points "implicit repeat of L" "M 0 0 L 1 1 2 2" [ "0.0,0.0", "1.0,1.0", "2.0,2.0" ]
  points "Z returns to the current subpath start" "M 0 0 L 5 0 M 10 10 L 15 10 Z"
    [ "0.0,0.0", "5.0,0.0", "10.0,10.0", "15.0,10.0", "10.0,10.0" ]
  points "relative m after a subpath" "M 0 0 L 5 5 m 1 1 l 1 0 z"
    [ "0.0,0.0", "5.0,5.0", "6.0,6.0", "7.0,6.0", "6.0,6.0" ]
  points "absolute cubic, 8 chords" "M 0 0 C 0 8 8 8 8 0" [ "0.0,0.0", "8.0,0.0" ]
  points "relative cubic" "M 1 1 c 0 8 8 8 8 0" [ "1.0,1.0", "9.0,1.0" ]
  points "Q is a cubic with the control point doubled" "M 0 0 Q 4 8 8 0" [ "0.0,0.0", "8.0,0.0" ]
  points "relative s" "M 0 0 s 4 8 8 0" [ "0.0,0.0", "8.0,0.0" ]
  points "T and t read like L and l" "M 0 0 T 4 4 t 1 1" [ "0.0,0.0", "4.0,4.0", "5.0,5.0" ]
  points "arc only moves the pen" "M 0 0 A 5 5 0 0 1 10 0 L 10 10"
    [ "0.0,0.0", "10.0,0.0", "10.0,10.0" ]
  points "relative arc" "M 1 1 a 5 5 0 0 1 10 0 l 0 5" [ "1.0,1.0", "11.0,1.0", "11.0,6.0" ]
  points "compact tokens, trailing lone number" "M0,0L10-5.5.5"
    [ "0.0,0.0", "10.0,-5.5", "0.5,NaN" ]
  points "exponent operands" "M 1e1 2.5e-1 L 2E2 0" [ "10.0,0.25", "200.0,0.0" ]
  points "exponent at a command slot acts as an unknown command" "M 0 0 L 1 1 1e1 5 2 2 L 3 3"
    [ "0.0,0.0", "1.0,1.0", "3.0,3.0" ]
  points "leading numbers skipped one by one" "5 6 M 0 0 L 1 1" [ "0.0,0.0", "1.0,1.0" ]
  points "truncated L reads NaN" "M 0 0 L 5" [ "0.0,0.0", "5.0,NaN" ]
  points "truncated M swallows the next command letter" "M 3 L 1 1" [ "3.0,NaN", "1.0,1.0" ]
  points "truncated cubic" "M 0 0 C 1 1 2 2" [ "0.0,0.0", "NaN,NaN" ]
  points "lone Z closes at the origin" "Z" [ "0.0,0.0" ]
  points "empty path" "" []
  points "no tokens" "none" []
  where
  points label d expected =
    expect t ("pathPoints: " <> label) expected (map pointText (pathPoints d))

occluderCases :: Tally -> Effect Unit
occluderCases t = do
  boxes "fill inherited from a white group"
    "<svg><g fill=\"#fff\"><path d=\"M 0 0 L 10 0 L 10 5 L 0 5 Z\"/></g></svg>"
    [ "0.0,0.0,10.0,5.0" ]
  boxes "own #FFFFFF fill, any case"
    "<path fill=\"#FFFFFF\" d=\"M 1 1 H 4 V 3 H 1 Z\"/>"
    [ "1.0,1.0,3.0,2.0" ]
  boxes "four fs are not white" "<path fill=\"#ffff\" d=\"M 0 0 L 1 1\"/>" []
  boxes "own fill overrides the group"
    "<g fill=\"#fff\"><path fill=\"none\" d=\"M 0 0 L 9 9\"/></g>"
    []
  boxes "self-closing group pushes nothing" "<g fill=\"#fff\"/><path d=\"M 0 0 L 9 9\"/>" []
  boxes "nested plain group inherits"
    "<g fill=\"#fff\"><g stroke=\"red\"><path d=\"M 0 0 L 4 2\"/></g></g>"
    [ "0.0,0.0,4.0,2.0" ]
  boxes "closing tag pops back to the parent fill"
    "<g fill=\"#fff\"></g><path d=\"M 0 0 L 4 2\"/>"
    []
  boxes "stray closings never pop the root"
    "</g></g><g fill=\"#fff\"><path d=\"M 0 0 L 3 3\"/></g>"
    [ "0.0,0.0,3.0,3.0" ]
  boxes "zero-width box dropped" "<g fill=\"#fff\"><path d=\"M 5 0 V 10\"/></g>" []
  boxes "svg root fill counts as a group"
    "<svg fill=\"#fff\"><path d=\"M 0 0 L 2 2\"/></svg>"
    [ "0.0,0.0,2.0,2.0" ]
  boxes "empty own fill is not inherited"
    "<g fill=\"#fff\"><path fill=\"\" d=\"M 0 0 L 2 2\"/></g>"
    []
  boxes "path without d" "<g fill=\"#fff\"><path x=\"1\"/></g>" []
  boxes "curved background bounds its subdivided chords"
    "<g fill=\"#fff\"><path d=\"M 0 0 C 0 8 8 8 8 0\"/></g>"
    [ "0.0,0.0,8.0,6.0" ]
  boxes "NaN coordinate poisons the bounds"
    "<g fill=\"#fff\"><path d=\"M 0 0 L 5\"/></g>"
    [ "0.0,NaN,5.0,NaN" ]
  boxes "several boxes in document order"
    "<g fill=\"#fff\"><path d=\"M 0 0 H 2 V 2\"/><path d=\"M 10 10 H 13 V 14\"/></g><path fill=\"#fff\" d=\"M 20 20 L 21 25\"/>"
    [ "0.0,0.0,2.0,2.0", "10.0,10.0,3.0,4.0", "20.0,20.0,1.0,5.0" ]
  where
  boxes label svg expected =
    expect t ("occluders: " <> label) expected (map boxText (occluders svg))

segHitsBoxCases :: Tally -> Effect Unit
segHitsBoxCases t = do
  hits "crossing horizontally" true (seg (-5.0) 5.0 15.0 5.0)
  hits "reversed direction" true (seg 15.0 5.0 (-5.0) 5.0)
  hits "missing above" false (seg (-5.0) (-5.0) 15.0 (-5.0))
  hits "parallel inside" true (seg 2.0 5.0 8.0 5.0)
  hits "parallel outside" false (seg (-1.0) (-5.0) (-1.0) 15.0)
  hits "ending on the edge" true (seg (-5.0) 5.0 0.0 5.0)
  hits "stopping short of the edge" false (seg (-5.0) 5.0 (-0.1) 5.0)
  hits "touching the corner diagonally" true (seg (-5.0) 5.0 5.0 (-5.0))
  hits "cutting the corner" true (seg (-2.0) 3.0 3.0 (-2.0))
  hits "passing outside the corner" false (seg (-5.0) 4.0 4.0 (-5.0))
  hits "vertical through" true (seg 5.0 (-20.0) 5.0 20.0)
  hits "degenerate point inside" true (seg 3.0 3.0 3.0 3.0)
  hits "degenerate point outside" false (seg 11.0 3.0 11.0 3.0)
  hits "NaN endpoint slips through" true (seg Number.nan 5.0 15.0 5.0)
  where
  hits label expected s = expect t ("segHitsBox: " <> label) expected (segHitsBox s unitBox)

harnessCases :: Tally -> Effect Unit
harnessCases t = do
  packages "plain picture" code1 [ "amsmath", "amssymb" ]
  source "plain picture" code1 doc1
  packages "tikzcd diagram" code2 [ "amsmath", "amssymb", "tikz-cd" ]
  source "tikzcd diagram" code2 doc2
  packages "3-D setup" code3 [ "amsmath", "amssymb", "tikz-3dplot" ]
  source "3-D setup" code3 doc3
  packages "both" code4 [ "amsmath", "amssymb", "tikz-cd", "tikz-3dplot" ]
  source "both" code4 doc4
  where
  packages label code expected =
    expect t ("auditTexPackages: " <> label) expected (auditTexPackages code)
  source label code expected =
    expect t ("auditTexSource: " <> label) expected (auditTexSource operatorPreamble code)

operatorPreamble :: String
operatorPreamble = "\\providecommand{\\OPT}{\\operatorname{OPT}}%"

code1 :: String
code1 = "\\begin{tikzpicture}\\draw (0,0) -- (1,1);\\end{tikzpicture}"

doc1 :: String
doc1 =
  "\\begin{document}\n\\providecommand{\\set}[1]{\\{#1\\}}%\n\\providecommand{\\OPT}{\\operatorname{OPT}}%\n\\begin{tikzpicture}\\draw (0,0) -- (1,1);\\end{tikzpicture}\n\\end{document}"

code2 :: String
code2 = "\\begin{tikzcd} A \\arrow[r] & B \\end{tikzcd}"

doc2 :: String
doc2 =
  "\\begin{document}\n\\providecommand{\\set}[1]{\\{#1\\}}%\n\\providecommand{\\OPT}{\\operatorname{OPT}}%\n\\begin{tikzcd} A \\arrow[r] & B \\end{tikzcd}\n\\end{document}"

code3 :: String
code3 = "\\tdplotsetmaincoords{60}{110}\n\\begin{tikzpicture}[tdplot_main_coords]\\end{tikzpicture}"

doc3 :: String
doc3 =
  "\\begin{document}\n\\providecommand{\\set}[1]{\\{#1\\}}%\n\\providecommand{\\OPT}{\\operatorname{OPT}}%\n\\tdplotsetmaincoords{60}{110}\n\\begin{tikzpicture}[tdplot_main_coords]\\end{tikzpicture}\n\\end{document}"

code4 :: String
code4 = "\\tdplotsetmaincoords{60}{110}\\begin{tikzcd}\\end{tikzcd}"

doc4 :: String
doc4 =
  "\\begin{document}\n\\providecommand{\\set}[1]{\\{#1\\}}%\n\\providecommand{\\OPT}{\\operatorname{OPT}}%\n\\tdplotsetmaincoords{60}{110}\\begin{tikzcd}\\end{tikzcd}\n\\end{document}"

figcheckCases :: Tally -> Effect Unit
figcheckCases t = do
  check "nothing to report" { runs: [], svg: "", missingFonts: [] } []
  check "doubled text, deduplicated"
    { runs:
        [ run 0.0 0.0 5.0 10.0 "x"
        , run 1.0 1.0 5.0 10.0 "x"
        , run 2.0 0.0 5.0 10.0 "x"
        , run 40.0 0.0 5.0 10.0 "y"
        , run 42.0 2.0 5.0 10.0 "y"
        ]
    , svg: ""
    , missingFonts: []
    }
    [ "DOUBLED{x,y}" ]
  check "same text further apart is neither doubled nor overlap"
    { runs: [ run 0.0 0.0 20.0 10.0 "x", run 3.0 0.0 20.0 10.0 "x" ], svg: "", missingFonts: [] }
    []
  check "just past the doubled radius"
    { runs: [ run 0.0 0.0 5.0 10.0 "x", run 2.2 0.0 5.0 10.0 "x" ], svg: "", missingFonts: [] }
    []
  check "overstruck composite exempt"
    { runs: [ run 0.0 0.0 5.0 10.0 "6", run 1.0 1.0 5.0 10.0 "=" ], svg: "", missingFonts: [] }
    []
  check "overstruck needs both runs short"
    { runs: [ run 0.0 0.0 10.0 10.0 "66", run 1.0 1.0 10.0 10.0 "abc" ], svg: "", missingFonts: [] }
    [ "OVERLAP{66|abc}" ]
  check "accent over its base exempt"
    { runs:
        [ run 0.0 0.0 5.0 10.0 "~"
        , run 2.5 (-3.0) 5.0 10.0 "a"
        , run 20.0 0.0 4.0 10.0 "¯"
        , run 22.0 2.0 15.0 10.0 "xyz"
        ]
    , svg: ""
    , missingFonts: []
    }
    []
  check "accent a column away collides"
    { runs: [ run 0.0 0.0 5.0 10.0 "^", run 3.0 0.0 5.0 10.0 "b" ], svg: "", missingFonts: [] }
    [ "OVERLAP{^|b}" ]
  check "overlap needs more than 1.2pt across"
    { runs: [ run 0.0 0.0 11.2 10.0 "ab", run 10.0 0.0 10.0 10.0 "cd" ], svg: "", missingFonts: [] }
    []
  check "overlap needs 35% of the shorter height"
    { runs:
        [ run 0.0 0.0 20.0 10.0 "left"
        , run 10.0 6.5 20.0 10.0 "right"
        , run 40.0 0.0 20.0 10.0 "up"
        , run 50.0 6.0 20.0 8.0 "down"
        ]
    , svg: ""
    , missingFonts: []
    }
    [ "OVERLAP{up|down}" ]
  check "first 6 overlaps"
    { runs:
        [ run 0.0 0.0 20.0 10.0 "a"
        , run 3.0 0.0 20.0 10.0 "b"
        , run 6.0 0.0 20.0 10.0 "c"
        , run 9.0 0.0 20.0 10.0 "d"
        , run 12.0 0.0 20.0 10.0 "e"
        , run 15.0 0.0 20.0 10.0 "f"
        , run 18.0 0.0 20.0 10.0 "g"
        , run 21.0 0.0 20.0 10.0 "h"
        ]
    , svg: ""
    , missingFonts: []
    }
    [ "OVERLAP{a|b a|c a|d a|e a|f a|g}" ]
  check "overlaps deduplicated"
    { runs:
        [ run 0.0 0.0 20.0 10.0 "a"
        , run 3.0 0.0 20.0 10.0 "b"
        , run 40.0 0.0 20.0 10.0 "a"
        , run 43.0 0.0 20.0 10.0 "b"
        ]
    , svg: ""
    , missingFonts: []
    }
    [ "OVERLAP{a|b}" ]
  check "missing fonts pass through in order"
    { runs: [], svg: "", missingFonts: [ "cmfoo10", "cmbar7" ] }
    [ "MISSING-FONT{cmfoo10,cmbar7}" ]
  check "stroke through a label"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ], svg: "<path d=\"M 0 15 L 40 15\"/>", missingFonts: [] }
    [ "LINE-OVER-TEXT{A}" ]
  check "connector ending at the label"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ], svg: "<path d=\"M 0 15 L 15 15\"/>", missingFonts: [] }
    []
  check "white background hides the stroke"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ]
    , svg:
        "<g fill=\"#fff\"><path d=\"M 8 8 L 22 8 L 22 22 L 8 22 Z\"/></g><path d=\"M 0 15 L 40 15\"/>"
    , missingFonts: []
    }
    []
  check "segment between the label's own frame edges"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ]
    , svg: "<path d=\"M 5 5 L 25 5 L 25 25 L 5 25 Z\"/><path d=\"M 5 15 L 25 15\"/>"
    , missingFonts: []
    }
    []
  check "same segment without the frame"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ], svg: "<path d=\"M 5 15 L 25 15\"/>", missingFonts: [] }
    [ "LINE-OVER-TEXT{A}" ]
  check "stroke running past the frame"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ]
    , svg: "<path d=\"M 5 5 L 25 5 L 25 25 L 5 25 Z\"/><path d=\"M 0 15 L 30 15\"/>"
    , missingFonts: []
    }
    [ "LINE-OVER-TEXT{A}" ]
  check "open three-sided path is no frame"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ]
    , svg: "<path d=\"M 5 5 L 25 5 L 25 25 L 5 25\"/><path d=\"M 5 15 L 25 15\"/>"
    , missingFonts: []
    }
    [ "LINE-OVER-TEXT{A}" ]
  check "curve arcing clear of the label core"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ]
    , svg: "<path d=\"M 0 30 C 5 0 25 0 30 30\"/>"
    , missingFonts: []
    }
    []
  check "curved stroke through a label"
    { runs: [ run (-18.0) 11.4 10.0 10.0 "A" ]
    , svg: "<path d=\"M -185 60 C -85 0 115 0 215 60\"/>"
    , missingFonts: []
    }
    [ "LINE-OVER-TEXT{A}" ]
  check "first 8 line hits, deduplicated"
    { runs:
        [ run 0.0 10.0 10.0 10.0 "p0"
        , run 20.0 10.0 10.0 10.0 "p1"
        , run 40.0 10.0 10.0 10.0 "p1"
        , run 60.0 10.0 10.0 10.0 "p2"
        , run 80.0 10.0 10.0 10.0 "p3"
        , run 100.0 10.0 10.0 10.0 "p4"
        , run 120.0 10.0 10.0 10.0 "p5"
        , run 140.0 10.0 10.0 10.0 "p6"
        , run 160.0 10.0 10.0 10.0 "p7"
        , run 180.0 10.0 10.0 10.0 "p8"
        ]
    , svg: "<path d=\"M -10 15 L 300 15\"/>"
    , missingFonts: []
    }
    [ "LINE-OVER-TEXT{p0,p1,p2,p3,p4,p5,p6,p7}" ]
  check "every flag, in order"
    { runs:
        [ run 0.0 0.0 5.0 10.0 "x"
        , run 1.0 0.0 5.0 10.0 "x"
        , run 30.0 0.0 20.0 10.0 "foo"
        , run 40.0 2.0 20.0 10.0 "bar"
        , run 100.0 100.0 10.0 10.0 "L"
        ]
    , svg: "<path d=\"M 90 105 L 130 105\"/>"
    , missingFonts: [ "cmxx10" ]
    }
    [ "DOUBLED{x}", "MISSING-FONT{cmxx10}", "OVERLAP{foo|bar}", "LINE-OVER-TEXT{L}" ]
  where
  check label input expected =
    expect t ("figcheckFlags: " <> label) expected (figcheckFlags input)

labelOnStrokeCases :: Tally -> Effect Unit
labelOnStrokeCases t = do
  hitsOf "dense stroke through a label"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ], svg: "<path d=\"M 12 13 L 13 14 L 14 15 L 15 16\"/>" }
    [ "A(4)" ]
  hitsOf "two vertices are not enough"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ], svg: "<path d=\"M 12 13 L 13 14 L 100 100\"/>" }
    []
  hitsOf "vertices count across paths"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ]
    , svg: "<path d=\"M 12 13 L 13 14\"/><path d=\"M 14 15 L 50 50\"/>"
    }
    [ "A(3)" ]
  hitsOf "white background hides the stroke"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ]
    , svg:
        "<g fill=\"#fff\"><path d=\"M 9 9 H 21 V 21 H 9 Z\"/></g><path d=\"M 12 13 L 13 14 L 14 15 L 15 16\"/>"
    }
    []
  hitsOf "the label's own frame"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ]
    , svg: "<path d=\"M 9 9 L 21 9 L 15 15 L 14 14 L 16 16 L 9 21\"/>"
    }
    []
  hitsOf "seven vertices are no frame"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ]
    , svg: "<path d=\"M 9 9 L 21 9 L 15 15 L 14 14 L 16 16 L 9 21 L 100 100\"/>"
    }
    [ "A(3)" ]
  hitsOf "a frame 30pt larger is not the label's own"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ]
    , svg: "<path d=\"M 0 0 L 60 0 L 15 15 L 14 14 L 16 16\"/>"
    }
    [ "A(3)" ]
  hitsOf "core box edges are inclusive"
    { runs: [ run 10.0 10.0 10.0 10.0 "A" ]
    , svg: "<path d=\"M 11.75 12.25 L 18.25 17.75 L 11.75 17.75 L 50 50 L 60 60 L 70 70 L 80 80\"/>"
    }
    [ "A(3)" ]
  hitsOf "every hit in run order"
    { runs:
        [ run 10.0 10.0 10.0 10.0 "A", run 100.0 100.0 10.0 10.0 "B", run 200.0 10.0 10.0 10.0 "C" ]
    , svg:
        "<path d=\"M 12 13 L 12.5 13.4 L 13 13.8 L 13.5 14.2 L 14 14.6 L 14.5 15 L 15 15.4 L 15.5 15.8 L 16 16.2 L 16.5 16.6 L 17 17 L 17.5 17.4\"/><path d=\"M 202 13 L 203 14 L 204 15 L 900 900 L 901 901 L 902 902 L 903 903\"/>"
    }
    [ "A(12)", "C(3)" ]
  where
  hitsOf label input expected =
    expect t ("labelOnStrokeHits: " <> label) expected (labelOnStrokeHits input)

helperCases :: Tally -> Effect Unit
helperCases t = do
  expect t "commandKind: T reads as L and S as Q, either case" [ "L", "L", "Q", "Q" ]
    (map commandKind [ "T", "t", "S", "s" ])
  expect t "commandKind: other letters fold to their absolute form" [ "M", "C", "Z", "A" ]
    (map commandKind [ "m", "c", "z", "A" ])
  expect t "commandKind: no command yet stays empty" "" (commandKind "")

  expect t "bezier: starts on its first point" "0.0,0.0" (pointText (arch 0.0))
  expect t "bezier: ends on its last point" "10.0,0.0" (pointText (arch 1.0))
  expect t "bezier: a symmetric arch peaks midway, three quarters up" "5.0,7.5"
    (pointText (arch 0.5))
  expect t "bezier: evenly spaced collinear controls trace the straight line" "4.5,0.0"
    ( pointText
        (bezier { x: 0.0, y: 0.0 } { x: 3.0, y: 0.0 } { x: 6.0, y: 0.0 } { x: 9.0, y: 0.0 } 0.5)
    )

  expect t "encloses: half a point of slack past each edge" [ true, true, true, true ]
    ( map (\p -> encloses p.x p.y unitBox)
        [ pt 10.5 5.0, pt (-0.5) 5.0, pt 5.0 10.5, pt 5.0 (-0.5) ]
    )
  expect t "encloses: anything further out is outside" [ false, false ]
    (map (\p -> encloses p.x p.y unitBox) [ pt 10.6 5.0, pt 5.0 (-0.51) ])

  expect t "closedFrame: a closed rectangle is a frame" (Just "0.0,0.0,20.0,10.0")
    (boxText <$> frameOf "M 0 0 L 20 0 L 20 10 L 0 10 Z")
  expect t "closedFrame: a path ending within a point of its start still closes"
    (Just "0.0,0.0,20.0,10.0")
    (boxText <$> frameOf "M 0 0 L 20 0 L 20 10 L 0.5 10 L 0.5 0.5")
  expect t "closedFrame: a diagonal side is not a frame" Nothing
    (boxText <$> frameOf "M 0 0 L 10 0 L 0 10 Z")
  expect t "closedFrame: an open three-sided path is not a frame" Nothing
    (boxText <$> frameOf "M 0 0 L 20 0 L 20 10 L 0 10")
  expect t "closedFrame: two pieces are too few" Nothing (boxText <$> frameOf "M 0 0 H 10 H 0")
  expect t "closedFrame: seven pieces are too many" Nothing
    (boxText <$> frameOf "M 0 0 H 2 H 4 H 6 V 2 H 0 V 1 Z")
  expect t "closedFrame: nothing drawn, no frame" Nothing (boxText <$> closedFrame [])

  expect t "onFrameEdge: beside a side edge, along its length" true (onFrameEdge 0.5 5.0 frame)
  expect t "onFrameEdge: beside the top edge, along its length" true (onFrameEdge 10.0 1.0 frame)
  expect t "onFrameEdge: beside the bottom edge" true (onFrameEdge 10.0 9.0 frame)
  expect t "onFrameEdge: just past a corner still counts" true (onFrameEdge (-1.4) (-1.4) frame)
  expect t "onFrameEdge: the middle of the frame is off its edges" false
    (onFrameEdge 10.0 5.0 frame)
  expect t "onFrameEdge: in line with a side but past its end" false (onFrameEdge 0.5 15.0 frame)
  expect t "onFrameEdge: in line with the top but past its end" false (onFrameEdge 25.0 0.0 frame)

  expect t "framesRun: a snug frame around the run" true
    (framesRun label { x: 9.0, y: 9.0, w: 22.0, h: 10.0 })
  expect t "framesRun: a frame a point inside the run's edges still frames it" true
    (framesRun label { x: 11.0, y: 11.0, w: 18.0, h: 6.0 })
  expect t "framesRun: a frame 30pt wider is a container, not the run's frame" false
    (framesRun label { x: 0.0, y: 9.0, w: 50.0, h: 10.0 })
  expect t "framesRun: a frame 30pt taller is a container, not the run's frame" false
    (framesRun label { x: 9.0, y: 0.0, w: 22.0, h: 38.0 })
  expect t "framesRun: a frame beside the run does not frame it" false
    (framesRun label { x: 40.0, y: 10.0, w: 20.0, h: 8.0 })
  where
  arch = bezier { x: 0.0, y: 0.0 } { x: 0.0, y: 10.0 } { x: 10.0, y: 10.0 } { x: 10.0, y: 0.0 }
  pt x y = { x, y }
  frameOf d = closedFrame (pathSegments d)
  frame = { x: 0.0, y: 0.0, w: 20.0, h: 10.0 }
  label = run 10.0 10.0 20.0 8.0 "label"
