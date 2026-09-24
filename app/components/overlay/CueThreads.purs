-- | ## CueThreads
-- |
-- | The setup composable behind `CueThreads.vue`: verlet rope physics
-- | between cue roots and their marks, Catmull-Rom spline paths, and the
-- | animation-frame loop. DOM measurement and the cues-store bridge live
-- | in the FFI; the SFC keeps only the store handle.
module App.Components.CueThreads
  ( CuesStore
  , DomElement
  , Point
  , RopePoint
  , ThreadArgs
  , ThreadBindings
  , frameDt
  , layRope
  , setup
  , splinePath
  , stepPoints
  ) where

import Prelude

import App.Utils.JsMath (hypot)
import Data.Array
  ( any
  , catMaybes
  , concatMap
  , filter
  , index
  , length
  , mapWithIndex
  , null
  , range
  , snoc
  , uncons
  ) as Array
import Data.Foldable (foldM)
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Int (round, toNumber)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Nullable (Nullable, null, toMaybe)
import Data.Number.Format (toString)
import Data.String (joinWith)
import Data.Traversable (for, traverse)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn1, runEffectFn1, runEffectFn2)
import Vue (Ref, onUnmounted, ref, watchGetter, write)

-- | The `useCues()` store handle — mark registry and active cue groups.
foreign import data CuesStore :: Type

-- | A DOM `Element`.
foreign import data DomElement :: Type

foreign import isClientImpl :: Boolean

foreign import sameElementImpl :: Fn2 DomElement DomElement Boolean

foreign import centerImpl :: EffectFn1 DomElement Point

foreign import markElementImpl :: EffectFn2 CuesStore String (Nullable DomElement)

foreign import groupsOfImpl :: EffectFn1 CuesStore (Array CueGroup)

foreign import deactivateCuesImpl :: EffectFn1 CuesStore Unit

foreign import imageClipImpl :: Effect (Nullable String)

foreign import rafImpl :: EffectFn1 (EffectFn1 Number Unit) Int

foreign import cancelRafImpl :: EffectFn1 Int Unit

foreign import onTouchStartImpl :: EffectFn1 (Effect Unit) (Effect Unit)

minSegments :: Int
minSegments = 6

maxSegments :: Int
maxSegments = 22

segmentDistance :: Number
segmentDistance = 40.0

slackRatio :: Number
slackRatio = 1.06

slackPx :: Number
slackPx = 8.0

gravity :: Number
gravity = 0.0016

airFriction :: Number
airFriction = 0.015

iterations :: Int
iterations = 3

-- | A point in viewport coordinates.
type Point = { x :: Number, y :: Number }

type CueGroup = { root :: DomElement, targets :: Array String }

-- | One verlet particle: current and previous position, plus whether
-- | it's pinned to a measured endpoint.
type RopePoint = { x :: Number, y :: Number, px :: Number, py :: Number, pinned :: Boolean }

type Rope =
  { root :: DomElement
  , target :: DomElement
  , points :: Array RopePoint
  , linkLength :: Number
  }

type RootRopes = { root :: DomElement, ropes :: Array Rope }

type ThreadArgs =
  { -- | The cues store handle.
    cues :: CuesStore
  }

type ThreadBindings =
  { -- | Spline path "d" attribute per rope, in render order.
    paths :: Ref (Array String)
  -- | Clip-path for the portrait while a cue is active — the overlay
  -- | copy drawn above the image uses it.
  , imageClip :: Ref (Nullable String)
  }

mkRope :: DomElement -> Point -> DomElement -> Point -> Maybe Rope
mkRope root start target end =
  (\laid -> { root, target, points: laid.points, linkLength: laid.linkLength })
    <$> layRope start end

