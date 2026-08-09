-- | ## ReaderPeeks
-- |
-- | The study reader's two hover overlays, ported to the desk: a
-- | figure's hidden caption floats as a "fig n." card, and a link into
-- | the notes site floats that lesson's title and summary. Both are
-- | backed by the build-time notes index and are wiped whenever the page
-- | scrolls (fixed positioning goes stale) or the reader clears out.
module App.Composables.ReaderPeeks
  ( CardInstance
  , DomElement
  , FigPeek
  , MouseEvt
  , PeekStyle
  , PeeksBindings
  , RefPeek
  , useReaderPeeks
  ) where

import Prelude

import App.Utils.MarkdownMath (renderInlineMath)
import Data.Function.Uncurried (Fn2, Fn3, Fn4, runFn2, runFn3, runFn4)
import Data.Int as Int
import Data.Maybe (Maybe(..), isJust)
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.String (Pattern(..), stripPrefix)
import Data.String.CodeUnits as CU
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
import Vue (Ref, read, ref, requestFrame, write)

-- | A DOM `HTMLElement`. @ts HTMLElement
foreign import data DomElement :: Type

-- | A raw `MouseEvent`. @ts MouseEvent
foreign import data MouseEvt :: Type

-- | Whatever Vue hands a function template ref (component instance,
-- | element, or null).
foreign import data CardInstance :: Type

-- | A `Record<string, string>` of fixed-position style declarations.
foreign import data PeekStyle :: Type

-- | One lesson's metadata in the notes-site index.
type NotesMetaEntry = { title :: String, "module" :: String, summary :: String }

-- | Caption markup, running figure number, and viewport rect of a
-- | peekable figure — null when the caption is missing or blank.
type FigData = { html :: String, n :: Int, left :: Number, top :: Number, width :: Number }

foreign import lookupNotesMetaImpl :: String -> Nullable NotesMetaEntry
foreign import urlPathnameImpl :: String -> String
foreign import mouseXImpl :: MouseEvt -> Number
foreign import closestAnchorImpl :: EffectFn1 MouseEvt (Nullable DomElement)
foreign import closestFigureImpl :: EffectFn1 MouseEvt (Nullable DomElement)
foreign import hrefAttrImpl :: EffectFn1 DomElement String
foreign import sameElementImpl :: Fn2 (Nullable DomElement) (Nullable DomElement) Boolean
foreign import peekableFigureImpl :: EffectFn2 DomElement (Nullable DomElement) Boolean
foreign import figPeekDataImpl :: EffectFn2 DomElement (Nullable DomElement) (Nullable FigData)
foreign import cardRootImpl :: CardInstance -> Nullable DomElement
foreign import linkRectImpl :: EffectFn1 DomElement { top :: Number, bottom :: Number }
foreign import cardHeightImpl :: EffectFn1 (Nullable DomElement) Number
foreign import windowInnerWidthImpl :: Effect Number
foreign import windowInnerHeightImpl :: Effect Number
foreign import pxImpl :: Number -> String
foreign import figStyleImpl :: Fn3 String String String PeekStyle
foreign import refStyleImpl :: Fn4 String String (Nullable String) (Nullable String) PeekStyle
foreign import onDeskEventImpl
  :: EffectFn3 (Ref (Nullable DomElement)) String (EffectFn1 MouseEvt Unit) Unit

foreign import onScrollCaptureImpl :: EffectFn1 (Effect Unit) Unit
foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit

-- | Floating figure-caption card state.
type FigPeek = { html :: String, n :: Int, style :: PeekStyle }

-- | Floating notes-reference card state.
type RefPeek = { "module" :: String, title :: String, summaryHtml :: String, style :: PeekStyle }

type PeeksBindings =
  { figPeek :: Ref (Nullable FigPeek)
  , refPeek :: Ref (Nullable RefPeek)
  , refVisible :: Ref Boolean
  , bindRefCard :: EffectFn1 CardInstance Unit
  , clearPeeks :: Effect Unit
  }

refW :: Number
refW = 330.0

refGap :: Number
refGap = 10.0

refDelayMs :: Int
refDelayMs = 1000

notesPrefix :: String
notesPrefix = "https://notes.amittai.studio/"

stripTrailingSlashes :: String -> String
stripTrailingSlashes s =
  if CU.takeRight 1 s == "/" then stripTrailingSlashes (CU.dropRight 1 s) else s

metaFor :: String -> Nullable NotesMetaEntry
metaFor href = case stripPrefix (Pattern notesPrefix) href of
  Nothing -> null
  Just _ -> lookupNotesMetaImpl (stripTrailingSlashes (urlPathnameImpl href))

pxRound :: Number -> String
pxRound n = show (Int.round n) <> "px"

-- | ## useReaderPeeks
-- |
-- | ### Parameters
-- |
-- | | Name | Type | Description |
-- | | --- | --- | --- |
-- | | `desk` | `Ref<HTMLElement \| null>` | The reading surface to watch |
-- |
-- | ### Returns
-- |
-- | | Name | Type | Description |
-- | | --- | --- | --- |
-- | | `figPeek` | `Ref<FigPeekState \| null>` | Floating figure-caption card |
-- | | `refPeek` | `Ref<RefPeekState \| null>` | Floating reference card |
-- | | `refVisible` | `Ref<boolean>` | Fade state for the reference card |
-- | | `bindRefCard` | `(c: unknown) => void` | Template ref for the card element |
-- | | `clearPeeks` | `() => void` | Dismiss both overlays |
useReaderPeeks :: EffectFn1 (Ref (Nullable DomElement)) PeeksBindings
useReaderPeeks = mkEffectFn1 setup

