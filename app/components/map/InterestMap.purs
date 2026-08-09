-- | ## InterestMap
-- |
-- | The setup composable behind `InterestMap.vue`: the polar layout feed,
-- | the d3-force entry simulation, lineage lighting from the connections
-- | store, the opening height spring that drives the mapReveal store, the
-- | orbital-ring wave, the idle ring pulse, and node dragging. The SFC
-- | keeps only the interests content query, the wrapper template ref, and
-- | one call here. The d3-force and motion-v numeric kernels stay behind
-- | the FFI edge; orchestration, parameters, state machine, and lifecycle
-- | live here.
module App.Components.InterestMap
  ( BranchesData
  , DomElement
  , LayoutData
  , LinkData
  , MapArgs
  , MapBindings
  , NodeData
  , PointerEvt
  , Spoke
  , StringSet
  , Vec2
  , useInterestMap
  ) where

import Prelude

import Data.Array
  ( concatMap
  , elem
  , filter
  , find
  , findIndex
  , index
  , length
  , modifyAt
  , null
  , slice
  , snoc
  , sortBy
  , uncons
  ) as Array
import Data.Foldable (foldl, for_, traverse_)
import Data.FoldableWithIndex (forWithIndex_)
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.Number (abs, cos, pi, sin)
import Data.Traversable (traverse)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Timer (IntervalId, TimeoutId, clearInterval, clearTimeout, setInterval, setTimeout)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , EffectFn4
  , EffectFn6
  , mkEffectFn1
  , mkEffectFn2
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  , runEffectFn4
  , runEffectFn6
  )
import Vue
  ( Computed
  , Ref
  , computed
  , onMounted
  , onUnmounted
  , read
  , ref
  , shallowRef
  , write
  )

-- | The interests collection's `branches` array.
foreign import data BranchesData :: Type

-- | A DOM `HTMLElement`.
foreign import data DomElement :: Type

-- | A `MapLayout` from `useInterestLayout`.
foreign import data LayoutData :: Type

-- | One `MapLink` of the layout.
foreign import data LinkData :: Type

-- | One `MapNode` of the layout.
foreign import data NodeData :: Type

-- | A raw `PointerEvent`.
foreign import data PointerEvt :: Type

-- | A plain `Record<string, {x, y}>` of simulated node positions.
foreign import data PositionMap :: Type

-- | A JS `Set<string>` of node ids.
foreign import data StringSet :: Type

-- | The `@nuxtjs/color-mode` instance — read at pulse time.
foreign import data ColorModeApi :: Type

-- | The mapReveal pinia store handle.
foreign import data RevealHandle :: Type

-- | A mutable d3-force simulation node.
foreign import data SimNodeData :: Type

-- | A d3-force `Simulation` handle.
foreign import data SimHandle :: Type

-- | A motion-v animation's controls.
foreign import data SpringControls :: Type