-- | A slack rope's particles and link length between two measured
-- | centers: an interior particle per `segmentDistance` px of span, held
-- | between `minSegments` and `maxSegments`, spaced evenly along the
-- | straight line between the two pinned ends; the links share the span
-- | plus 6% and 8px of slack, so the rope hangs. Nothing when the end has
-- | collapsed to the origin — a target that is not laid out.
layRope :: Point -> Point -> Maybe { points :: Array RopePoint, linkLength :: Number }
layRope start end
  | end.x == 0.0 && end.y == 0.0 = Nothing
  | otherwise =
      let
        distance = hypot (end.x - start.x) (end.y - start.y)
        count = clamp minSegments maxSegments (round (distance / segmentDistance))
        ropeLength = distance * slackRatio + slackPx
        mid i =
          let
            t = toNumber i / toNumber (count + 1)
            x = start.x + (end.x - start.x) * t
            y = start.y + (end.y - start.y) * t
          in
            { x, y, px: x, py: y, pinned: false }
        points =
          [ { x: start.x, y: start.y, px: start.x, py: start.y, pinned: true } ]
            <> map mid (Array.range 1 count)
            <> [ { x: end.x, y: end.y, px: end.x, py: end.y, pinned: true } ]
      in
        Just { points, linkLength: ropeLength / toNumber (count + 1) }

