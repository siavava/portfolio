-- | ## DraggableBubble
-- |
-- | Pointer-drag for review bubbles: they live in the grid but can be
-- | picked up and tossed anywhere. The most recently grabbed bubble
-- | climbs a shared z-index stack (module state in the FFI) so it stays
-- | on top. When the layout collapses to a single column, a motion-v
-- | spring returns any tossed bubble to its resting place.
module App.Composables.DraggableBubble
  ( BubbleBindings
  , DomElement
  , PointerEvt
  , Vec2
  , dragTranslation
  , setup
  , springsHome
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn1, runEffectFn1, runEffectFn2)
import Vue (Ref, read, ref, watchRef, write)

-- | The draggable element (an `HTMLElement`). @ts HTMLElement
foreign import data DomElement :: Type

-- | A raw `PointerEvent`. @ts PointerEvent
foreign import data PointerEvt :: Type

-- | The `reactive({ x, y })` translation object the template reads.
foreign import data Vec2 :: Type

foreign import newVec2Impl :: Effect Vec2

foreign import getXImpl :: EffectFn1 Vec2 Number

foreign import getYImpl :: EffectFn1 Vec2 Number

foreign import setXImpl :: EffectFn2 Vec2 Number Unit

foreign import setYImpl :: EffectFn2 Vec2 Number Unit

foreign import useMediaQueryImpl :: EffectFn1 String (Ref Boolean)

foreign import startSpringImpl :: EffectFn1 (EffectFn1 Number Unit) (Effect Unit)

foreign import nextStackImpl :: Effect Int

foreign import capturePointerImpl :: EffectFn2 (Nullable DomElement) PointerEvt Unit

foreign import pointerXImpl :: PointerEvt -> Number

foreign import pointerYImpl :: PointerEvt -> Number

type BubbleBindings =
  { -- | The accumulated drag translation the template binds as a transform.
    offset :: Vec2
  , -- | Whether a drag is live.
    dragging :: Ref Boolean
  , -- | The bubble's stack position, raised on each grab.
    zIndex :: Ref Int
  , -- | The pointer handlers to `v-on` onto the element.
    handlers ::
      { pointerdown :: EffectFn1 PointerEvt Unit
      , pointermove :: EffectFn1 PointerEvt Unit
      , pointerup :: Effect Unit
      , pointercancel :: Effect Unit
      }
  }

-- | The translation while dragging: the offset the bubble had when it
-- | was grabbed, moved by however far the pointer has travelled since.
dragTranslation
  :: { x :: Number, y :: Number }
  -> { x :: Number, y :: Number }
  -> { x :: Number, y :: Number }
  -> { x :: Number, y :: Number }
dragTranslation base start pointer =
  { x: base.x + pointer.x - start.x
  , y: base.y + pointer.y - start.y
  }

-- | Whether the bubble springs back to its resting place: only on the
-- | collapse to a single column, and only when it was tossed somewhere.
springsHome :: Boolean -> Number -> Number -> Boolean
springsHome mobile x y = not (not mobile || (x == 0.0 && y == 0.0))

-- | ## useDraggableBubble
-- |
-- | ### Parameters
-- |
-- | | Param | Type | Description |
-- | | --- | --- | --- |
-- | | `el` | `Ref<HTMLElement \| null>` | The draggable element |
-- |
-- | ### Returns
-- |
-- | `{ offset, dragging, zIndex, handlers }` — the accumulated
-- | translation, drag state, z-index, and the pointer handlers to `v-on`
-- | onto the element.
setup :: Ref (Nullable DomElement) -> Effect BubbleBindings
setup el = do
  offset <- newVec2Impl
  dragging <- ref false
  zIndex <- ref 0
  singleColumn <- runEffectFn1 useMediaQueryImpl "(max-width: 900px)"
  pointerStart <- Ref.new { x: 0.0, y: 0.0 }
  offsetStart <- Ref.new { x: 0.0, y: 0.0 }
  resetAnimation <- Ref.new (Nothing :: Maybe (Effect Unit))

  let
    stopReset = Ref.read resetAnimation >>= case _ of
      Just stop -> stop
      Nothing -> pure unit

  _ <- watchRef singleColumn \mobile -> do
    startX <- runEffectFn1 getXImpl offset
    startY <- runEffectFn1 getYImpl offset
    when (springsHome mobile startX startY) do
      stopReset
      stop <- runEffectFn1 startSpringImpl $ mkEffectFn1 \t -> do
        runEffectFn2 setXImpl offset (startX * t)
        runEffectFn2 setYImpl offset (startY * t)
      Ref.write (Just stop) resetAnimation

  let
    onPointerdown event = do
      mobile <- read singleColumn
      unless mobile do
        stopReset
        write dragging true
        z <- nextStackImpl
        write zIndex z
        Ref.write { x: pointerXImpl event, y: pointerYImpl event } pointerStart
        x <- runEffectFn1 getXImpl offset
        y <- runEffectFn1 getYImpl offset
        Ref.write { x, y } offsetStart
        element <- read el
        runEffectFn2 capturePointerImpl element event

    onPointermove event = do
      isDragging <- read dragging
      when isDragging do
        start <- Ref.read pointerStart
        base <- Ref.read offsetStart
        let
          moved = dragTranslation base start { x: pointerXImpl event, y: pointerYImpl event }
        runEffectFn2 setXImpl offset moved.x
        runEffectFn2 setYImpl offset moved.y

    onPointerup = write dragging false

  pure
    { offset
    , dragging
    , zIndex
    , handlers:
        { pointerdown: mkEffectFn1 onPointerdown
        , pointermove: mkEffectFn1 onPointermove
        , pointerup: onPointerup
        , pointercancel: onPointerup
        }
    }