foreign import showNumberImpl :: Number -> String
foreign import interestLayoutImpl :: EffectFn2 BranchesData Number LayoutData
foreign import layoutNodesImpl :: LayoutData -> Array NodeData
foreign import layoutLinksImpl :: LayoutData -> Array LinkData
foreign import layoutRingsImpl :: LayoutData -> Array Number
foreign import layoutCxImpl :: LayoutData -> Number
foreign import layoutCyImpl :: LayoutData -> Number
foreign import nodeIdImpl :: NodeData -> String
foreign import nodeLevelImpl :: NodeData -> Int
foreign import linkSourceImpl :: LinkData -> Nullable String
foreign import linkTargetImpl :: LinkData -> String
foreign import linkPrereqImpl :: LinkData -> Boolean
foreign import mkStringSetImpl :: Array String -> StringSet
foreign import stringSetHasImpl :: Fn2 StringSet String Boolean
foreign import shuffleKeyImpl :: Fn2 String Number Number
foreign import randomImpl :: Effect Number
foreign import useElementWidthImpl :: EffectFn1 (Ref (Nullable DomElement)) (Ref Number)
foreign import useMediaQueryImpl :: EffectFn1 String (Ref Boolean)
foreign import activeNamesImpl :: Effect (Ref (Array String))
foreign import useMapRevealImpl :: Effect RevealHandle
foreign import revealDriveImpl :: EffectFn2 RevealHandle Number Unit
foreign import revealSettleImpl :: EffectFn1 RevealHandle Unit
foreign import useColorModeImpl :: Effect ColorModeApi
foreign import isDarkImpl :: EffectFn1 ColorModeApi Boolean
foreign import mkSimNodeImpl :: EffectFn1 NodeData SimNodeData
foreign import simNodeIdImpl :: SimNodeData -> String
foreign import hasFixedImpl :: EffectFn1 SimNodeData Boolean
foreign import createSimulationImpl :: EffectFn2 (Array SimNodeData) (Effect Unit) SimHandle
foreign import simStopImpl :: EffectFn1 SimHandle Unit
foreign import simRestartImpl :: EffectFn1 SimHandle Unit
foreign import simAlphaTargetImpl :: EffectFn2 SimHandle Number Unit
foreign import simSetNodesImpl :: EffectFn2 SimHandle (Array SimNodeData) Unit
foreign import setSimEntryImpl :: EffectFn3 SimNodeData Number Number Unit
foreign import setSimFixedImpl :: EffectFn3 SimNodeData Number Number Unit
foreign import clearSimFixedImpl :: EffectFn1 SimNodeData Unit
foreign import positionsOfImpl :: EffectFn1 (Array SimNodeData) PositionMap
foreign import lookupPosImpl :: Fn2 PositionMap String (Nullable Vec2)
foreign import svgPointImpl
  :: EffectFn4 (Ref (Nullable DomElement)) PointerEvt Number Number Vec2

foreign import springImpl
  :: EffectFn6 Number Number Number Number (EffectFn1 Number Unit) (Effect Unit) SpringControls

foreign import stopSpringImpl :: EffectFn1 SpringControls Unit
foreign import setRingRadiusImpl :: EffectFn3 (Ref (Array Number)) Int Number Unit
foreign import prefersReducedMotionImpl :: Effect Boolean
foreign import pulseRingsImpl :: EffectFn2 (Ref (Nullable DomElement)) Boolean Unit
foreign import watchPairImpl
  :: forall a b. EffectFn4 (Effect a) (Effect b) (Effect Unit) Boolean Unit

-- | A point in the map's centered coordinate space.
type Vec2 = { x :: Number, y :: Number }

-- | One orbital spoke's unit direction and length.
type Spoke = { deg :: Number, ux :: Number, uy :: Number, len :: Number }

type MapArgs =
  { wrapper :: Ref (Nullable DomElement)
  , branches :: Effect (Nullable BranchesData)
  }

type MapBindings =
  { layout :: Computed (Nullable LayoutData)
  , spokes :: Computed (Array Spoke)
  , fadeRadius :: Computed Number
  , compact :: Computed Boolean
  , pulseTick :: Ref Int
  , appearedSet :: Computed StringSet
  , shownLinks :: Computed (Array LinkData)
  , glowSet :: Computed StringSet
  , litNodes :: Computed StringSet
  , hovered :: Ref (Nullable String)
  , ringRadii :: Ref (Array Number)
  , ringsSettled :: Ref Boolean
  , spokeProgress :: Computed Number
  , wrapperStyle :: Computed { height :: String }
  , pos :: EffectFn1 (Nullable String) Vec2
  , litLink :: EffectFn1 LinkData Boolean
  , onDragStart :: EffectFn2 String PointerEvt Unit
  , onDragMove :: EffectFn2 String PointerEvt Unit
  , onDragEnd :: EffectFn1 String Unit
  }

