-- | ## InterestMap
-- |
-- | The setup composable behind `InterestMap.vue`: the polar layout feed,
-- | the d3-force entry simulation, lineage lighting from the connections
-- | store, the opening height spring that drives the mapReveal store, the
-- | orbital-ring wave, the idle ring pulse, node dragging, and the small
-- | per-element helpers the template binds (ring radii, spoke tips, link
-- | and node highlight state). The SFC keeps only the interests content
-- | query, the wrapper template ref, and one call here. The d3-force and
-- | motion-v numeric kernels stay behind the FFI edge; orchestration,
-- | parameters, state machine, and lifecycle live here.
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
  , setup
  ) where

import Prelude

import App.Components.InterestMap.Geometry
  ( compactAt
  , linkClasses
  , mapScale
  , openTarget
  , opensInPlace
  , ringRadiusAt
  , spokeGrowth
  , spokeTipAt
  , spokesAt
  )
import App.Components.InterestMap.Graph
  ( appearanceOrderBy
  , buildAdj
  , endpointsWithin
  , lineage
  , parentOf
  )
import Data.Array
  ( concatMap
  , filter
  , find
  , index
  , length
  , null
  , slice
  , snoc
  ) as Array
import Data.Foldable (for_, traverse_)
import Data.FoldableWithIndex (forWithIndex_)
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.Number.Format (toString)
import Data.Traversable (traverse)
import Effect (Effect)
import Effect.Random (random)
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

-- | A DOM `HTMLElement`. @ts HTMLElement
foreign import data DomElement :: Type

-- | A `MapLayout` from `useInterestLayout`.
foreign import data LayoutData :: Type

-- | One `MapLink` of the layout.
foreign import data LinkData :: Type

-- | One `MapNode` of the layout.
foreign import data NodeData :: Type

-- | A raw `PointerEvent`. @ts PointerEvent
foreign import data PointerEvt :: Type

-- | A plain `Record<string, {x, y}>` of simulated node positions.
foreign import data PositionMap :: Type

-- | A JS `Set<string>` of node ids.
foreign import data StringSet :: Type

-- | The `@nuxtjs/color-mode` instance — read at pulse time.
foreign import data ColorModeApi :: Type

foreign import data RevealHandle :: Type

-- | A mutable d3-force simulation node.
foreign import data SimNodeData :: Type

-- | A d3-force `Simulation` handle.
foreign import data SimHandle :: Type

-- | A motion-v animation's controls.
foreign import data SpringControls :: Type

-- | Builds the scaled polar `MapLayout` for the branches
-- | (`useInterestLayout`).
foreign import interestLayoutImpl :: EffectFn2 BranchesData Number LayoutData

foreign import layoutNodesImpl :: LayoutData -> Array NodeData

-- | The layout's edges: tree links, center spokes, prereq threads.
foreign import layoutLinksImpl :: LayoutData -> Array LinkData

-- | The orbital-ring radii, innermost first.
foreign import layoutRingsImpl :: LayoutData -> Array Number

foreign import layoutCxImpl :: LayoutData -> Number

foreign import layoutCyImpl :: LayoutData -> Number

-- | A node's id (its unique label).
foreign import nodeIdImpl :: NodeData -> String

-- | A node's depth: 1 branch root through 4 leaf tip.
foreign import nodeLevelImpl :: NodeData -> Int

-- | A link's source node id; null on the center-to-branch spokes.
foreign import linkSourceImpl :: LinkData -> Nullable String

foreign import linkTargetImpl :: LinkData -> String

foreign import linkPrereqImpl :: LinkData -> Boolean

foreign import mkStringSetImpl :: Array String -> StringSet

foreign import stringSetHasImpl :: Fn2 StringSet String Boolean

-- | FNV-style hash of a node id and the visit seed — the appearance
-- | shuffle key.
foreign import shuffleKeyImpl :: Fn2 String Number Number

-- | Reactive element width (VueUse `useElementSize`); the observer stops
-- | with the component scope.
foreign import useElementWidthImpl :: EffectFn1 (Ref (Nullable DomElement)) (Ref Number)

-- | Reactive media-query match (VueUse `useMediaQuery`); the listener
-- | stops with the component scope.
foreign import useMediaQueryImpl :: EffectFn1 String (Ref Boolean)

-- | The connections store's `activeNames` ref — names whose lineage
-- | should light up.
foreign import activeNamesImpl :: Effect (Ref (Array String))

