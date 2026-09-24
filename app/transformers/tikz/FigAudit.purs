-- | ## FigAudit
-- |
-- | The pure geometry behind the figure dev-tools: `figcheck` (doubled
-- | text, colliding labels, a stroke drawn straight through a label) and
-- | `figlabels` (a label sitting on a dense curve). Both render every
-- | `$$…tikzpicture…$$` block through node-tikzjax and pick the SVG apart;
-- | this module flattens `<path>` data into segments and vertices, finds
-- | the white label backgrounds that hide whatever they sit on, clips
-- | segments against label cores, and turns a figure's text runs into the
-- | flags the tools print. It also builds the render harness's TeX document
-- | and package list, so the auditors lint exactly what `figrender`
-- | rasterises and the site ships.
-- |
-- | The bun shells in `transformers/tikz/` keep node-tikzjax, the BaKoMa
-- | glyph metrics that size each text run, the font-file scan, and the
-- | console. Only those CLIs consume this module. @ts-internal
module App.Transformers.Tikz.FigAudit
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
  ) where

import Prelude

import Control.Monad.ST as ST
import Control.Monad.ST.Ref as STRef
import Data.Array
  ( all
  , any
  , catMaybes
  , concat
  , cons
  , drop
  , filter
  , foldl
  , head
  , index
  , last
  , length
  , mapMaybe
  , mapWithIndex
  , nub
  , null
  , range
  , snoc
  , take
  , zipWith
  )
import Data.Array.NonEmpty as NEA
import Data.Array.ST as STA
import Data.Int (toNumber)
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Number as Number
import Data.String (Pattern(..), contains, joinWith, stripPrefix, toLower, toUpper)
import Data.String.CodeUnits as CU
import Data.String.Regex (Regex, match, test)
import Data.String.Regex.Flags (global, ignoreCase, noFlags)
import Data.String.Regex.Unsafe (unsafeRegex)

foreign import jsNumberImpl :: String -> Number

-- | One `<text>` run with its absolute position and glyph-metric bbox
-- | (`y` is the top edge, `h` the font size), as the shell measures it.
type Run = { x :: Number, y :: Number, w :: Number, h :: Number, t :: String }

-- | One straight piece of a flattened path, from `(x1, y1)` to `(x2, y2)`.
type Seg = { x1 :: Number, y1 :: Number, x2 :: Number, y2 :: Number }

-- | A path vertex.
type Point = { x :: Number, y :: Number }

-- | An axis-aligned box: top-left corner, width, height.
type Box = { x :: Number, y :: Number, w :: Number, h :: Number }

type Cursor =
  { i :: Int
  , cx :: Number
  , cy :: Number
  , sx :: Number
  , sy :: Number
  , cmd :: String
  }

type Step a = { cursor :: Cursor, emit :: Array a }

pathTokens :: Regex
pathTokens = unsafeRegex "[MLHVCSQTAZmlhvcsqtaz]|-?\\d*\\.?\\d+(?:[eE]-?\\d+)?" global

letter :: Regex
letter = unsafeRegex "[a-zA-Z]" noFlags

matches :: Regex -> String -> Array String
matches re s = maybe [] (NEA.toArray >>> catMaybes) (match re s)

capture :: Regex -> String -> Maybe String
capture re s = match re s >>= \groups -> join (NEA.index groups 1)

tokenNumber :: Array String -> Int -> Number
tokenNumber toks k = maybe Number.nan jsNumberImpl (index toks k)

enterCommand :: Array String -> Cursor -> Cursor
enterCommand toks c = case index toks c.i of
  Just tok | test letter tok -> c { i = c.i + 1, cmd = tok }
  _ -> c

walkPath :: forall a. (Array String -> Cursor -> Step a) -> String -> Array a
walkPath step d = STA.run do
  out <- STA.new
  cursor <- STRef.new { i: 0, cx: 0.0, cy: 0.0, sx: 0.0, sy: 0.0, cmd: "" }
  ST.while (map (\c -> c.i < total) (STRef.read cursor)) do
    c <- STRef.read cursor
    let next = step toks c
    _ <- STA.pushAll next.emit out
    STRef.write next.cursor cursor
  pure out
  where
  toks = matches pathTokens d
  total = length toks

-- | `T` reads like `L`, `S` like `Q`; everything else keeps its letter.
commandKind :: String -> String
commandKind cmd = case toUpper cmd of
  "T" -> "L"
  "S" -> "Q"
  kind -> kind