origin :: Vec2
origin = { x: 0.0, y: 0.0 }

spokeAngles :: Array Number
spokeAngles = [ 22.5, 45.0, 67.5, 90.0, 112.5, 135.0, 157.5 ]

-- | The tree parent of a node — the non-prereq link targeting it.
parentOf :: Array LinkData -> String -> Maybe String
parentOf links nodeId =
  Array.find (\link -> linkTargetImpl link == nodeId && not (linkPrereqImpl link)) links
    >>= \link -> toMaybe (linkSourceImpl link)

-- | Insertion-ordered adjacency entries, one per source node.
type AdjEntry = { key :: String, vals :: Array String }

insertAdj :: String -> String -> Array AdjEntry -> Array AdjEntry
insertAdj key val entries = case Array.findIndex (\entry -> entry.key == key) entries of
  Just i -> fromMaybe entries
    (Array.modifyAt i (\entry -> entry { vals = Array.snoc entry.vals val }) entries)
  Nothing -> Array.snoc entries { key, vals: [ val ] }

lookupAdj :: Array AdjEntry -> String -> Array String
lookupAdj entries key = maybe [] _.vals (Array.find (\entry -> entry.key == key) entries)

-- | Every id reachable from `start` (inclusive) along the adjacency.
reachable :: Array AdjEntry -> String -> Array String
reachable adj start = go [] [ start ]
  where
  go seen frontier = case Array.uncons frontier of
    Nothing -> seen
    Just { head, tail } ->
      if Array.elem head seen then go seen tail
      else go (Array.snoc seen head) (tail <> lookupAdj adj head)

-- | Adjacency over the layout's links (prereq edges included, root links
-- | skipped), keyed by `keyOf` with `valOf` appended per link.
buildAdj
  :: (LinkData -> Nullable String)
  -> (LinkData -> Nullable String)
  -> Array LinkData
  -> Array AdjEntry
buildAdj keyOf valOf = foldl step []
  where
  step acc link = case toMaybe (keyOf link), toMaybe (valOf link) of
    Just key, Just val -> insertAdj key val acc
    _, _ -> acc

useInterestMap :: EffectFn1 MapArgs MapBindings
useInterestMap = mkEffectFn1 setup

