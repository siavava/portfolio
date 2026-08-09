-- | ## InterestLayout
-- |
-- | Polar layout for the interest map on a 936×792 canvas, ported from
-- | TypeScript: branch slices fan around the upper half, children band
-- | outward in three rings, grandchildren and leaves drift off their
-- | parents' angles, and prerequisite links thread between placed nodes.
-- | Entirely pure — the hand shim `useInterestLayout.ts` only restores the
-- | original name and default scale.
module App.Composables.Map.InterestLayout
  ( BranchIn
  , ChildIn
  , GrandchildIn
  , LayoutOut
  , LeafIn
  , LinkOut
  , NodeOut
  , interestLayoutJs
  ) where

import Prelude

import Data.Array (concat, find, foldl, index, length, mapWithIndex, snoc)
import Data.Function.Uncurried (Fn2, mkFn2)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.Number (cos, pi, sin)

baseWidth :: Number
baseWidth = 936.0

baseHeight :: Number
baseHeight = 792.0

ringRadii :: Array Number
ringRadii = [ 117.0, 234.0, 351.0, 468.0 ]

branchRadii :: Array Int
branchRadii = [ 168, 150, 205, 130, 100, 175, 190, 162 ]

minAngle :: Number
minAngle = 6.0

maxAngle :: Number
maxAngle = 174.0

sliceGutter :: Number
sliceGutter = 3.5

bandBases :: Array Int
bandBases = [ 258, 314, 364 ]

bandSteps :: Array Int
bandSteps = [ 28, 26, 22 ]

outerCap :: Int
outerCap = 408

edgeBias :: Number
edgeBias = 0.12

-- Fixed-depth mirror of InterestBranch/InterestNode: the original layout
-- only ever descends four levels, and absent JS keys read as null.
type LeafIn = { label :: String, requires :: Nullable (Array String) }
type GrandchildIn =
  { label :: String, requires :: Nullable (Array String), children :: Nullable (Array LeafIn) }

type ChildIn =
  { label :: String
  , requires :: Nullable (Array String)
  , children :: Nullable (Array GrandchildIn)
  }

type BranchIn = { label :: String, color :: String, children :: Array ChildIn }

type NodeOut =
  { id :: String
  , label :: String
  , level :: Int
  , branch :: String
  , color :: String
  , labelSide :: Nullable String
  , x :: Number
  , y :: Number
  }

type LinkOut =
  { id :: String
  , source :: Nullable String
  , target :: String
  , branch :: String
  , color :: String
  , prereq :: Nullable Boolean
  , x1 :: Number
  , y1 :: Number
  , x2 :: Number
  , y2 :: Number
  }

type LayoutOut =
  { width :: Number
  , height :: Number
  , cx :: Number
  , cy :: Number
  , rings :: Array Number
  , nodes :: Array NodeOut
  , links :: Array LinkOut
  }

toRadians :: Number -> Number
toRadians degrees = degrees * pi / 180.0

childRadius :: Int -> Int -> Int -> Int
childRadius band bandIndex branchIndex =
  let
    radius = fromMaybe 0 (index bandBases band)
      + bandIndex * fromMaybe 0 (index bandSteps band)
      + (branchIndex * 5) `mod` 9
  in
    if band == 2 then min radius outerCap else radius

type Point = { x :: Number, y :: Number }

type Parts = { nodes :: Array NodeOut, links :: Array LinkOut }

-- | Per-child context threaded down to the grandchild and tip levels:
-- | the scaled polar placement, the owning branch, and the child's drift
-- | direction, angle, and ring radius.
type ChildCtx =
  { place :: Number -> Number -> Point
  , branch :: BranchIn
  , sign :: Number
  , childAngle :: Number
  , childR :: Int
  }

-- | Every node shares its branch identity and takes its id from its
-- | label; only level, label side, and position vary.
mkNode :: BranchIn -> Int -> Nullable String -> String -> Point -> NodeOut
mkNode branch level labelSide label point =
  { id: label
  , label
  , level
  , branch: branch.label
  , color: branch.color
  , labelSide
  , x: point.x
  , y: point.y
  }

-- | Every link shares its branch identity, derives its id from its
-- | endpoints ("root" when sourceless), and defaults to a plain tree
-- | edge; the prerequisite pass overrides id and flag on top of this.
mkLink
  :: forall r p q
   . { label :: String, color :: String | r }
  -> Nullable String
  -> String
  -> { x :: Number, y :: Number | p }
  -> { x :: Number, y :: Number | q }
  -> LinkOut
mkLink branch source target from to =
  { id: fromMaybe "root" (toMaybe source) <> ":" <> target
  , source
  , target
  , branch: branch.label
  , color: branch.color
  , prereq: null
  , x1: from.x
  , y1: from.y
  , x2: to.x
  , y2: to.y
  }

interestLayoutJs :: Fn2 (Array BranchIn) Number LayoutOut
interestLayoutJs = mkFn2 \branches scale ->
  let
    place radius angle =
      { x: radius * scale * cos (toRadians angle)
      , y: -radius * scale * sin (toRadians angle)
      }

    sliceWidth = (maxAngle - minAngle) / toNumber (length branches)

    branchParts = concat (mapWithIndex (layoutBranch place sliceWidth) branches)
    prereqLinks = prereqPass branches (concatNodes branchParts)
  in
    { width: baseWidth * scale
    , height: baseHeight * scale
    , cx: baseWidth * scale / 2.0
    , cy: 520.0 * scale
    , rings: map (_ * scale) ringRadii
    , nodes: concatNodes branchParts
    , links: concatLinks branchParts <> prereqLinks
    }