setup :: Ref (Nullable DomElement) -> Effect PeeksBindings
setup desk = do
  figPeek <- ref (null :: Nullable FigPeek)
  refPeek <- ref (null :: Nullable RefPeek)
  refVisible <- ref false
  refCard <- Ref.new (null :: Nullable DomElement)
  refTimer <- Ref.new (Nothing :: Maybe TimeoutId)
  refHideTimer <- Ref.new (Nothing :: Maybe TimeoutId)
  refLink <- Ref.new (null :: Nullable DomElement)
  refMouseX <- Ref.new 0.0

  let
    showFigPeek fig = do
      deskEl <- read desk
      figData <- runEffectFn2 figPeekDataImpl fig deskEl
      case toMaybe figData of
        Nothing -> write figPeek null
        Just d -> write figPeek $ notNull
          { html: d.html
          , n: d.n
          , style: runFn3 figStyleImpl
              (pxImpl (d.left + d.width / 2.0))
              (pxImpl (max 8.0 (d.top - 10.0)))
              (pxImpl (min 560.0 (max 260.0 d.width)))
          }

    clearRef = do
      Ref.read refTimer >>= case _ of
        Just pending -> clearTimeout pending *> Ref.write Nothing refTimer
        Nothing -> pure unit
      Ref.write null refLink
      peek <- read refPeek
      when (isJust (toMaybe peek)) do
        write refVisible false
        Ref.read refHideTimer >>= case _ of
          Just pending -> clearTimeout pending
          Nothing -> pure unit
        hide <- setTimeout 170 do
          write refPeek null
          Ref.write Nothing refHideTimer
        Ref.write (Just hide) refHideTimer

    positionRef = do
      peekN <- read refPeek
      linkN <- Ref.read refLink
      case toMaybe peekN, toMaybe linkN of
        Just peek, Just link -> do
          rect <- runEffectFn1 linkRectImpl link
          mouseX <- Ref.read refMouseX
          winWidth <- windowInnerWidthImpl
          let left = min (max 12.0 (mouseX - refW / 2.0)) (winWidth - refW - 12.0)
          card <- Ref.read refCard
          height <- runEffectFn1 cardHeightImpl card
          style <-
            if height == 0.0 || rect.top - height - refGap >= 8.0 then do
              winHeight <- windowInnerHeightImpl
              pure
                ( runFn4 refStyleImpl (pxRound left) (pxImpl refW) null
                    (notNull (pxRound (winHeight - rect.top + refGap)))
                )
            else
              pure
                ( runFn4 refStyleImpl (pxRound left) (pxImpl refW)
                    (notNull (pxRound (rect.bottom + refGap)))
                    null
                )
          write refPeek (notNull (peek { style = style }))
        _, _ -> pure unit

    showRefPeek link = do
      href <- runEffectFn1 hrefAttrImpl link
      case toMaybe (metaFor href) of
        Nothing -> pure unit
        Just meta -> do
          Ref.read refHideTimer >>= case _ of
            Just pending -> clearTimeout pending *> Ref.write Nothing refHideTimer
            Nothing -> pure unit
          write refVisible false
          write refPeek $ notNull
            { "module": meta."module"
            , title: meta.title
            , summaryHtml: renderInlineMath meta.summary
            , style: runFn4 refStyleImpl "-9999px" (pxImpl refW) (notNull "0px") null
            }
          runEffectFn1 nextTickImpl do
            positionRef
            void $ requestFrame (write refVisible true)

    clearPeeks = do
      write figPeek null
      clearRef

    onMouseover event = do
      Ref.write (mouseXImpl event) refMouseX
      linkN <- runEffectFn1 closestAnchorImpl event
      metaLink <- case toMaybe linkN of
        Just link -> do
          href <- runEffectFn1 hrefAttrImpl link
          pure (if isJust (toMaybe (metaFor href)) then Just link else Nothing)
        Nothing -> pure Nothing
      case metaLink of
        Just link -> do
          current <- Ref.read refLink
          unless (runFn2 sameElementImpl (notNull link) current) do
            clearRef
            Ref.write (notNull link) refLink
            pending <- setTimeout refDelayMs (showRefPeek link)
            Ref.write (Just pending) refTimer
          write figPeek null
        Nothing -> do
          current <- Ref.read refLink
          when (isJust (toMaybe current)) clearRef
          figN <- runEffectFn1 closestFigureImpl event
          deskEl <- read desk
          peekable <- case toMaybe figN of
            Just fig -> runEffectFn2 peekableFigureImpl fig deskEl
            Nothing -> pure false
          case toMaybe figN of
            Just fig | peekable -> showFigPeek fig
            _ -> write figPeek null

    onMousemove event = do
      Ref.write (mouseXImpl event) refMouseX
      visible <- read refVisible
      peek <- read refPeek
      when (visible && isJust (toMaybe peek)) positionRef

  runEffectFn3 onDeskEventImpl desk "mouseover" (mkEffectFn1 onMouseover)
  runEffectFn3 onDeskEventImpl desk "mousemove" (mkEffectFn1 onMousemove)
  runEffectFn3 onDeskEventImpl desk "mouseleave" (mkEffectFn1 \_ -> clearPeeks)
  runEffectFn1 onScrollCaptureImpl clearPeeks

  pure
    { figPeek
    , refPeek
    , refVisible
    , bindRefCard: mkEffectFn1 \card -> Ref.write (cardRootImpl card) refCard
    , clearPeeks
    }