-- | One verlet integration step plus constraint relaxation, with the
-- | endpoints re-pinned to the freshly measured centers.
stepPoints :: Number -> Point -> Point -> Number -> Array RopePoint -> Array RopePoint
stepPoints dt rootCenter targetCenter linkLength points =
  relax iterations (map integrate (Array.mapWithIndex anchor points))
  where
  count = Array.length points

  anchor i point
    | i == 0 = point { x = rootCenter.x, y = rootCenter.y }
    | i == count - 1 = point { x = targetCenter.x, y = targetCenter.y }
    | otherwise = point

  integrate point
    | point.pinned = point
    | otherwise =
        let
          vx = (point.x - point.px) * (1.0 - airFriction)
          vy = (point.y - point.py) * (1.0 - airFriction)
        in
          { x: point.x + vx
          , y: point.y + vy + gravity * dt * dt
          , px: point.x
          , py: point.y
          , pinned: point.pinned
          }

  relax 0 ps = ps
  relax n ps = relax (n - 1) (constrain ps)

  constrain ps = case Array.uncons ps of
    Nothing -> ps
    Just { head, tail } -> go [] head tail

  go acc curr rest = case Array.uncons rest of
    Nothing -> Array.snoc acc curr
    Just { head: next, tail } ->
      let
        dx = next.x - curr.x
        dy = next.y - curr.y
        rawLength = hypot dx dy
        len = if rawLength == 0.0 then 0.0001 else rawLength
        difference = (len - linkLength) / len
        ax = dx * difference * 0.5
        ay = dy * difference * 0.5
        curr' =
          if curr.pinned then curr
          else curr
            { x = curr.x + (if next.pinned then dx * difference else ax)
            , y = curr.y + (if next.pinned then dy * difference else ay)
            }
        next' =
          if next.pinned then next
          else next
            { x = next.x - (if curr.pinned then dx * difference else ax)
            , y = next.y - (if curr.pinned then dy * difference else ay)
            }
      in
        go (Array.snoc acc curr') next' tail

-- | The step a frame at `timestamp` advances the ropes by, in ms, after
-- | the frame at `previous` (0 before the first frame, which then steps
-- | the minimum): held between 8 and 33 ms, so a stalled tab does not
-- | fling the ropes and a fast display does not freeze them.
frameDt :: Number -> Number -> Number
frameDt previous timestamp =
  clamp 8.0 33.0 (timestamp - (if previous == 0.0 then timestamp else previous))

-- | Catmull-Rom spline through the rope points, as in the reference.
splinePath :: Array RopePoint -> String
splinePath points =
  if total < 2 then ""
  else
    "M " <> num first.x <> " " <> num first.y
      <> joinWith "" (map segment (Array.range 0 (total - 2)))
  where
  total = Array.length points
  num = toString
  fallback = { x: 0.0, y: 0.0, px: 0.0, py: 0.0, pinned: false }
  at i = fromMaybe fallback (Array.index points i)
  first = at 0
  segment i =
    let
      p0 = at (max 0 (i - 1))
      p1 = at i
      p2 = at (i + 1)
      p3 = at (min (total - 1) (i + 2))
      cp1x = p1.x + (p2.x - p0.x) / 6.0
      cp1y = p1.y + (p2.y - p0.y) / 6.0
      cp2x = p2.x - (p3.x - p1.x) / 6.0
      cp2y = p2.y - (p3.y - p1.y) / 6.0
    in
      " C " <> num cp1x <> " " <> num cp1y <> ", " <> num cp2x <> " " <> num cp2y
        <> ", "
        <> num p2.x
        <> " "
        <> num p2.y

-- | Runs the thread overlay: watches the store's active cue groups,
-- | lays slack verlet ropes from each root to its marks, steps them per
-- | animation frame, and publishes the spline paths plus the portrait
-- | clip. Client-only; the loop parks while no group is active.
setup :: ThreadArgs -> Effect ThreadBindings
setup args = do
  paths <- ref ([] :: Array String)
  imageClip <- ref (null :: Nullable String)
  ropesByRoot <- Ref.new ([] :: Array RootRopes)
  frame <- Ref.new 0
  previousTime <- Ref.new 0.0

  let
    updateImageClip = imageClipImpl >>= write imageClip

    renderPaths rs = write paths (map (\rope -> splinePath rope.points) rs)

    buildRopes root targets = map Array.catMaybes $ for targets \name -> do
      el <- toMaybe <$> runEffectFn2 markElementImpl args.cues name
      case el of
        Nothing -> pure Nothing
        Just target -> do
          start <- runEffectFn1 centerImpl root
          end <- runEffectFn1 centerImpl target
          pure (mkRope root start target end)

    stepRope dt rope = do
      rootCenter <- runEffectFn1 centerImpl rope.root
      targetCenter <- runEffectFn1 centerImpl rope.target
      pure (rope { points = stepPoints dt rootCenter targetCenter rope.linkLength rope.points })

    tick timestamp = do
      entries <- Ref.read ropesByRoot
      if Array.null (Array.concatMap _.ropes entries) then Ref.write 0 frame
      else do
        prev <- Ref.read previousTime
        let dt = frameDt prev timestamp
        Ref.write timestamp previousTime
        stepped <- for entries \entry -> do
          ropes' <- traverse (stepRope dt) entry.ropes
          pure entry { ropes = ropes' }
        Ref.write stepped ropesByRoot
        renderPaths (Array.concatMap _.ropes stepped)
        updateImageClip
        next <- runEffectFn1 rafImpl (mkEffectFn1 tick)
        Ref.write next frame

    rebuild groups = do
      entries <- Ref.read ropesByRoot
      let
        kept = Array.filter
          (\entry -> Array.any (\group -> runFn2 sameElementImpl entry.root group.root) groups)
          entries
      updated <- foldM
        ( \acc group ->
            if Array.any (\entry -> runFn2 sameElementImpl entry.root group.root) acc then pure acc
            else do
              built <- buildRopes group.root group.targets
              pure (Array.snoc acc { root: group.root, ropes: built })
        )
        kept
        groups
      Ref.write updated ropesByRoot
      let flattened = Array.concatMap _.ropes updated
      if Array.null flattened then do
        pending <- Ref.read frame
        runEffectFn1 cancelRafImpl pending
        Ref.write 0 frame
        Ref.write 0.0 previousTime
        write paths []
      else do
        renderPaths flattened
        updateImageClip
        pending <- Ref.read frame
        when (pending == 0) do
          Ref.write 0.0 previousTime
          next <- runEffectFn1 rafImpl (mkEffectFn1 tick)
          Ref.write next frame

  when isClientImpl
    (void (watchGetter (runEffectFn1 groupsOfImpl args.cues) \groups _ -> rebuild groups))

  stopTouch <- runEffectFn1 onTouchStartImpl (runEffectFn1 deactivateCuesImpl args.cues)

  onUnmounted do
    pending <- Ref.read frame
    runEffectFn1 cancelRafImpl pending
    stopTouch

  pure { paths, imageClip }