-- | The cubic Bézier through `p0`…`p3` at parameter `t`, in the original
-- | evaluation order.
bezier :: Point -> Point -> Point -> Point -> Number -> Point
bezier p0 p1 p2 p3 t = { x: axis p0.x p1.x p2.x p3.x, y: axis p0.y p1.y p2.y p3.y }
  where
  mt = 1.0 - t
  axis a b c d = mt * mt * mt * a + 3.0 * mt * mt * t * b + 3.0 * mt * t * t * c + t * t * t * d

cubic :: Point -> Point -> Point -> Point -> Array Seg
cubic p0 p1 p2 p3 = zipWith chord (cons p0 samples) samples
  where
  samples = map (\s -> bezier p0 p1 p2 p3 (toNumber s / 8.0)) (range 1 8)
  chord a b = { x1: a.x, y1: a.y, x2: b.x, y2: b.y }

segmentStep :: Array String -> Cursor -> Step Seg
segmentStep toks cursor = case commandKind c.cmd of
  "M" ->
    let
      nx = along c.cx (arg 0)
      ny = along c.cy (arg 1)
    in
      { cursor: c { i = c.i + 2, cx = nx, cy = ny, sx = nx, sy = ny, cmd = moveFollower }
      , emit: []
      }
  "L" -> line 2 (along c.cx (arg 0)) (along c.cy (arg 1))
  "H" -> line 1 (along c.cx (arg 0)) c.cy
  "V" -> line 1 c.cx (along c.cy (arg 0))
  "C" -> curve 6 (arg 0) (arg 1) (arg 2) (arg 3) (arg 4) (arg 5)
  "Q" -> curve 4 (arg 0) (arg 1) (arg 0) (arg 1) (arg 2) (arg 3)
  "A" ->
    { cursor: c { i = c.i + 7, cx = along c.cx (arg 5), cy = along c.cy (arg 6) }
    , emit: []
    }
  "Z" -> line 0 c.sx c.sy
  _ -> { cursor: c { i = c.i + 1 }, emit: [] }
  where
  c = enterCommand toks cursor
  rel = c.cmd == toLower c.cmd
  moveFollower = if rel then "l" else "L"
  arg k = tokenNumber toks (c.i + k)
  along from v = if rel then from + v else v
  line used nx ny =
    { cursor: c { i = c.i + used, cx = nx, cy = ny }
    , emit: [ { x1: c.cx, y1: c.cy, x2: nx, y2: ny } ]
    }
  curve used ax ay bx by x y =
    let
      start = { x: c.cx, y: c.cy }
      control1 = { x: along c.cx ax, y: along c.cy ay }
      control2 = { x: along c.cx bx, y: along c.cy by }
      end = { x: along c.cx x, y: along c.cy y }
    in
      { cursor: c { i = c.i + used, cx = end.x, cy = end.y }
      , emit: cubic start control1 control2 end
      }

-- | Flatten an SVG path `d` into straight segments. Cubic and quadratic
-- | Béziers are subdivided along the actual curve (8 chords; `S` and `Q`
-- | as a cubic with the one control point doubled), so a node-border circle
-- | stays on its perimeter while a bent arrow that arcs over a label is
-- | followed faithfully. An elliptical arc `A` only moves the pen.
-- | Implicit repeats after `M` continue as `L`/`l`; a truncated command
-- | reads `NaN` for its missing numbers.
pathSegments :: String -> Array Seg
pathSegments = walkPath segmentStep

pointStep :: Array String -> Cursor -> Step Point
pointStep toks cursor = case commandKind c.cmd of
  "M" ->
    let
      nx = along c.cx (arg 0)
      ny = along c.cy (arg 1)
      landed = land 2 nx ny
    in
      landed { cursor { sx = nx, sy = ny, cmd = if rel then "l" else "L" } }
  "L" -> land 2 (along c.cx (arg 0)) (along c.cy (arg 1))
  "H" -> land 1 (along c.cx (arg 0)) c.cy
  "V" -> land 1 c.cx (along c.cy (arg 0))
  "C" -> land 6 (along c.cx (arg 4)) (along c.cy (arg 5))
  "Q" -> land 4 (along c.cx (arg 2)) (along c.cy (arg 3))
  "A" -> land 7 (along c.cx (arg 5)) (along c.cy (arg 6))
  "Z" -> land 0 c.sx c.sy
  _ -> { cursor: c { i = c.i + 1 }, emit: [] }
  where
  c = enterCommand toks cursor
  rel = c.cmd == toLower c.cmd
  arg k = tokenNumber toks (c.i + k)
  along from v = if rel then from + v else v
  land used nx ny =
    { cursor: c { i = c.i + used, cx = nx, cy = ny }
    , emit: [ { x: nx, y: ny } ]
    }