foreign import useMapRevealImpl :: Effect RevealHandle

-- | Feeds the store the opening spring's offset from its target so the
-- | page below can track the map.
foreign import revealDriveImpl :: EffectFn2 RevealHandle Number Unit

-- | Marks the reveal settled and clears the store's offset.
foreign import revealSettleImpl :: EffectFn1 RevealHandle Unit

-- | Whether the opening spring has already landed once this visit.
foreign import revealSettledImpl :: EffectFn1 RevealHandle Boolean

foreign import useColorModeImpl :: Effect ColorModeApi

foreign import isDarkImpl :: EffectFn1 ColorModeApi Boolean

-- | Wraps a layout node as a sim node seeded at — and homing to — its
-- | layout position.
foreign import mkSimNodeImpl :: EffectFn1 NodeData SimNodeData

foreign import simNodeIdImpl :: SimNodeData -> String

-- | Whether the sim node is pinned (`fx` set) — i.e. mid-drag.
foreign import hasFixedImpl :: EffectFn1 SimNodeData Boolean

-- | Builds the d3-force simulation — home pull, collision, mild
-- | repulsion — parked at alpha 0; the callback fires per tick.
foreign import createSimulationImpl :: EffectFn2 (Array SimNodeData) (Effect Unit) SimHandle

foreign import simStopImpl :: EffectFn1 SimHandle Unit

foreign import simRestartImpl :: EffectFn1 SimHandle Unit

-- | Sets the simulation's alpha target — above zero keeps it hot.
foreign import simAlphaTargetImpl :: EffectFn2 SimHandle Number Unit

foreign import simSetNodesImpl :: EffectFn2 SimHandle (Array SimNodeData) Unit

-- | Teleports a sim node to (x, y) with zero velocity — the entry spawn.
foreign import setSimEntryImpl :: EffectFn3 SimNodeData Number Number Unit

-- | Pins a sim node at (x, y) via `fx`/`fy`.
foreign import setSimFixedImpl :: EffectFn3 SimNodeData Number Number Unit

foreign import clearSimFixedImpl :: EffectFn1 SimNodeData Unit

-- | Snapshots the nodes' positions as an id-keyed record.
foreign import positionsOfImpl :: EffectFn1 (Array SimNodeData) PositionMap

foreign import lookupPosImpl :: Fn2 PositionMap String (Nullable Vec2)

-- | A pointer event's position in the map's centered coordinate space:
-- | client coords minus the SVG rect and `(cx, cy)`.
foreign import svgPointImpl
  :: EffectFn4 (Ref (Nullable DomElement)) PointerEvt Number Number Vec2

-- | Runs a motion-v spring from → to with the given visual duration and
-- | bounce, calling back per frame and once on completion; the returned
-- | controls stop it.
foreign import springImpl
  :: EffectFn6 Number Number Number Number (EffectFn1 Number Unit) (Effect Unit) SpringControls

foreign import stopSpringImpl :: EffectFn1 SpringControls Unit

-- | In-place indexed write to the ring-radii ref
-- | (`radii.value[i] = v`), growing the array as needed.
foreign import setRingRadiusImpl :: EffectFn3 (Ref (Array Number)) Int Number Unit

-- | Whether the visitor prefers reduced motion; SSR counts as reduced,
-- | so server-rendered markup never animates.
foreign import prefersReducedMotionImpl :: Effect Boolean

-- | One idle heartbeat: WAAPI stroke pulses across the rings plus a dash
-- | glint along the spokes, colored for the current theme.
foreign import pulseRingsImpl :: EffectFn2 (Ref (Nullable DomElement)) Boolean Unit

-- | A two-source Vue `watch` (element-compared), optionally immediate;
-- | stops with the component scope.
foreign import watchPairImpl
  :: forall a b. EffectFn4 (Effect a) (Effect b) (Effect Unit) Boolean Unit

-- | A point in the map's centered coordinate space (the same record as
-- | `App.Components.InterestMap.Geometry.Vec2`).
type Vec2 = { x :: Number, y :: Number }

-- | One orbital spoke's unit direction and length (the same record as
-- | `App.Components.InterestMap.Geometry.Spoke`).
type Spoke = { deg :: Number, ux :: Number, uy :: Number, len :: Number }

type MapArgs =
  { -- | Template ref to the wrapper div: measured for scale, height-
    -- | animated on open, and queried for the SVG by drag and pulse code.
    wrapper :: Ref (Nullable DomElement)
  -- | Reads the interests collection's branches; null until the content
  -- | query lands.
  , branches :: Effect (Nullable BranchesData)
  }