concatNodes :: Array Parts -> Array NodeOut
concatNodes = foldl (\acc p -> acc <> p.nodes) []

concatLinks :: Array Parts -> Array LinkOut
concatLinks = foldl (\acc p -> acc <> p.links) []

layoutBranch :: (Number -> Number -> Point) -> Number -> Int -> BranchIn -> Array Parts
layoutBranch place sliceWidth b branch =
  let
    sliceEnd = maxAngle - toNumber b * sliceWidth
    sliceStart = sliceEnd - sliceWidth
    center = sliceStart + sliceWidth / 2.0
    angle = center + (center - 90.0) * edgeBias
    radius = toNumber (fromMaybe 0 (index branchRadii (b `mod` length branchRadii)))
    origin = place radius angle

    rootParts =
      { nodes: [ mkNode branch 1 (notNull "below") branch.label origin ]
      , links: [ mkLink branch null branch.label { x: 0.0, y: 0.0 } origin ]
      }

    count = length branch.children
    fanStart = sliceStart + sliceGutter
    fanWidth = sliceWidth - 2.0 * sliceGutter
    step = if count > 1 then fanWidth / toNumber (count - 1) else 0.0

    children = foldl
      ( \acc entry ->
          let
            childAngle =
              if count > 1 then fanStart + toNumber entry.ix * step
              else angle
            band = entry.ix `mod` 3
            bandIndex = fromMaybe 0 (index acc.counts band)
            childR = childRadius band bandIndex b
            part = layoutChild place branch origin angle childAngle childR entry.child
          in
            { counts: mapWithIndex (\i n -> if i == band then n + 1 else n) acc.counts
            , parts: snoc acc.parts part
            }
      )
      { counts: [ 0, 0, 0 ], parts: [] }
      (mapWithIndex (\ix child -> { ix, child }) branch.children)
  in
    [ rootParts ] <> children.parts

-- | Place one child on its band ring and lay out its subtree, reusing
-- | the branch origin already computed in `layoutBranch`.
layoutChild
  :: (Number -> Number -> Point)
  -> BranchIn
  -> Point
  -> Number
  -> Number
  -> Int
  -> ChildIn
  -> Parts
layoutChild place branch origin branchAngle childAngle childR child =
  let
    point = place (toNumber childR) childAngle
    sign = if childAngle >= branchAngle then 1.0 else -1.0
    ctx = { place, branch, sign, childAngle, childR }

    grandchildren = concat
      ( mapWithIndex (layoutGrandchild ctx child.label point)
          (fromMaybe [] (toMaybe child.children))
      )
  in
    { nodes: [ mkNode branch 2 null child.label point ] <> concatNodes grandchildren
    , links:
        [ mkLink branch (notNull branch.label) child.label origin point ]
          <> concatLinks grandchildren
    }

-- | Drift the grandchild off its parent's angle — `ctx.sign` picks the
-- | side once per child — and hang its leaf tips further out.
layoutGrandchild :: ChildCtx -> String -> Point -> Int -> GrandchildIn -> Array Parts
layoutGrandchild ctx parentLabel point g grandchild =
  let
    drift = ctx.sign * toNumber (g + 1) * 3.5
    leaf = ctx.place (toNumber ctx.childR + 84.0) (ctx.childAngle + drift)

    grandParts =
      { nodes: [ mkNode ctx.branch 3 null grandchild.label leaf ]
      , links: [ mkLink ctx.branch (notNull parentLabel) grandchild.label point leaf ]
      }

    tips = mapWithIndex (layoutTip ctx drift grandchild.label leaf)
      (fromMaybe [] (toMaybe grandchild.children))
  in
    [ grandParts ] <> tips

-- | Outermost ring: a leaf tip drifts further along the same side its
-- | parent drifted.
layoutTip :: ChildCtx -> Number -> String -> Point -> Int -> LeafIn -> Parts
layoutTip ctx drift parentLabel leaf l leafChild =
  let
    leafDrift = drift + ctx.sign * toNumber (l + 1) * 5.0
    tip = ctx.place (toNumber ctx.childR + 132.0) (ctx.childAngle + leafDrift)
  in
    { nodes: [ mkNode ctx.branch 4 null leafChild.label tip ]
    , links: [ mkLink ctx.branch (notNull parentLabel) leafChild.label leaf tip ]
    }

-- | The prerequisite pass: every node's `requires` list threads a link
-- | from the required node's position, cross-branch links flagged.
prereqPass :: Array BranchIn -> Array NodeOut -> Array LinkOut
prereqPass branches nodes = concat (map branchReqs branches)
  where
  findNode nodeId = find (\n -> n.id == nodeId) nodes

  addPrereqs
    :: forall r. { label :: String, requires :: Nullable (Array String) | r } -> Array LinkOut
  addPrereqs node = fromMaybe [] (toMaybe node.requires) >>= \required ->
    case findNode required, findNode node.label of
      Just from, Just to ->
        let
          link = mkLink { label: to.branch, color: to.color } (notNull required) node.label from to
        in
          [ link { id = "req:" <> link.id, prereq = notNull (from.branch /= to.branch) } ]
      _, _ -> []

  branchReqs branch = branch.children >>= \child ->
    addPrereqs child
      <>
        ( fromMaybe [] (toMaybe child.children) >>= \grandchild ->
            addPrereqs grandchild
              <> (fromMaybe [] (toMaybe grandchild.children) >>= addPrereqs)
        )