-- | Path vertices only — the endpoint of every command, `M` included, with
-- | no Bézier subdivision — so a dense `plot` curve deposits one point per
-- | segment. The label-on-stroke test counts how many land in a label.
pathPoints :: String -> Array Point
pathPoints = walkPath pointStep

type Bounds = { xmin :: Number, ymin :: Number, xmax :: Number, ymax :: Number }

noBounds :: Bounds
noBounds =
  { xmin: Number.infinity
  , ymin: Number.infinity
  , xmax: -Number.infinity
  , ymax: -Number.infinity
  }

segmentBounds :: Array Seg -> Bounds
segmentBounds = foldl grow noBounds
  where
  grow b s =
    { xmin: Number.min (Number.min b.xmin s.x1) s.x2
    , xmax: Number.max (Number.max b.xmax s.x1) s.x2
    , ymin: Number.min (Number.min b.ymin s.y1) s.y2
    , ymax: Number.max (Number.max b.ymax s.y1) s.y2
    }

pointBounds :: Array Point -> Bounds
pointBounds = foldl grow noBounds
  where
  grow b p =
    { xmin: Number.min b.xmin p.x
    , xmax: Number.max b.xmax p.x
    , ymin: Number.min b.ymin p.y
    , ymax: Number.max b.ymax p.y
    }

boundsBox :: Bounds -> Box
boundsBox b = { x: b.xmin, y: b.ymin, w: b.xmax - b.xmin, h: b.ymax - b.ymin }

-- | Does `(px, py)` fall in the box, give or take half a point?
encloses :: Number -> Number -> Box -> Boolean
encloses px py b =
  px >= b.x - 0.5 && px <= b.x + b.w + 0.5 && py >= b.y - 0.5 && py <= b.y + b.h + 0.5

occluderTokens :: Regex
occluderTokens = unsafeRegex occluderSource global

occluderToken :: Regex
occluderToken = unsafeRegex occluderSource noFlags

occluderSource :: String
occluderSource = "<path\\b([^>]*?)/?>|<(g|svg)\\b([^>]*?)(/?)>|</(?:g|svg)>"

fillAttr :: Regex
fillAttr = unsafeRegex "fill=\"([^\"]*)\"" noFlags

dAttr :: Regex
dAttr = unsafeRegex "\\bd=\"([^\"]+)\"" noFlags

pureWhite :: Regex
pureWhite = unsafeRegex "^#f{3}(f{3})?$" ignoreCase

-- | White (`#fff`) fill boxes — typically a `node[fill=white]` label
-- | background drawn over the connector it sits on, so the line is hidden,
-- | not a real overlap. The fill is usually inherited from an ancestor
-- | `<g fill="#fff">`, so it is tracked down the group stack (a
-- | self-closing group pushes nothing; the root `none` is never popped).
-- | A box is kept only when it has width. Light-grey cell shading is drawn
-- | under the arrow, not over it, so only pure white counts.
occluders :: String -> Array Box
occluders svg = (foldl visit { fills: [ "none" ], boxes: [] } (matches occluderTokens svg)).boxes
  where
  visit acc tok = case stripPrefix (Pattern "</") tok of
    Just _ -> acc { fills = if length acc.fills > 1 then drop 1 acc.fills else acc.fills }
    Nothing -> case group 2, capture dAttr (fromMaybe "" (group 1)) of
      Just _, _
        | group 4 == Just "/" -> acc
        | otherwise -> acc { fills = cons (fillOf (group 3)) acc.fills }
      Nothing, Just d
        | test pureWhite (fillOf (group 1)) -> withBox (segmentBounds (pathSegments d))
      _, _ -> acc
    where
    groups = maybe [] NEA.toArray (match occluderToken tok)
    group k = join (index groups k)
    inherited = fromMaybe "none" (head acc.fills)
    fillOf attrs = fromMaybe inherited (capture fillAttr (fromMaybe "" attrs))
    withBox b = if b.xmin < b.xmax then acc { boxes = snoc acc.boxes (boundsBox b) } else acc

type Window = { t0 :: Number, t1 :: Number }

clipEdge :: Number -> Number -> Window -> Maybe Window
clipEdge p q w
  | p == 0.0 = if q < 0.0 then Nothing else Just w
  | p < 0.0 =
      let
        r = q / p
      in
        if r > w.t1 then Nothing else Just (if r > w.t0 then w { t0 = r } else w)
  | otherwise =
      let
        r = q / p
      in
        if r < w.t0 then Nothing else Just (if r < w.t1 then w { t1 = r } else w)

