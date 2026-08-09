-- | ## ProjectShelf
-- |
-- | The setup composable behind `ProjectShelf.vue`: hover state machine,
-- | tooltip anchoring with edge-overflow shift, and center-on-select
-- | scrolling. The SFC keeps only what the compiler forces into TypeScript
-- | (`defineProps`/`defineEmits` macros, template refs) plus one call here.
module App.Components.ProjectShelf
  ( DomElement
  , MouseEvt
  , ShelfArgs
  , ShelfBindings
  , ShelfBook
  , StyleMap
  , setup
  ) where

import Prelude

import Data.Function.Uncurried (Fn3, runFn3)
import Data.Maybe (Maybe(..), isNothing)
import Data.Nullable (Nullable, notNull, null, toMaybe, toNullable)
import Data.Number.Format (toString)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Timer (TimeoutId, clearTimeout, setTimeout)
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn2, runEffectFn1, runEffectFn2)
import Vue (Ref, onMounted, onUnmounted, read, ref, watchGetter, write)

-- | A DOM `HTMLElement`. @ts HTMLElement
foreign import data DomElement :: Type

-- | A raw `MouseEvent`. @ts MouseEvent
foreign import data MouseEvt :: Type

-- | An assembled `:style` object. @ts Record<string, string>
foreign import data StyleMap :: Type

-- | The event's `currentTarget` viewport rect: left, top, width.
foreign import rectOfEventTargetImpl
  :: EffectFn1 MouseEvt { left :: Number, top :: Number, width :: Number }

-- | Half the rendered tooltip bubble's width, or null before it exists.
foreign import tooltipHalfWidthImpl :: EffectFn1 (Nullable DomElement) (Nullable Number)

-- | `window.innerWidth`.
foreign import windowInnerWidthImpl :: Effect Number

-- | Assembles the tooltip `:style` object: left/top anchor plus the
-- | optional `--shelf-tt-x`/`--shelf-tt-arrow` shift variables.
foreign import mkStyleImpl :: Fn3 String String (Nullable { x :: String, arrow :: String }) StyleMap

-- | The scroll left that centers the `.selected` book, or null when
-- | nothing is selected or the shelf doesn't overflow.
foreign import centerTargetImpl :: EffectFn1 DomElement (Nullable { left :: Number })

-- | `scrollTo` with `behavior: "instant"`.
foreign import instantScrollImpl :: EffectFn2 DomElement Number Unit

-- | Eased horizontal scroll to the given left (`glideScroll`).
foreign import glideToImpl :: EffectFn2 DomElement Number Unit

-- | Vue's `nextTick` with a callback, result discarded.
foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit

-- | Adds a capturing, passive scroll listener on window; returns the
-- | remove thunk (manual cleanup — no-op stub during SSR).
foreign import onWindowScrollImpl :: EffectFn1 (Effect Unit) (Effect Unit)

-- | One spine on the shelf.
type ShelfBook = { path :: String, title :: String, date :: String }

type ShelfArgs =
  { -- | Template ref to the outer shelf wrapper (tooltip lives in it).
    viewport :: Ref (Nullable DomElement)
  -- | Template ref to the scrollable spine row.
  , shelf :: Ref (Nullable DomElement)
  -- | Reads the `selectedPath` prop; null when nothing is selected.
  , selectedPath :: Effect (Nullable String)
  }

type ShelfBindings =
  { -- | The book under the pointer; null hides the tooltip.
    hovered :: Ref (Nullable ShelfBook)
  -- | The most recent hovered book — keeps the tooltip text mounted
  -- | through the fade-out.
  , lastHovered :: Ref (Nullable ShelfBook)
  -- | True when the tooltip should jump (fresh hover) instead of glide
  -- | between spines.
  , tooltipSnap :: Ref Boolean
  -- | Tooltip inline style: anchor position and edge-shift variables.
  , tooltipStyle :: Ref StyleMap
  -- | Mouseenter handler: anchors the tooltip over the spine, shifted
  -- | back inside the window edges.
  , hover :: EffectFn2 ShelfBook MouseEvt Unit
  -- | Mouseleave handler: hides the tooltip after a 120 ms grace delay.
  , unhover :: Effect Unit
  }

px :: Number -> String
px n = toString n <> "px"

-- | Wires the shelf's hover state machine and tooltip anchoring with
-- | edge-overflow shift, hides the tooltip on any window scroll, and
-- | centers the selected spine — instantly on mount, gliding on later
-- | selection changes.
setup :: ShelfArgs -> Effect ShelfBindings
setup args = do
  hovered <- ref (null :: Nullable ShelfBook)
  lastHovered <- ref (null :: Nullable ShelfBook)
  tooltipSnap <- ref false
  tooltipStyle <- ref (runFn3 mkStyleImpl "0px" "0px" (toNullable Nothing))
  hideTimer <- Ref.new (Nothing :: Maybe TimeoutId)
  anchor <- Ref.new { left: "0px", top: "0px" }
  shiftVars <- Ref.new (Nothing :: Maybe { x :: String, arrow :: String })

  let
    clearHide = Ref.read hideTimer >>= case _ of
      Just pending -> clearTimeout pending *> Ref.write Nothing hideTimer
      Nothing -> pure unit

    applyStyle = do
      a <- Ref.read anchor
      vars <- Ref.read shiftVars
      write tooltipStyle (runFn3 mkStyleImpl a.left a.top (toNullable vars))

    centerBook smooth = runEffectFn1 nextTickImpl do
      mShelf <- toMaybe <$> read args.shelf
      case mShelf of
        Nothing -> pure unit
        Just el -> do
          target <- toMaybe <$> runEffectFn1 centerTargetImpl el
          case target of
            Nothing -> pure unit
            Just t
              | smooth -> runEffectFn2 glideToImpl el t.left
              | otherwise -> runEffectFn2 instantScrollImpl el t.left

    hover book event = do
      clearHide
      current <- read hovered
      write tooltipSnap (isNothing (toMaybe current))
      rect <- runEffectFn1 rectOfEventTargetImpl event
      let centerX = rect.left + rect.width / 2.0
      Ref.write { left: px centerX, top: px rect.top } anchor
      applyStyle
      write hovered (notNull book)
      write lastHovered (notNull book)
      runEffectFn1 nextTickImpl do
        vp <- read args.viewport
        mHalf <- toMaybe <$> runEffectFn1 tooltipHalfWidthImpl vp
        case mHalf of
          Nothing -> pure unit
          Just halfWidth -> do
            winWidth <- windowInnerWidthImpl
            let
              edgePad = 8.0
              overflowLeft = halfWidth - centerX + edgePad
              overflowRight = centerX + halfWidth - (winWidth - edgePad)
              shift =
                if overflowLeft > 0.0 then overflowLeft
                else if overflowRight > 0.0 then -overflowRight
                else 0.0
            Ref.write
              ( Just
                  { x: "calc(-50% + " <> px shift <> ")", arrow: "calc(50% - " <> px shift <> ")" }
              )
              shiftVars
            applyStyle

    unhover = do
      clearHide
      pending <- setTimeout 120 (write hovered null)
      Ref.write (Just pending) hideTimer

  stopScroll <- runEffectFn1 onWindowScrollImpl (write hovered null)
  _ <- watchGetter args.selectedPath \_ previous -> centerBook (not isNothing (toMaybe previous))
  onMounted (centerBook false)
  onUnmounted (clearHide *> stopScroll)

  pure
    { hovered
    , lastHovered
    , tooltipSnap
    , tooltipStyle
    , hover: mkEffectFn2 hover
    , unhover
    }