type MapBindings =
  { -- | The scaled polar layout (width/height/cx/cy/rings/nodes/links),
    -- | or null before the branches arrive — gates the whole SVG.
    layout :: Computed (Nullable LayoutData)
  -- | Decorative spoke rays: angle, unit direction, scaled length.
  , spokes :: Computed (Array Spoke)
  -- | Radius of the center fade-out gradient circle.
  , fadeRadius :: Computed Number
  -- | True on narrow layouts (scale < 0.62) — nodes drop to compact
  -- | labels.
  , compact :: Computed Boolean
  -- | Bumped on every idle ring pulse; nodes key their own pulse off it.
  , pulseTick :: Ref Int
  -- | Ids revealed so far by the entry stagger — a node renders once its
  -- | id is in here.
  , appearedSet :: Computed StringSet
  -- | Links whose endpoints have all appeared.
  , shownLinks :: Computed (Array LinkData)
  -- | Hover lineage: ids reachable up and down from the hovered node.
  , glowSet :: Computed StringSet
  -- | Connection lineage: ids reachable from the connections store's
  -- | active names — non-empty dims everything else.
  , litNodes :: Computed StringSet
  -- | Whether any node is lit — the SVG's `has-highlight` class.
  , hasHighlight :: Computed Boolean
  -- | The hovered node id, written back by node hover events.
  , hovered :: Ref (Nullable String)
  -- | Ring radii mid-wave; the template reads these until settled.
  , ringRadii :: Ref (Array Number)
  -- | True once the opening ring wave finishes — rings then use the
  -- | layout radii directly.
  , ringsSettled :: Ref Boolean
  -- | 0–1 spoke growth, tracking the fourth ring's spring.
  , spokeProgress :: Computed Number
  -- | Wrapper inline style: the spring-animated height in px.
  , wrapperStyle :: Computed { height :: String }
  -- | A ring's drawn radius, given its index and layout radius: the layout
  -- | radius once the wave settles, its mid-wave radius (0 before it
  -- | starts) until then.
  , ringRadius :: EffectFn2 Int Number Number
  -- | A spoke's outer end at the current growth.
  , spokeTip :: EffectFn1 Spoke Vec2
  -- | A link's classes: a prerequisite thread, and — while something is
  -- | lit — dimmed or lit by whether both its endpoints are.
  , linkState :: EffectFn1 LinkData { prereq :: Boolean, dimmed :: Boolean, lit :: Boolean }
  -- | Whether the entry stagger has revealed the node id yet.
  , nodeShown :: EffectFn1 String Boolean
  -- | Whether the node id is on the hovered or the lit lineage.
  , nodeGlowing :: EffectFn1 String Boolean
  -- | Whether the node id sits outside a non-empty lit lineage.
  , nodeDimmed :: EffectFn1 String Boolean
  -- | Node hover events: the hovered id, or null on leave.
  , hover :: EffectFn1 (Nullable String) Unit
  -- | The simulated position of a node id (origin for null or unknown).
  , pos :: EffectFn1 (Nullable String) Vec2
  -- | Whether both of a link's endpoints are lit.
  , litLink :: EffectFn1 LinkData Boolean
  -- | Pointerdown on a node: pin it under the pointer and heat the sim.
  , onDragStart :: EffectFn2 String PointerEvt Unit
  -- | Pointermove: keep the pinned node under the pointer.
  , onDragMove :: EffectFn2 String PointerEvt Unit
  -- | Pointerup/cancel: release the node and let the sim cool.
  , onDragEnd :: EffectFn1 String Unit
  }

origin :: Vec2
origin = { x: 0.0, y: 0.0 }

endpointsIn :: StringSet -> LinkData -> Boolean
endpointsIn set link =
  endpointsWithin (runFn2 stringSetHasImpl set) (linkTargetImpl link) (linkSourceImpl link)

type PulseDeps =
  { pulseTimer :: Ref.Ref (Maybe TimeoutId)
  , pulseInterval :: Ref.Ref (Maybe IntervalId)
  , pulseTick :: Ref Int
  , colorMode :: ColorModeApi
  , wrapper :: Ref (Nullable DomElement)
  }

stopPulse :: PulseDeps -> Effect Unit
stopPulse deps = do
  Ref.read deps.pulseTimer >>= traverse_ clearTimeout
  Ref.read deps.pulseInterval >>= traverse_ clearInterval
  Ref.write Nothing deps.pulseTimer
  Ref.write Nothing deps.pulseInterval

