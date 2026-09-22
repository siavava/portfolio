-- | ## TimelineTarget
-- |
-- | The setup composable behind `TimelineTarget.vue`: a phrase in the bio
-- | that belongs to a year on the timeline. Hovering it lifts a preview of
-- | that year out of the page — above the phrase, dropping below it only
-- | when there is no room above — and holds the preview open while the
-- | pointer crosses the gap into it. The SFC keeps the prop macro, the template
-- | ref, the store handle, and the router move plus one call here.
module App.Components.TimelineTarget
  ( DomElement
  , Placement
  , TargetArgs
  , TargetBindings
  , setup
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.Traversable (sequence)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Timer (TimeoutId, clearTimeout, setTimeout)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , mkEffectFn1
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  )
import Vue (Ref, onUnmounted, read, ref, write)

-- | An `HTMLElement` — opaque here; only the FFI touches it. @ts HTMLElement
foreign import data DomElement :: Type

-- | Where the preview goes: its viewport position, and whether it hangs
-- | above the phrase (the default) or had to drop below.
type Placement =
  { left :: Number
  , top :: Number
  , above :: Boolean
  }

-- | The preview's placement for the phrase's current rect and a preview of
-- | the given width and height.
foreign import placementImpl :: EffectFn3 DomElement Number Number Placement

-- | Reports the preview's height once now and again after every size
-- | change; returns the stop thunk.
foreign import observeHeightImpl :: EffectFn2 DomElement (EffectFn1 Number Unit) (Effect Unit)

-- | Vue's `nextTick` with a callback, result discarded.
foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit

-- | Whether the primary pointer can hover at all.
foreign import canHoverImpl :: Effect Boolean

-- | Runs the action on any pointer-down outside both elements; returns the
-- | remove thunk.
foreign import onOutsidePressImpl
  :: EffectFn2 (Effect (Array (Nullable DomElement))) (Effect Unit) (Effect Unit)

-- | The preview's width in px, and a guess at its height — both needed for
-- | a placement before the preview has rendered.
peekWidth :: Number
peekWidth = 300.0

guessedHeight :: Number
guessedHeight = 240.0

-- | How long the preview lingers after the pointer leaves, so it can be
-- | crossed into.
graceMs :: Int
graceMs = 220

type TargetArgs =
  { -- | Template ref to the phrase `<span>`.
    el :: Ref (Nullable DomElement)
  -- | Template ref to the preview, once shown.
  , peek :: Ref (Nullable DomElement)
  -- | Navigate to the timeline, landed on this year.
  , open :: Effect Unit
  }

type TargetBindings =
  { -- | Whether the preview is up.
    shown :: Ref Boolean
  -- | Where the preview sits; null until first shown.
  , placement :: Ref (Nullable Placement)
  -- | Pointer entered the phrase or the preview: show, or cancel a pending
  -- | close.
  , enter :: Effect Unit
  -- | Pointer left: close after the grace.
  , leave :: Effect Unit
  -- | The phrase was pressed. With a hovering pointer that goes straight
  -- | to the timeline; on touch, where there is no hover to preview with,
  -- | the first press shows the preview and its own link opens the year.
  , press :: Effect Unit
  }

-- | Wires a timeline target: the hover-held preview with its placement, and
-- | the press that opens the year outright where hover already previews it.
setup :: TargetArgs -> Effect TargetBindings
setup args = do
  shown <- ref false
  placement <- ref (null :: Nullable Placement)
  closeTimer <- Ref.new (Nothing :: Maybe TimeoutId)
  watching <- Ref.new (Nothing :: Maybe (Effect Unit))

  let
    cancelClose = Ref.read closeTimer >>= case _ of
      Just pending -> clearTimeout pending *> Ref.write Nothing closeTimer
      Nothing -> pure unit

    stopWatching = Ref.read watching >>= case _ of
      Just stop -> stop *> Ref.write Nothing watching
      Nothing -> pure unit

    dismiss = stopWatching *> write shown false

    place height = do
      anchor <- read args.el
      case toMaybe anchor of
        Just element -> do
          spot <- runEffectFn3 placementImpl element peekWidth height
          write placement (notNull spot)
        Nothing -> pure unit

    -- The guess picks the side for the first frame. The preview's real
    -- height picks the side that keeps it — and keeps picking, since the
    -- body renders in after the frame and grows the box.
    show = do
      cancelClose
      up <- read shown
      unless up do
        place guessedHeight
        write shown true
        runEffectFn1 nextTickImpl do
          rendered <- read args.peek
          case toMaybe rendered of
            Just element -> do
              stop <- runEffectFn2 observeHeightImpl element (mkEffectFn1 place)
              Ref.write (Just stop) watching
            Nothing -> pure unit

    hide = cancelClose *> dismiss

    leave = do
      cancelClose
      pending <- setTimeout graceMs dismiss
      Ref.write (Just pending) closeTimer

    press = do
      hovering <- canHoverImpl
      if hovering then args.open
      else do
        up <- read shown
        if up then hide else show

  unbind <- runEffectFn2 onOutsidePressImpl
    (sequence [ read args.el, read args.peek ])
    hide

  onUnmounted (cancelClose *> stopWatching *> unbind)

  pure { shown, placement, enter: show, leave, press }
