-- | ## TimelineTarget
-- |
-- | The setup composable behind `TimelineTarget.vue`: a phrase in the bio
-- | that belongs to a period on the timeline. Resting a pointer on it — a
-- | pass on the way elsewhere does not count — or tabbing to it lifts a
-- | preview of that period out of the page, above the phrase unless there
-- | is no room there. The preview is measured before it is shown, so it
-- | never changes sides while it enters, and it holds while the pointer
-- | crosses the gap into it. Escape puts it away. While a preview is up the
-- | name bar shows its year, through the timeline store. The SFC keeps the
-- | prop macro, the template refs, the content query, the id, and the
-- | store and router handles plus one call here.
module App.Components.TimelineTarget
  ( DomElement
  , IdRef
  , Landing
  , MouseEvt
  , Placement
  , Router
  , StyleMap
  , TargetArgs
  , TargetBindings
  , TimelineDoc
  , YearProp
  , descriptionFor
  , landingFor
  , peekEdge
  , peekGap
  , peekPlacement
  , periodMonth
  , setup
  ) where

import Prelude

import App.Components.Timeline (Node, monthLabel, onlyPeriod, periodPoint)
import Data.Array (find)
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe, toNullable)
import Data.Number (max, min) as Number
import Data.Traversable (sequence, traverse_)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Timer (TimeoutId, clearTimeout, setTimeout)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , mkEffectFn1
  , mkEffectFn2
  , runEffectFn1
  , runEffectFn2
  )
import Vue
  ( Computed
  , Ref
  , computed
  , onBeforeUnmount
  , onUnmounted
  , provide
  , read
  , ref
  , watchRef
  , write
  )

-- | An `HTMLElement` — opaque here; only the FFI touches it. @ts HTMLElement
foreign import data DomElement :: Type

-- | The `year` prop as it arrives: MDC hands it over as a string, a bound
-- | value as a number. @ts number | string
foreign import data YearProp :: Type

-- | A year's page from the timeline collection, as the content query
-- | returns it — opaque; field access happens in the FFI.
-- | @ts import("@nuxt/content").TimelineCollectionItem
foreign import data TimelineDoc :: Type

-- | The `vue-router` router. @ts import("vue-router").Router
foreign import data Router :: Type

-- | A raw `MouseEvent`. @ts MouseEvent
foreign import data MouseEvt :: Type

-- | An id reference for an ARIA attribute, or none — `undefined` rather
-- | than null, which is what the attribute's binding accepts.
-- | @ts string | undefined
foreign import data IdRef :: Type

-- | An assembled `:style` object. @ts Record<string, string>
foreign import data StyleMap :: Type

-- | Where the preview goes: its left edge, and the edge it hangs from — its
-- | bottom edge's distance from the viewport's bottom when it sits above
-- | the phrase (the default), its top when it had to drop below. Anchoring
-- | the edge nearest the phrase keeps the card against it as it grows.
type Placement =
  { left :: Number
  , edge :: Number
  , above :: Boolean
  }

-- | Where the timeline route lands: the year, and the period's month
-- | label when the phrase is about one period — null leaves it off the
-- | query altogether.
type Landing =
  { year :: Int
  , period :: Nullable String
  }

foreign import anchorRectImpl
  :: EffectFn1 DomElement { left :: Number, top :: Number, bottom :: Number }

foreign import viewportImpl :: Effect { width :: Number, height :: Number }

foreign import observeHeightImpl
  :: EffectFn2 DomElement (EffectFn2 Number Boolean Unit) (Effect Unit)

foreign import revealImpl :: EffectFn2 DomElement Boolean Unit

foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit

foreign import canHoverImpl :: Effect Boolean

foreign import focusVisibleImpl :: EffectFn1 DomElement Boolean

foreign import hoveredImpl :: EffectFn1 (Nullable DomElement) Boolean

foreign import onOutsidePressImpl
  :: EffectFn2 (Effect (Array (Nullable DomElement))) (Effect Unit) (Effect Unit)

foreign import onEscapeImpl :: EffectFn1 (Effect Unit) (Effect Unit)

foreign import yearOfImpl :: YearProp -> Int

foreign import docYearImpl :: TimelineDoc -> Int

foreign import docNodesImpl :: TimelineDoc -> Array Node

foreign import withNodesImpl :: Fn2 TimelineDoc (Array Node) TimelineDoc

foreign import hrefImpl :: EffectFn2 Router Landing String

foreign import pushImpl :: EffectFn2 Router Landing Unit

foreign import plainClickImpl :: MouseEvt -> Boolean

foreign import preventDefaultImpl :: EffectFn1 MouseEvt Unit

foreign import idRefImpl :: Nullable String -> IdRef

foreign import peekStyleImpl :: Placement -> StyleMap

peekWidth :: Number
peekWidth = 300.0

guessedHeight :: Number
guessedHeight = 240.0

-- | The space between the phrase and the preview, and the least the
-- | preview keeps from the viewport's edges, in px.
peekGap :: Number
peekGap = 8.0