runPulse :: PulseDeps -> Effect Unit
runPulse deps = do
  tick <- read deps.pulseTick
  write deps.pulseTick (tick + 1)
  dark <- runEffectFn1 isDarkImpl deps.colorMode
  runEffectFn2 pulseRingsImpl deps.wrapper dark

startPulse :: PulseDeps -> Effect Unit
startPulse deps = do
  stopPulse deps
  reduced <- prefersReducedMotionImpl
  unless reduced do
    pending <- setTimeout 1000 do
      runPulse deps
      repeating <- setInterval 5000 (runPulse deps)
      Ref.write (Just repeating) deps.pulseInterval
    Ref.write (Just pending) deps.pulseTimer

type DragDeps =
  { simNodes :: Ref.Ref (Array SimNodeData)
  , simulation :: Ref.Ref (Maybe SimHandle)
  , layout :: Computed (Nullable LayoutData)
  , wrapper :: Ref (Nullable DomElement)
  }

dragTarget :: DragDeps -> String -> Effect (Maybe SimNodeData)
dragTarget deps nodeId = do
  nodes <- Ref.read deps.simNodes
  pure (Array.find (\n -> simNodeIdImpl n == nodeId) nodes)

dragPoint :: DragDeps -> PointerEvt -> Effect Vec2
dragPoint deps event = do
  mLayout <- toMaybe <$> read deps.layout
  case mLayout of
    Nothing -> pure origin
    Just l -> runEffectFn4 svgPointImpl deps.wrapper event (layoutCxImpl l) (layoutCyImpl l)

onDragStart :: DragDeps -> String -> PointerEvt -> Effect Unit
onDragStart deps nodeId event = do
  mNode <- dragTarget deps nodeId
  mSim <- Ref.read deps.simulation
  case mNode, mSim of
    Just node, Just sim -> do
      point <- dragPoint deps event
      runEffectFn3 setSimFixedImpl node point.x point.y
      runEffectFn2 simAlphaTargetImpl sim 0.35
      runEffectFn1 simRestartImpl sim
    _, _ -> pure unit

onDragMove :: DragDeps -> String -> PointerEvt -> Effect Unit
onDragMove deps nodeId event = do
  mNode <- dragTarget deps nodeId
  for_ mNode \node -> do
    fixed <- runEffectFn1 hasFixedImpl node
    when fixed do
      point <- dragPoint deps event
      runEffectFn3 setSimFixedImpl node point.x point.y

onDragEnd :: DragDeps -> String -> Effect Unit
onDragEnd deps nodeId = do
  mNode <- dragTarget deps nodeId
  mSim <- Ref.read deps.simulation
  case mNode, mSim of
    Just node, Just sim -> do
      runEffectFn1 clearSimFixedImpl node
      runEffectFn2 simAlphaTargetImpl sim 0.0
    _, _ -> pure unit

