-- | ## FigureSpotlight
-- |
-- | Click-to-spotlight for article figures. Clicking a (non-algorithm,
-- | non-visualizer) figure opens it large on a card over the blurred
-- | page; the EXIT button, a backdrop click, or Escape close it. Page
-- | scroll locks while open. The click and key listeners attach on
-- | mount and tear down on unmount. DOM primitives live behind the FFI
-- | edge; the predicates and lifecycle wiring live here.
module App.Composables.FigureSpotlight
  ( DomElement
  , FigSpotlight
  , KeyEvt
  , MouseEvt
  , SpotlightBindings
  , closesSpotlight
  , setup
  , spotlightCapWidth
  , spotlightOrdinal
  ) where

import Prelude

import Data.Array (findIndex)
import Data.Foldable (for_)
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Int as Int
import Data.Maybe (Maybe(..), fromMaybe, isJust, isNothing)
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn1, runEffectFn1, runEffectFn2)
import Vue (Ref, onBeforeUnmount, onMounted, read, ref, write)

-- | A DOM `HTMLElement`. @ts HTMLElement
foreign import data DomElement :: Type
-- | A raw `MouseEvent`. @ts MouseEvent
foreign import data MouseEvt :: Type
-- | A raw `KeyboardEvent`. @ts KeyboardEvent
foreign import data KeyEvt :: Type

foreign import figuresInImpl :: EffectFn2 (Nullable DomElement) String (Array DomElement)

foreign import cloneImpl :: EffectFn1 DomElement DomElement

foreign import removeAllImpl :: EffectFn2 DomElement String Unit

foreign import outerHtmlImpl :: EffectFn1 DomElement String

foreign import innerHtmlImpl :: EffectFn1 DomElement String

foreign import querySelectorImpl :: EffectFn2 DomElement String (Nullable DomElement)

foreign import rectWidthImpl :: EffectFn1 DomElement Number

foreign import setRootOverflowImpl :: EffectFn1 String Unit

foreign import targetOfImpl :: EffectFn1 MouseEvt DomElement

foreign import closestImpl :: EffectFn2 DomElement String (Nullable DomElement)

foreign import containsImpl :: EffectFn2 DomElement DomElement Boolean

foreign import keyOfImpl :: EffectFn1 KeyEvt String

foreign import refEqImpl :: Fn2 DomElement DomElement Boolean

foreign import addClickImpl :: EffectFn2 DomElement (EffectFn1 MouseEvt Unit) Unit

foreign import removeClickImpl :: EffectFn2 DomElement (EffectFn1 MouseEvt Unit) Unit

foreign import addKeydownImpl :: EffectFn1 (EffectFn1 KeyEvt Unit) Unit

foreign import removeKeydownImpl :: EffectFn1 (EffectFn1 KeyEvt Unit) Unit

-- | A figure opened into the spotlight — mirrors the global
-- | `FigSpotlightState` shape.
type FigSpotlight =
  { -- | The cloned figure markup, caption nodes stripped.
    html :: String
  , -- | The caption's inner HTML; `""` when the figure has none.
    caption :: String
  , -- | 1-based index among the article's spotlightable figures.
    n :: Int
  , -- | Caption card width: the figure's width clamped to 260–560px.
    capWidth :: Int
  }

type SpotlightBindings =
  { -- | The open figure; null while the spotlight is closed.
    spotlight :: Ref (Nullable FigSpotlight)
  , -- | Close the spotlight and restore page scroll.
    close :: Effect Unit
  }

captionSelector :: String
captionSelector = ".fig-cap, .tikz-cap, figcaption"

interactiveSelector :: String
interactiveSelector = "a, button, input, select, textarea, [class*=visualiser], [class*=visualizer]"

figureSelector :: String
figureSelector = "figure:not(.algorithm)"

-- | The caption card's width for a figure `width` pixels wide: the
-- | figure's width clamped to 260–560px, rounded to whole pixels.
spotlightCapWidth :: Number -> Int
spotlightCapWidth width = Int.round (min 560.0 (max 260.0 width))

-- | The 1-based position of the first figure matching `isFig` among the
-- | article's spotlightable figures; 0 when none matches.
spotlightOrdinal :: forall a. (a -> Boolean) -> Array a -> Int
spotlightOrdinal isFig figs = 1 + fromMaybe (-1) (findIndex isFig figs)

-- | Whether a keypress closes the spotlight: Escape, while one is open.
closesSpotlight :: String -> Boolean -> Boolean
closesSpotlight key open = key == "Escape" && open

-- | Wire the spotlight over `content`: clicks on qualifying figures
-- | open it, Escape (or `close`) dismisses it, and the listeners attach
-- | on mount and tear down on unmount.
setup :: Ref (Nullable DomElement) -> Effect SpotlightBindings
setup content = do
  spotlight <- ref (null :: Nullable FigSpotlight)

  let
    open fig = do
      contentEl <- read content
      figs <- runEffectFn2 figuresInImpl contentEl figureSelector
      clone <- runEffectFn1 cloneImpl fig
      runEffectFn2 removeAllImpl clone captionSelector
      html <- runEffectFn1 outerHtmlImpl clone
      mCap <- toMaybe <$> runEffectFn2 querySelectorImpl fig captionSelector
      caption <- case mCap of
        Just cap -> runEffectFn1 innerHtmlImpl cap
        Nothing -> pure ""
      width <- runEffectFn1 rectWidthImpl fig
      let
        n = spotlightOrdinal (\f -> runFn2 refEqImpl f fig) figs
        capWidth = spotlightCapWidth width
      write spotlight (notNull { html, caption, n, capWidth })
      runEffectFn1 setRootOverflowImpl "hidden"

    close = do
      write spotlight null
      runEffectFn1 setRootOverflowImpl ""

    onClick event = do
      target <- runEffectFn1 targetOfImpl event
      interactive <- runEffectFn2 closestImpl target interactiveSelector
      when (isNothing (toMaybe interactive)) do
        mFig <- toMaybe <$> runEffectFn2 closestImpl target figureSelector
        for_ mFig \fig -> do
          mContentEl <- toMaybe <$> read content
          inContent <- case mContentEl of
            Just el -> runEffectFn2 containsImpl el fig
            Nothing -> pure false
          when inContent do
            visual <- runEffectFn2 querySelectorImpl fig "svg, img, picture"
            when (isJust (toMaybe visual)) (open fig)

    onKey event = do
      key <- runEffectFn1 keyOfImpl event
      current <- read spotlight
      when (closesSpotlight key (isJust (toMaybe current))) close

    clickHandler = mkEffectFn1 onClick
    keyHandler = mkEffectFn1 onKey

  onMounted do
    mContentEl <- toMaybe <$> read content
    for_ mContentEl \el -> runEffectFn2 addClickImpl el clickHandler
    runEffectFn1 addKeydownImpl keyHandler
  onBeforeUnmount do
    mContentEl <- toMaybe <$> read content
    for_ mContentEl \el -> runEffectFn2 removeClickImpl el clickHandler
    runEffectFn1 removeKeydownImpl keyHandler
    runEffectFn1 setRootOverflowImpl ""

  pure { spotlight, close }