setup :: MapArgs -> Effect MapBindings
setup args = do
  containerWidth <- runEffectFn1 useElementWidthImpl args.wrapper

  scale <- computed do
    width <- read containerWidth
    pure (if width == 0.0 then 1.0 else min 1.0 (width / 936.0))

  layout <- computed do
    mBranches <- toMaybe <$> args.branches
    case mBranches of
      Nothing -> pure null
      Just branches -> do
        s <- read scale
        built <- runEffectFn2 interestLayoutImpl branches s
        pure (notNull built)

  fadeRadius <- computed ((150.0 * _) <$> read scale)

  spokes <- computed do
    s <- read scale
    pure $ spokeAngles <#> \deg ->
      let
        rad = deg * pi / 180.0
        ux = cos rad
        uy = sin rad
      in
        { deg, ux, uy, len: min 516.0 (468.0 / abs ux) * s }

  compact <- computed ((_ < 0.62) <$> read scale)

  entropy <- randomImpl

  appearanceOrder <- computed do
    mLayout <- toMaybe <$> read layout
    let nodes = maybe [] layoutNodesImpl mLayout
    pure $ map _.node $ Array.sortBy
      (\a b -> compare (nodeLevelImpl a.node) (nodeLevelImpl b.node) <> compare a.key b.key)
      (nodes <#> \node -> { node, key: runFn2 shuffleKeyImpl (nodeIdImpl node) entropy })

  appearedCount <- ref 0

  appearedSet <- computed do
    order <- read appearanceOrder
    count <- read appearedCount
    pure (mkStringSetImpl (map nodeIdImpl (Array.slice 0 count order)))

  pulseTick <- ref 0
  colorMode <- useColorModeImpl

  entryTimer <- Ref.new (Nothing :: Maybe IntervalId)
  pulseTimer <- Ref.new (Nothing :: Maybe TimeoutId)
  pulseInterval <- Ref.new (Nothing :: Maybe IntervalId)
  heightControls <- Ref.new (Nothing :: Maybe SpringControls)

  shownLinks <- computed do
    mLayout <- toMaybe <$> read layout
    appeared <- read appearedSet
    let
      visible link =
        runFn2 stringSetHasImpl appeared (linkTargetImpl link)
          && case toMaybe (linkSourceImpl link) of
            Nothing -> true
            Just source -> runFn2 stringSetHasImpl appeared source
    pure (Array.filter visible (maybe [] layoutLinksImpl mLayout))

  positions <- shallowRef =<< runEffectFn1 positionsOfImpl []
  simulation <- Ref.new (Nothing :: Maybe SimHandle)
  simNodes <- Ref.new ([] :: Array SimNodeData)
  activeSimCount <- Ref.new 0

  hovered <- ref (null :: Nullable String)

  childrenMap <- computed do
    mLayout <- toMaybe <$> read layout
    pure (buildAdj linkSourceImpl (notNull <<< linkTargetImpl) (maybe [] layoutLinksImpl mLayout))

  parentsMap <- computed do
    mLayout <- toMaybe <$> read layout
    pure (buildAdj (notNull <<< linkTargetImpl) linkSourceImpl (maybe [] layoutLinksImpl mLayout))

  activeNames <- activeNamesImpl

  glowSet <- computed do
    mHovered <- toMaybe <$> read hovered
    case mHovered of
      Nothing -> pure (mkStringSetImpl [])
      Just nodeId -> do
        children <- read childrenMap
        parents <- read parentsMap
        pure (mkStringSetImpl (reachable children nodeId <> reachable parents nodeId))

  litNodes <- computed do
    names <- read activeNames
    if Array.null names then pure (mkStringSetImpl [])
    else do
      children <- read childrenMap
      parents <- read parentsMap
      pure
        ( mkStringSetImpl
            (Array.concatMap (\name -> reachable children name <> reachable parents name) names)
        )

  targetHeight <- computed do
    mLayout <- toMaybe <$> read layout
    pure (maybe 0.0 (\l -> layoutCyImpl l + 4.0) mLayout)

  singleColumn <- runEffectFn1 useMediaQueryImpl "(max-width: 900px)"
  height <- ref 0.0
  entryStarted <- ref false

  reveal <- useMapRevealImpl

  ringRadii <- ref ([] :: Array Number)
  ringsSettled <- ref false
  ringControls <- Ref.new ([] :: Array SpringControls)
  ringTimers <- Ref.new ([] :: Array TimeoutId)

  spokeProgress <- computed do
    mLayout <- toMaybe <$> read layout
    case mLayout >>= \l -> Array.index (layoutRingsImpl l) 3 of
      Nothing -> pure 0.0
      Just target
        | target == 0.0 -> pure 0.0
        | otherwise -> do
            settled <- read ringsSettled
            if settled then pure 1.0
            else do
              radii <- read ringRadii
              pure (fromMaybe 0.0 (Array.index radii 3) / target)

  wrapperStyle <- computed do
    h <- read height
    pure { height: showNumberImpl h <> "px" }

  let
    posOf mId = case mId of
      Nothing -> pure origin
      Just nodeId -> do
        posMap <- read positions
        pure (fromMaybe origin (toMaybe (runFn2 lookupPosImpl posMap nodeId)))

    syncPositions = do
      nodes <- Ref.read simNodes
      write positions =<< runEffectFn1 positionsOfImpl nodes

    clearEntryTimer = Ref.read entryTimer >>= case _ of
      Just pending -> clearInterval pending *> Ref.write Nothing entryTimer
      Nothing -> pure unit

    stopPulse = do
      Ref.read pulseTimer >>= traverse_ clearTimeout
      Ref.read pulseInterval >>= traverse_ clearInterval
      Ref.write Nothing pulseTimer
      Ref.write Nothing pulseInterval

    runPulse = do
      tick <- read pulseTick
      write pulseTick (tick + 1)
      dark <- runEffectFn1 isDarkImpl colorMode
      runEffectFn2 pulseRingsImpl args.wrapper dark

    startPulse = do
      stopPulse
      reduced <- prefersReducedMotionImpl
      unless reduced do
        pending <- setTimeout 1000 do
          runPulse
          repeating <- setInterval 5000 runPulse
          Ref.write (Just repeating) pulseInterval
        Ref.write (Just pending) pulseTimer

    resetRings = do
      Ref.read ringControls >>= traverse_ (runEffectFn1 stopSpringImpl)
      Ref.read ringTimers >>= traverse_ clearTimeout
      Ref.write [] ringControls
      Ref.write [] ringTimers
      write ringsSettled false
      write ringRadii []

    resetEntry = do
      clearEntryTimer
      stopPulse
      resetRings
      write entryStarted false
      write appearedCount 0
      Ref.write 0 activeSimCount
      Ref.read simulation >>= traverse_ \sim -> do
        runEffectFn2 simSetNodesImpl sim []
        runEffectFn2 simAlphaTargetImpl sim 0.0

    entryTick = do
      order <- read appearanceOrder
      unless (Array.null order) do
        count <- read appearedCount
        if count >= Array.length order then do
          clearEntryTimer
          Ref.read simulation >>= traverse_ \sim -> runEffectFn2 simAlphaTargetImpl sim 0.0
          startPulse
        else
          for_ (Array.index order count) \node -> do
            nodes <- Ref.read simNodes
            mSim <- Ref.read simulation
            case Array.find (\n -> simNodeIdImpl n == nodeIdImpl node) nodes, mSim of
              Just simNode, Just sim -> do
                mLayout <- toMaybe <$> read layout
                let links = maybe [] layoutLinksImpl mLayout
                from <- posOf (parentOf links (nodeIdImpl node))
                runEffectFn3 setSimEntryImpl simNode from.x from.y
                active <- Ref.modify (_ + 1) activeSimCount
                runEffectFn2 simSetNodesImpl sim (Array.slice 0 active nodes)
                runEffectFn2 simAlphaTargetImpl sim 0.28
                runEffectFn1 simRestartImpl sim
                syncPositions
              _, _ -> pure unit
            write appearedCount (count + 1)

    beginEntry = do
      clearEntryTimer
      repeating <- setInterval 55 entryTick
      Ref.write (Just repeating) entryTimer

    rebuild = do
      mLayout <- toMaybe <$> read layout
      for_ mLayout \_ -> do
        order <- read appearanceOrder
        Ref.read simulation >>= traverse_ (runEffectFn1 simStopImpl)
        nodes <- traverse (runEffectFn1 mkSimNodeImpl) order
        Ref.write nodes simNodes
        count <- read appearedCount
        let active = min count (Array.length nodes)
        Ref.write active activeSimCount
        sim <- runEffectFn2 createSimulationImpl (Array.slice 0 active nodes) syncPositions
        Ref.write (Just sim) simulation
        syncPositions

    waveRings done = do
      resetRings
      mLayout <- toMaybe <$> read layout
      let rings = maybe [] layoutRingsImpl mLayout
      if Array.null rings then done
      else forWithIndex_ rings \ringIndex target -> do
        pending <- setTimeout (ringIndex * 110) do
          controls <- runEffectFn6 springImpl 0.0 target 0.4 0.3
            ( mkEffectFn1 \latest -> runEffectFn3 setRingRadiusImpl ringRadii ringIndex
                (max 0.0 latest)
            )
            ( when (ringIndex == Array.length rings - 1) do
                write ringsSettled true
                done
            )
          Ref.modify_ (flip Array.snoc controls) ringControls
        Ref.modify_ (flip Array.snoc pending) ringTimers

    open = do
      mLayout <- toMaybe <$> read layout
      for_ mLayout \_ -> do
        single <- read singleColumn
        full <- read targetHeight
        let target = if single then 0.0 else full
        when (target == 0.0) do
          resetEntry
          runEffectFn1 revealSettleImpl reveal
        Ref.read heightControls >>= traverse_ (runEffectFn1 stopSpringImpl)
        h <- read height
        controls <- runEffectFn6 springImpl h target 0.35 0.35
          ( mkEffectFn1 \latest -> do
              write height (max 0.0 latest)
              when (target > 0.0) (runEffectFn2 revealDriveImpl reveal (latest - target))
          )
          ( when (target > 0.0) do
              runEffectFn1 revealSettleImpl reveal
              started <- read entryStarted
              unless started $ waveRings do
                write entryStarted true
                beginEntry
          )
        Ref.write (Just controls) heightControls

    dragTarget nodeId = do
      nodes <- Ref.read simNodes
      pure (Array.find (\n -> simNodeIdImpl n == nodeId) nodes)

    dragPoint event = do
      mLayout <- toMaybe <$> read layout
      case mLayout of
        Nothing -> pure origin
        Just l -> runEffectFn4 svgPointImpl args.wrapper event (layoutCxImpl l) (layoutCyImpl l)

    onDragStart nodeId event = do
      mNode <- dragTarget nodeId
      mSim <- Ref.read simulation
      case mNode, mSim of
        Just node, Just sim -> do
          point <- dragPoint event
          runEffectFn3 setSimFixedImpl node point.x point.y
          runEffectFn2 simAlphaTargetImpl sim 0.35
          runEffectFn1 simRestartImpl sim
        _, _ -> pure unit

    onDragMove nodeId event = do
      mNode <- dragTarget nodeId
      for_ mNode \node -> do
        fixed <- runEffectFn1 hasFixedImpl node
        when fixed do
          point <- dragPoint event
          runEffectFn3 setSimFixedImpl node point.x point.y

    onDragEnd nodeId = do
      mNode <- dragTarget nodeId
      mSim <- Ref.read simulation
      case mNode, mSim of
        Just node, Just sim -> do
          runEffectFn1 clearSimFixedImpl node
          runEffectFn2 simAlphaTargetImpl sim 0.0
        _, _ -> pure unit

  runEffectFn4 watchPairImpl (read layout) (read appearanceOrder) rebuild true

  onUnmounted do
    clearEntryTimer
    stopPulse
    resetRings
    Ref.read heightControls >>= traverse_ (runEffectFn1 stopSpringImpl)
    Ref.read simulation >>= traverse_ (runEffectFn1 simStopImpl)
    runEffectFn1 revealSettleImpl reveal

  onMounted open
  runEffectFn4 watchPairImpl (read targetHeight) (read singleColumn) open false

  pure
    { layout
    , spokes
    , fadeRadius
    , compact
    , pulseTick
    , appearedSet
    , shownLinks
    , glowSet
    , litNodes
    , hovered
    , ringRadii
    , ringsSettled
    , spokeProgress
    , wrapperStyle
    , pos: mkEffectFn1 (posOf <<< toMaybe)
    , litLink: mkEffectFn1 \link -> do
        lit <- read litNodes
        pure
          ( runFn2 stringSetHasImpl lit (linkTargetImpl link)
              && case toMaybe (linkSourceImpl link) of
                Nothing -> true
                Just source -> runFn2 stringSetHasImpl lit source
          )
    , onDragStart: mkEffectFn2 onDragStart
    , onDragMove: mkEffectFn2 onDragMove
    , onDragEnd: mkEffectFn1 onDragEnd
    }