peekEdge :: Number
peekEdge = 12.0

-- | Hangs the card from the edge nearest the phrase: above, its bottom sits
-- | `peekGap` over the phrase (as a distance from the viewport's bottom, so
-- | the card grows upward and away); below, its top sits `peekGap` under
-- | it. Above wins whenever the card clears the viewport's top by
-- | `peekEdge`, and its left edge keeps `peekEdge` from both sides — the
-- | right-hand clamp last, so a viewport too narrow for the card pins it
-- | there.
peekPlacement
  :: { left :: Number, top :: Number, bottom :: Number }
  -> { width :: Number, height :: Number }
  -> Number
  -> Number
  -> Placement
peekPlacement rect view width height =
  { left: Number.min (Number.max peekEdge rect.left) (view.width - width - peekEdge)
  , edge: if above then view.height - rect.top + peekGap else rect.bottom + peekGap
  , above
  }
  where
  above = rect.top - peekGap - height >= peekEdge

-- | The month of the period a `period` prop names, if it names one.
periodMonth :: Nullable String -> Nullable Int
periodMonth period = toNullable (_.month <$> (toMaybe period >>= toMaybe <<< periodPoint))

-- | Where the timeline route lands for a year and, when the phrase is
-- | about one period, the month it began — named by its three-letter label.
landingFor :: Int -> Nullable Int -> Landing
landingFor year month =
  { year, period: toNullable (monthLabel <<< show <$> toMaybe month) }

-- | The phrase's accessible description: the year it belongs to, on the
-- | timeline.
descriptionFor :: Int -> String
descriptionFor year = show year <> " on the timeline"

intentMs :: Int
intentMs = 120

graceMs :: Int
graceMs = 220

patienceMs :: Int
patienceMs = 400

type TargetArgs =
  { -- | Reads the `year` prop: the year this phrase belongs to.
    year :: Effect YearProp
  -- | Reads the `period` prop: the month of the period within that year
  -- | the phrase is about, when it is about one period rather than the
  -- | whole year — `Jun`.
  , period :: Effect (Nullable String)
  -- | Reads the timeline's pages, earliest year first.
  , docs :: Effect (Array TimelineDoc)
  -- | The preview's element id, which the phrase names as its description
  -- | while the preview is up.
  , peekId :: String
  -- | Template ref to the phrase `<span>`.
  , el :: Ref (Nullable DomElement)
  -- | Template ref to the preview, once shown.
  , peek :: Ref (Nullable DomElement)
  -- | The router the preview's link and the phrase's press go through.
  , router :: Router
  -- | The timeline store's `focus`: a preview of this year is up.
  , focusYear :: EffectFn1 Int Unit
  -- | The timeline store's `blur`: the preview of this year closed.
  , blurYear :: EffectFn1 Int Unit
  }

type TargetBindings =
  { -- | The year this phrase belongs to, as a number.
    year :: Computed Int
  -- | The page the preview shows: the year's, cut down to the one period
  -- | when the phrase is about one; null when the year has none.
  , doc :: Computed (Nullable TimelineDoc)
  -- | Where the preview's link goes: the timeline, landed on this period.
  , href :: Computed String
  -- | The phrase's accessible description — its own words are its name;
  -- | the timeline is what it adds.
  , description :: Computed String
  -- | The preview's element id.
  , peekId :: String
  -- | The phrase's `aria-describedby`: the preview's id while it is up.
  , describedBy :: Computed IdRef
  -- | Whether the preview is up.
  , shown :: Ref Boolean
  -- | Whether it has been measured and may be seen.
  , ready :: Ref Boolean
  -- | Where the preview sits; null until first shown.
  , placement :: Ref (Nullable Placement)
  -- | The preview's position as a `:style`; null until first shown.
  , peekStyle :: Computed (Nullable StyleMap)
  -- | The pointer came to rest on the phrase, or entered the preview:
  -- | show, or cancel a pending close. Touch has no hover and ignores it.
  , enter :: Effect Unit
  -- | Pointer left: close after the grace.
  , leave :: Effect Unit
  -- | The phrase took focus: keyboard focus shows the preview at once.
  , focus :: Effect Unit
  -- | The phrase lost focus: a preview that focus opened closes after the
  -- | grace, unless the pointer has come to rest on it. A tap focuses the
  -- | phrase too, but what it opens is closed by a press elsewhere.
  , blur :: Effect Unit
  -- | The phrase was pressed. With a hovering pointer that goes straight
  -- | to the timeline; on touch, where there is no hover to preview with,
  -- | a press toggles the preview and its own link opens the period.
  , press :: Effect Unit
  -- | Put the preview away and go to the timeline.
  , open :: Effect Unit
  -- | A click on the preview's link. A plain click goes through the
  -- | preview's own close-and-open; a modified one (a new tab, a new
  -- | window) is the browser's.
  , follow :: EffectFn1 MouseEvt Unit
  }