-- | Liang–Barsky: does the segment intersect the axis-aligned box? Edges
-- | are inclusive, so a segment ending on the border counts.
segHitsBox :: Seg -> Box -> Boolean
segHitsBox s b = case window of
  Just w -> w.t0 <= w.t1
  Nothing -> false
  where
  dx = s.x2 - s.x1
  dy = s.y2 - s.y1
  window =
    clipEdge (-dx) (s.x1 - b.x) { t0: 0.0, t1: 1.0 }
      >>= clipEdge dx (b.x + b.w - s.x1)
      >>= clipEdge (-dy) (s.y1 - b.y)
      >>= clipEdge dy (b.y + b.h - s.y1)

-- | The TeX document the render harness hands node-tikzjax: the `\set`
-- | shim, the operator preamble, then the (color-hoisted) picture code.
auditTexSource :: String -> String -> String
auditTexSource preamble code =
  "\\begin{document}\n\\providecommand{\\set}[1]{\\{#1\\}}%\n"
    <> preamble
    <> "\n"
    <> code
    <> "\n\\end{document}"

-- | The TeX packages to load, in order: always `amsmath` and `amssymb`,
-- | then `tikz-cd` for a `tikzcd` diagram and `tikz-3dplot` for `\tdplot…`.
auditTexPackages :: String -> Array String
auditTexPackages code =
  [ "amsmath", "amssymb" ]
    <> (if contains (Pattern "\\begin{tikzcd}") code then [ "tikz-cd" ] else [])
    <> (if contains (Pattern "tdplot") code then [ "tikz-3dplot" ] else [])

pathDataAll :: Regex
pathDataAll = unsafeRegex pathDataSource global

pathDataOne :: Regex
pathDataOne = unsafeRegex pathDataSource noFlags

pathDataSource :: String
pathDataSource = "<path\\b[^>]*\\bd=\"([^\"]+)\""

pathData :: String -> Array String
pathData svg = mapMaybe (capture pathDataOne) (matches pathDataAll svg)

accentMark :: Regex
accentMark = unsafeRegex "^[\\^~¯¹˙´`¨°˜ˆ¸]$" noFlags

data PairVerdict
  = Doubled String
  | Overlap String

pairVerdict :: Run -> Run -> Maybe PairVerdict
pairVerdict a b = verdict
  where
  dx = Number.abs (a.x - b.x)
  dy = Number.abs (a.y - b.y)
  ix = Number.min (a.x + a.w) (b.x + b.w) - Number.max a.x b.x
  iy = Number.min (a.y + a.h) (b.y + b.h) - Number.max a.y b.y
  verdict
    | a.t == b.t = if dx < 2.2 && dy < 2.2 then Just (Doubled a.t) else Nothing
    | dx < 2.0 && dy < 2.0 && CU.length a.t <= 2 && CU.length b.t <= 2 = Nothing
    | dx < 3.0 && (test accentMark a.t || test accentMark b.t) = Nothing
    | ix > 1.2 && iy > 0.35 * Number.min a.h b.h = Just (Overlap (a.t <> "|" <> b.t))
    | otherwise = Nothing

-- | A node/cell border: a closed path of 3–6 axis-aligned segments. Its
-- | bbox lets a label's own frame be told apart from a real line.
closedFrame :: Array Seg -> Maybe Box
closedFrame ps = case head ps, last ps of
  Just first, Just final | closes first final -> Just (boundsBox (segmentBounds ps))
  _, _ -> Nothing
  where
  closes first final =
    length ps >= 3
      && length ps <= 6
      && all axisAligned ps
      && Number.abs (first.x1 - final.x2) < 1.0
      && Number.abs (first.y1 - final.y2) < 1.0
  axisAligned s = Number.abs (s.x1 - s.x2) < 0.6 || Number.abs (s.y1 - s.y2) < 0.6

-- | Is the point within 1.5pt of one of the frame's edges (and alongside
-- | that edge, not off past its end)?
onFrameEdge :: Number -> Number -> Box -> Boolean
onFrameEdge px py f = nearSide && alongSide || nearTopOrBottom && alongTop
  where
  nearSide = Number.abs (px - f.x) < 1.5 || Number.abs (px - f.x - f.w) < 1.5
  alongSide = py >= f.y - 1.5 && py <= f.y + f.h + 1.5
  nearTopOrBottom = Number.abs (py - f.y) < 1.5 || Number.abs (py - f.y - f.h) < 1.5
  alongTop = px >= f.x - 1.5 && px <= f.x + f.w + 1.5