-- | Wires the whole interest map: the scaled polar layout, the opening
-- | height spring (driving the mapReveal store), the ring wave and
-- | staggered node entry through the d3-force simulation, lineage
-- | lighting, the idle pulse, and node dragging.
setup :: MapArgs -> Effect MapBindings
setup args = do
  containerWidth <- runEffectFn1 useElementWidthImpl args.wrapper

  scale <- computed (mapScale <$> read containerWidth)

  layout <- computed do
    mBranches <- toMaybe <$> args.branches
    case mBranches of
      Nothing -> pure null
      Just branches -> do
        s <- read scale
        built <- runEffectFn2 interestLayoutImpl branches s
        pure (notNull built)

  fadeRadius <- computed ((150.0 * _) <$> read scale)

  spokes <- computed (spokesAt <$> read scale)

  compact <- computed (compactAt <$> read scale)

  entropy <- random

  appearanceOrder <- computed do
    mLayout <- toMaybe <$> read layout
    let
      nodes = maybe [] layoutNodesImpl mLayout
      shuffle node = runFn2 shuffleKeyImpl (nodeIdImpl node) entropy
    pure (appearanceOrderBy nodeLevelImpl shuffle nodes)

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
    pure (Array.filter (endpointsIn appeared) (maybe [] layoutLinksImpl mLayout))

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
        pure (mkStringSetImpl (lineage children parents nodeId))

  litIds <- computed do
    names <- read activeNames
    if Array.null names then pure []
    else do
      children <- read childrenMap
      parents <- read parentsMap
      pure (Array.concatMap (lineage children parents) names)

  litNodes <- computed (mkStringSetImpl <$> read litIds)

  hasHighlight <- computed (not <<< Array.null <$> read litIds)

  targetHeight <- computed do
    mLayout <- toMaybe <$> read layout
    pure (maybe 0.0 (\l -> layoutCyImpl l + 4.0) mLayout)

  singleColumn <- runEffectFn1 useMediaQueryImpl "(max-width: 900px)"
  height <- ref 0.0
  entryStarted <- ref false
  mounting <- Ref.new true

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
            else spokeGrowth target <$> read ringRadii

  wrapperStyle <- computed do
    h <- read height
    pure { height: toString h <> "px" }

  let
    pulseDeps = { pulseTimer, pulseInterval, pulseTick, colorMode, wrapper: args.wrapper }
    dragDeps = { simNodes, simulation, layout, wrapper: args.wrapper }

    has set nodeId = runFn2 stringSetHasImpl set nodeId

    litHas nodeId = flip has nodeId <$> read litNodes

    litLinkOf link = (\lit -> endpointsIn lit link) <$> read litNodes

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

    resetRings = do
      Ref.read ringControls >>= traverse_ (runEffectFn1 stopSpringImpl)
      Ref.read ringTimers >>= traverse_ clearTimeout
      Ref.write [] ringControls
      Ref.write [] ringTimers
      write ringsSettled false
      write ringRadii []

    resetEntry = do
      clearEntryTimer
      stopPulse pulseDeps
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
          startPulse pulseDeps
        else
          for_ (Array.index order count) \node -> do
            nodes <- Ref.read simNodes
            mSim <- Ref.read simulation
            case Array.find (\n -> simNodeIdImpl n == nodeIdImpl node) nodes, mSim of
              Just simNode, Just sim -> do
                mLayout <- toMaybe <$> read layout
                let links = maybe [] layoutLinksImpl mLayout
                from <- posOf
                  (parentOf linkTargetImpl linkPrereqImpl linkSourceImpl links (nodeIdImpl node))
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
        let target = openTarget single full
        when (target == 0.0) do
          resetEntry
          runEffectFn1 revealSettleImpl reveal
        Ref.read heightControls >>= traverse_ (runEffectFn1 stopSpringImpl)
        h <- read height
        seen <- runEffectFn1 revealSettledImpl reveal
        first <- Ref.read mounting
        Ref.write false mounting
        if opensInPlace { first, seen, height: h, target } then do
          write height target
          started <- read entryStarted
          unless started $ waveRings do
            write entryStarted true
            beginEntry
        else do
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

  runEffectFn4 watchPairImpl (read layout) (read appearanceOrder) rebuild true

  onUnmounted do
    clearEntryTimer
    stopPulse pulseDeps
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
    , hasHighlight
    , hovered
    , ringRadii
    , ringsSettled
    , spokeProgress
    , wrapperStyle
    , pos: mkEffectFn1 (posOf <<< toMaybe)
    , litLink: mkEffectFn1 litLinkOf
    , ringRadius: mkEffectFn2 \ringIndex radius -> do
        settled <- read ringsSettled
        if settled then pure radius
        else (\radii -> ringRadiusAt settled radii ringIndex radius) <$> read ringRadii
    , spokeTip: mkEffectFn1 \spoke -> do
        progress <- read spokeProgress
        pure (spokeTipAt progress spoke)
    , linkState: mkEffectFn1 \link -> do
        highlight <- read hasHighlight
        lit <- if highlight then litLinkOf link else pure false
        pure (linkClasses (linkPrereqImpl link) highlight lit)
    , nodeShown: mkEffectFn1 \nodeId -> do
        appeared <- read appearedSet
        pure (has appeared nodeId)
    , nodeGlowing: mkEffectFn1 \nodeId -> do
        glow <- read glowSet
        if has glow nodeId then pure true else litHas nodeId
    , nodeDimmed: mkEffectFn1 \nodeId -> do
        highlight <- read hasHighlight
        if highlight then not <$> litHas nodeId else pure false
    , hover: mkEffectFn1 (write hovered)
    , onDragStart: mkEffectFn2 (onDragStart dragDeps)
    , onDragMove: mkEffectFn2 (onDragMove dragDeps)
    , onDragEnd: mkEffectFn1 (onDragEnd dragDeps)
    }
