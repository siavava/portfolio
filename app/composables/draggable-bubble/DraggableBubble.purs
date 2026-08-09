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
  , setup
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

-- | A fresh `reactive({ x: 0, y: 0 })`.
foreign import newVec2Impl :: Effect Vec2

-- | Read the x translation — a reactive read Vue can track.
foreign import getXImpl :: EffectFn1 Vec2 Number

-- | Read the y translation — a reactive read Vue can track.
foreign import getYImpl :: EffectFn1 Vec2 Number

-- | Write the x translation.
foreign import setXImpl :: EffectFn2 Vec2 Number Unit

-- | Write the y translation.
foreign import setYImpl :: EffectFn2 Vec2 Number Unit

-- | VueUse `useMediaQuery`: a ref tracking whether the query matches
-- | (`false` during SSR).
foreign import useMediaQueryImpl :: EffectFn1 String (Ref Boolean)

-- | Run a motion-v spring from 1 to 0, feeding each frame's value to the
-- | callback; returns the Effect that stops the animation.
foreign import startSpringImpl :: EffectFn1 (EffectFn1 Number Unit) (Effect Unit)

-- | The next value off the shared z-index stack (module state, so the
-- | latest grab tops every bubble on the page).
foreign import nextStackImpl :: Effect Int

-- | `setPointerCapture` on the element (no-op when null), so the drag
-- | keeps receiving moves outside the bubble.
foreign import capturePointerImpl :: EffectFn2 (Nullable DomElement) PointerEvt Unit

-- | The pointer's `clientX`.
foreign import pointerXImpl :: PointerEvt -> Number

-- | The pointer's `clientY`.
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

  -- On collapse to a single column, spring any tossed bubble back home.
  _ <- watchRef singleColumn \mobile -> do
    startX <- runEffectFn1 getXImpl offset
    startY <- runEffectFn1 getYImpl offset
    unless (not mobile || (startX == 0.0 && startY == 0.0)) do
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
        runEffectFn2 setXImpl offset (base.x + pointerXImpl event - start.x)
        runEffectFn2 setYImpl offset (base.y + pointerYImpl event - start.y)

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