flag :: String -> String -> Array String -> Maybe String
flag name sep items
  | null items = Nothing
  | otherwise = Just (name <> "{" <> joinWith sep items <> "}")

-- | Every flag `figcheck` raises for one rendered figure, in print order:
-- |
-- | - `DOUBLED{…}` — the same text drawn twice at ~the same spot (a
-- |   labelled node re-drawn over itself: bold, ghosted text);
-- | - `MISSING-FONT{…}` — fonts the outliner cannot load (the shell's
-- |   ordered scan, passed through);
-- | - `OVERLAP{…}` — two different labels whose boxes intersect (first 6);
-- | - `LINE-OVER-TEXT{…}` — a stroke passing through a label's core box
-- |   with both ends outside the label, not hidden under a white
-- |   background, and not an edge of the label's own frame (first 8).
figcheckFlags :: { runs :: Array Run, svg :: String, missingFonts :: Array String } -> Array String
figcheckFlags { runs, svg, missingFonts } = catMaybes
  [ flag "DOUBLED" "," (nub (mapMaybe doubledText verdicts))
  , flag "MISSING-FONT" "," missingFonts
  , flag "OVERLAP" " " (take 6 (nub (mapMaybe overlapText verdicts)))
  , flag "LINE-OVER-TEXT" "," (take 8 (nub (mapMaybe lineOverText runs)))
  ]
  where
  verdicts = concat (mapWithIndex (\i a -> mapMaybe (pairVerdict a) (drop (i + 1) runs)) runs)
  doubledText = case _ of
    Doubled t -> Just t
    _ -> Nothing
  overlapText = case _ of
    Overlap pair -> Just pair
    _ -> Nothing
  segSets = map pathSegments (pathData svg)
  segs = concat segSets
  frames = mapMaybe closedFrame segSets
  occ = occluders svg
  lineOverText r =
    if any (encloses cx cy) occ || not (any passesThrough segs) then Nothing else Just r.t
    where
    cx = r.x + r.w / 2.0
    cy = r.y + r.h / 2.0
    bw = Number.max (r.w * 0.55) 1.5
    bh = r.h * 0.55
    core = { x: r.x + (r.w - bw) / 2.0, y: r.y + (r.h - bh) / 2.0, w: bw, h: bh }
    myFrames = filter (encloses cx cy) frames
    onFrame px py = any (onFrameEdge px py) myFrames
    outside px py =
      px < r.x - 1.0 || px > r.x + r.w + 1.0 || py < r.y - 1.0 || py > r.y + r.h + 1.0
    passesThrough s =
      segHitsBox s core
        && outside s.x1 s.y1
        && outside s.x2 s.y2
        && not (onFrame s.x1 s.y1 && onFrame s.x2 s.y2)

-- | Is the box the run's own frame — enclosing it (1pt slack) without
-- | being more than 30pt larger either way?
framesRun :: Run -> Box -> Boolean
framesRun r f =
  f.x <= r.x + 1.0
    && f.y <= r.y + 1.0
    && f.x + f.w >= r.x + r.w - 1.0
    && f.y + f.h >= r.y + r.h - 1.0
    && f.w < r.w + 30.0
    && f.h < r.h + 30.0

-- | `figlabels`' label-on-stroke hits for one rendered figure, as
-- | `text(count)`: a run whose core box (65% × 55%) holds at least 3 path
-- | vertices, unless a white background hides the stroke or the run sits
-- | in its own boxed frame (a 3–6 vertex path whose bbox encloses it,
-- | within 30pt). A dense curve through a label deposits many vertices; a
-- | connector that merely ends there deposits about one.
labelOnStrokeHits :: { runs :: Array Run, svg :: String } -> Array String
labelOnStrokeHits { runs, svg } = mapMaybe labelHit runs
  where
  pointSets = map pathPoints (pathData svg)
  frames = map (pointBounds >>> boundsBox) (filter frameSized pointSets)
  frameSized ps = length ps >= 3 && length ps <= 6
  points = concat pointSets
  occ = occluders svg
  labelHit r =
    if any (encloses cx0 cy0) occ || ownFrame || inside < 3 then Nothing
    else Just (r.t <> "(" <> show inside <> ")")
    where
    cx0 = r.x + r.w / 2.0
    cy0 = r.y + r.h / 2.0
    bw = r.w * 0.65
    bh = r.h * 0.55
    bx = r.x + (r.w - bw) / 2.0
    by = r.y + (r.h - bh) / 2.0
    ownFrame = any (framesRun r) frames
    inside = length (filter inCore points)
    inCore p = p.x >= bx && p.x <= bx + bw && p.y >= by && p.y <= by + bh
