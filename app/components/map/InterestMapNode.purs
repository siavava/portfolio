-- | ## InterestMapNode
-- |
-- | The setup composable behind `InterestMapNode.vue`: label line
-- | splitting and measurement, the pulse-ripple animation, connection
-- | registration, and pointer-drag state. The SFC keeps only the compiler
-- | macros, template refs, and the connections-store handle.
module App.Components.InterestMapNode
  ( HitBox
  , LabelBox
  , LabelEl
  , MapNodeData
  , NodeArgs
  , NodeBindings
  , PointerEvt
  , PulseEl
  , useInterestMapNode
  ) where

import Prelude

import Data.Array (length, slice) as Array
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.String (Pattern(..), joinWith, split)
import Data.String.CodeUnits as CU
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Timer (setTimeout)
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn1, runEffectFn1, runEffectFn2)
import Vue
  ( Computed
  , Ref
  , computed
  , onMounted
  , onUnmounted
  , read
  , ref
  , watchGetter
  , write
  )

foreign import data LabelEl :: Type
foreign import data MapNodeData :: Type
foreign import data PointerEvt :: Type
foreign import data PulseEl :: Type

foreign import nodeLabelImpl :: MapNodeData -> String
foreign import nodeLevelImpl :: MapNodeData -> Int
foreign import labelSideBelowImpl :: MapNodeData -> Boolean
foreign import prefersReducedMotionImpl :: Effect Boolean
foreign import animatePulseImpl :: EffectFn2 PulseEl Number Unit
foreign import getBBoxImpl :: EffectFn1 LabelEl LabelBox
foreign import onFontsReadyImpl :: EffectFn1 (Effect Unit) Unit
foreign import capturePointerImpl :: EffectFn1 PointerEvt Unit
foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit

type LabelBox = { x :: Number, y :: Number, width :: Number, height :: Number }

type HitBox = { x :: Int, y :: Int, width :: Int, height :: Int }

type NodeArgs =
  { node :: Effect MapNodeData
  , compact :: Effect Boolean
  , pulseTick :: Effect Int
  , pulseRing :: Ref (Nullable PulseEl)
  , label :: Ref (Nullable LabelEl)
  , registerNode :: EffectFn1 String Unit
  , unregisterNode :: EffectFn1 String Unit
  , emitDragstart :: EffectFn1 PointerEvt Unit
  , emitDragmove :: EffectFn1 PointerEvt Unit
  , emitDragend :: Effect Unit
  }

type NodeBindings =
  { dotRadius :: Computed Number
  , showLabel :: Computed Boolean
  , lines :: Computed (Array String)
  , labelBox :: Ref (Nullable LabelBox)
  , labelY :: Computed Int
  , hitBox :: Computed HitBox
  , onPointerdown :: EffectFn1 PointerEvt Unit
  , onPointermove :: EffectFn1 PointerEvt Unit
  , onPointerup :: Effect Unit
  }

-- | Split a label onto two lines at the middle word once it outgrows a
-- | single short word group.
splitLines :: String -> Array String
splitLines label =
  if Array.length words < 2 || CU.length label <= 11 then [ label ]
  else
    [ joinWith " " (Array.slice 0 middle words)
    , joinWith " " (Array.slice middle (Array.length words) words)
    ]
  where
  words = split (Pattern " ") label
  middle = (Array.length words + 1) / 2

padBox :: LabelBox -> LabelBox
padBox box =
  { x: box.x - padX
  , y: box.y - padY
  , width: box.width + padX * 2.0
  , height: box.height + padY * 2.0
  }
  where
  padX = 5.0
  padY = 2.0

useInterestMapNode :: EffectFn1 NodeArgs NodeBindings
useInterestMapNode = mkEffectFn1 setup

setup :: NodeArgs -> Effect NodeBindings
setup args = do
  dotRadius <- computed do
    node <- args.node
    pure (if nodeLevelImpl node == 1 then 3.0 else 2.5)

  _ <- watchGetter args.pulseTick \tick _ -> do
    ring <- toMaybe <$> read args.pulseRing
    case ring of
      Just el | tick /= 0 -> do
        reduced <- prefersReducedMotionImpl
        unless reduced do
          r <- read dotRadius
          node <- args.node
          void (setTimeout ((nodeLevelImpl node - 1) * 100) (runEffectFn2 animatePulseImpl el r))
      _ -> pure unit

  showLabel <- computed do
    compact <- args.compact
    node <- args.node
    pure (not compact || nodeLevelImpl node == 1)

  lines <- computed (splitLines <<< nodeLabelImpl <$> args.node)

  labelBox <- ref (null :: Nullable LabelBox)

  let
    measureLabel = do
      el <- toMaybe <$> read args.label
      case el of
        Nothing -> write labelBox null
        Just labelEl -> do
          box <- runEffectFn1 getBBoxImpl labelEl
          write labelBox (notNull (padBox box))

  onMounted do
    node <- args.node
    runEffectFn1 args.registerNode (nodeLabelImpl node)
    runEffectFn1 nextTickImpl do
      measureLabel
      runEffectFn1 onFontsReadyImpl measureLabel

  onUnmounted do
    node <- args.node
    runEffectFn1 args.unregisterNode (nodeLabelImpl node)

  _ <- watchGetter
    ( do
        l <- read lines
        s <- read showLabel
        pure { l, s }
    )
    \_ _ -> runEffectFn1 nextTickImpl measureLabel

  labelY <- computed do
    node <- args.node
    if labelSideBelowImpl node then pure 16
    else do
      ls <- read lines
      pure (if Array.length ls > 1 then (-19) else (-8))

  hitBox <- computed do
    node <- args.node
    ls <- read lines
    let tall = Array.length ls > 1
    pure
      ( if labelSideBelowImpl node then
          { x: -24, y: -10, width: 48, height: if tall then 44 else 34 }
        else
          { x: -24, y: if tall then -34 else -24, width: 48, height: if tall then 44 else 34 }
      )

  dragging <- Ref.new false

  let
    onPointerdown event = do
      Ref.write true dragging
      runEffectFn1 args.emitDragstart event
      runEffectFn1 capturePointerImpl event

    onPointermove event = do
      isDragging <- Ref.read dragging
      when isDragging (runEffectFn1 args.emitDragmove event)

    onPointerup = do
      isDragging <- Ref.read dragging
      when isDragging do
        Ref.write false dragging
        args.emitDragend

  pure
    { dotRadius
    , showLabel
    , lines
    , labelBox
    , labelY
    , hitBox
    , onPointerdown: mkEffectFn1 onPointerdown
    , onPointermove: mkEffectFn1 onPointermove
    , onPointerup
    }