-- | Wires a timeline target: the preview held up by hover or focus, placed
-- | and measured before it shows, and the press that opens the period
-- | outright where hover already previews it. The year is provided to the
-- | periods the preview renders, which label a run past New Year from it.
setup :: TargetArgs -> Effect TargetBindings
setup args = do
  year <- computed (yearOfImpl <$> args.year)
  month <- computed (periodMonth <$> args.period)

  provide "timeline-year" year

  doc <- computed do
    entries <- args.docs
    wanted <- read year
    within <- toMaybe <$> read month
    let
      trim found = case within of
        Just at -> runFn2 withNodesImpl found (onlyPeriod at (docNodesImpl found))
        Nothing -> found
    pure (toNullable (trim <$> find (\entry -> docYearImpl entry == wanted) entries))

  landing <- computed (landingFor <$> read year <*> read month)

  href <- computed (runEffectFn2 hrefImpl args.router =<< read landing)
  description <- computed (descriptionFor <$> read year)

  shown <- ref false
  ready <- ref false
  placement <- ref (null :: Nullable Placement)
  timer <- Ref.new (Nothing :: Maybe TimeoutId)
  patience <- Ref.new (Nothing :: Maybe TimeoutId)
  watching <- Ref.new ([] :: Array (Effect Unit))
  byFocus <- Ref.new false

  describedBy <- computed do
    up <- read shown
    pure (idRefImpl (if up then notNull args.peekId else null))

  peekStyle <- computed (toNullable <<< map peekStyleImpl <<< toMaybe <$> read placement)

  let
    clear cell = do
      Ref.read cell >>= traverse_ clearTimeout
      Ref.write Nothing cell

    cancelTimer = clear timer

    later ms action = do
      cancelTimer
      pending <- setTimeout ms action
      Ref.write (Just pending) timer

    stopWatching = do
      clear patience
      stops <- Ref.read watching
      Ref.write [] watching
      traverse_ identity stops

    dismiss = do
      cancelTimer
      stopWatching
      Ref.write false byFocus
      write ready false
      write shown false

    place height = do
      anchor <- read args.el
      case toMaybe anchor of
        Just element -> do
          rect <- runEffectFn1 anchorRectImpl element
          view <- viewportImpl
          write placement (notNull (peekPlacement rect view peekWidth height))
        Nothing -> pure unit

    reveal = do
      settled <- read ready
      unless settled do
        write ready true
        spot <- toMaybe <$> read placement
        card <- toMaybe <$> read args.peek
        case card, spot of
          Just element, Just placed -> runEffectFn1 nextTickImpl
            (runEffectFn2 revealImpl element placed.above)
          _, _ -> pure unit

    display = do
      cancelTimer
      up <- read shown
      unless up do
        write ready false
        place guessedHeight
        write shown true
        runEffectFn1 nextTickImpl do
          rendered <- read args.peek
          case toMaybe rendered of
            Just element -> do
              stop <- runEffectFn2 observeHeightImpl element $ mkEffectFn2 \height filled -> do
                place height
                when filled reveal
              escape <- runEffectFn1 onEscapeImpl dismiss
              Ref.write [ stop, escape ] watching
              waiting <- setTimeout patienceMs reveal
              Ref.write (Just waiting) patience
            Nothing -> pure unit

    hovering action = do
      can <- canHoverImpl
      when can action

    enter = hovering do
      up <- read shown
      if up then cancelTimer else later intentMs display

    leave = hovering (later graceMs dismiss)

    focus = do
      anchor <- toMaybe <$> read args.el
      case anchor of
        Just element -> do
          keyboard <- runEffectFn1 focusVisibleImpl element
          when keyboard do
            display
            Ref.write true byFocus
        Nothing -> pure unit

    blur = do
      opened <- Ref.read byFocus
      resting <- runEffectFn1 hoveredImpl =<< read args.peek
      when (opened && not resting) (later graceMs dismiss)

    -- The bar lets go of the year before the route changes under it.
    open = do
      dismiss
      read year >>= runEffectFn1 args.blurYear
      read landing >>= runEffectFn2 pushImpl args.router

    press = do
      can <- canHoverImpl
      if can then open
      else do
        up <- read shown
        if up then dismiss else display

    follow = mkEffectFn1 \event ->
      when (plainClickImpl event) do
        runEffectFn1 preventDefaultImpl event
        open

  unbind <- runEffectFn2 onOutsidePressImpl
    (sequence [ read args.el, read args.peek ])
    dismiss

  onUnmounted (dismiss *> unbind)

  _ <- watchRef shown \up ->
    read year >>= runEffectFn1 (if up then args.focusYear else args.blurYear)
  onBeforeUnmount (read year >>= runEffectFn1 args.blurYear)

  pure
    { year
    , doc
    , href
    , description
    , peekId: args.peekId
    , describedBy
    , shown
    , ready
    , placement
    , peekStyle
    , enter
    , leave
    , focus
    , blur
    , press
    , open
    , follow
    }
