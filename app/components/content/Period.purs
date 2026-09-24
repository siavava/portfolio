-- | ## Period
-- |
-- | The setup composable behind `Period.vue`: one period of a year, the
-- | same markup on the rail, in the vertical column, and in the bio's
-- | preview slab. Every place a period renders provides its year. The
-- | timeline provides the period in the spotlight and the one that is hot;
-- | both layouts provide the heat a hover or focus reports, shared with the
-- | period's span on the line, and the pick that spotlights a period on a
-- | tap; the rail also folds a period with more than a headline down to
-- | it, opening it while the pointer rests there or once it is picked,
-- | its height eased open and shut. Whatever is not provided simply does not apply
-- | — the preview slab provides only the year. The SFC keeps the prop
-- | macro plus one call here.
module App.Components.Period
  ( MouseEvt
  , PeriodArgs
  , PointerEvt
  , PeriodBindings
  , Spot
  , WrittenMonth
  , folding
  , isPeriodAt
  , setup
  , spansMonths
  ) where

import Prelude

import App.Components.Timeline (DomElement, Folding, PeriodInfo, Pointer, periodInfo)
import App.Components.Timeline as Timeline
import Data.Array (elem)
import Data.Maybe (Maybe(..), isJust, maybe)
import Data.Nullable (Nullable, null, toMaybe, toNullable)
import Data.Traversable (traverse, traverse_)
import Effect (Effect)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn3
  , mkEffectFn1
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  )
import Vue (class Readable, Computed, Ref, computed, inject, read, ref, watchGetter, write)

-- | A month as the prop is written — `Jun`, `June`, `6`, `Feb 2026`: MDC
-- | hands over a string, a bound value may be a number.
-- | @ts string | number
foreign import data WrittenMonth :: Type

-- | A raw `MouseEvent`. @ts MouseEvent
foreign import data MouseEvt :: Type

-- | A raw `PointerEvent`. @ts PointerEvent
foreign import data PointerEvt :: Type

foreign import writtenImpl :: WrittenMonth -> String

foreign import onLinkImpl :: MouseEvt -> Boolean

foreign import onDetailImpl :: MouseEvt -> Boolean

foreign import selectingImpl :: Effect Boolean

foreign import isMouseImpl :: PointerEvt -> Boolean

foreign import pointerAtImpl :: PointerEvt -> Pointer

foreign import prefersReducedMotionImpl :: Effect Boolean

foreign import unfoldImpl :: EffectFn3 DomElement Boolean (Effect Unit) Unit

foreign import foldImpl :: EffectFn3 DomElement Boolean (Effect Unit) Unit

-- | A period named by where it starts and where it ends — the timeline's
-- | own `Spot`.
type Spot = Timeline.Spot

type Heat =
  { warm :: EffectFn1 Spot Unit
  , cool :: Effect Unit
  }

type PeriodArgs =
  { -- | Reads the `from` prop: the month it began.
    from :: Effect WrittenMonth
  -- | Reads the `to` prop: the month it ran to, when it spanned more than
  -- | one; with a year when it ran past New Year — `Feb 2026`.
  , to :: Effect (Nullable WrittenMonth)
  -- | Template ref to the period's body, whose height eases as it folds.
  , body :: Ref (Nullable DomElement)
  }

type PeriodBindings =
  { -- | Whether the period runs over more than one month.
    range :: Computed Boolean
  -- | Whether a tap on it spotlights it.
  , pickable :: Boolean
  -- | Whether it shows only its headline until opened: on the rail, when
  -- | it has more to say.
  , folds :: Computed Boolean
  -- | Whether it is open: picked, or held open by a resting pointer.
  , open :: Computed Boolean
  -- | Whether its detail is laid out — open, or still easing shut.
  , unfolded :: Ref Boolean
  -- | Whether it is the period in the spotlight.
  , lit :: Computed Boolean
  -- | Whether it is the period under the pointer or focus on the rail.
  , hot :: Computed Boolean
  -- | Whether it wears the accent: the spotlit period, unless another one
  -- | is hot.
  , shown :: Computed Boolean
  -- | The key naming it in the DOM, for `data-period`; null when the months
  -- | cannot be read.
  , key :: Computed (Nullable String)
  -- | The year it began, for `data-year`; null when the months cannot be
  -- | read.
  , year :: Computed (Nullable Int)
  -- | The month it began, for `data-month`.
  , month :: Computed (Nullable Int)
  -- | What its head shows — `jun – sep` — or the prop as written.
  , label :: Computed String
  -- | What a screen reader says instead — `June to September`.
  , spoken :: Computed String
  -- | The pointer or focus came onto the period: report it to the rail.
  , warm :: Effect Unit
  -- | And left it.
  , cool :: Effect Unit
  -- | A click on the period.
  , pick :: EffectFn1 MouseEvt Unit
  -- | A pointer moved over the period: a mouse coming to rest there opens
  -- | it, and folds whichever was open.
  , hover :: EffectFn1 PointerEvt Unit
  }

-- | Whether the period read is the one the spot names — the same start and
-- | end; never when either is missing. Open in the period's other fields,
-- | so the TS surface needs no `PeriodInfo` translation.
isPeriodAt
  :: forall r
   . Nullable Spot
  -> Nullable { year :: Int, month :: Int, endYear :: Int, endMonth :: Int | r }
  -> Boolean
isPeriodAt wanted period = case toMaybe wanted, toMaybe period of
  Just spot, Just found -> spot == Timeline.spotOf found
  _, _ -> false

-- | Whether a period keyed `key` folds to its headline, given the keys of
-- | those that have more to say — never where nothing folds, or when the
-- | period cannot be read.
folding :: Nullable (Array String) -> Nullable String -> Boolean
folding keys key = case toMaybe keys, toMaybe key of
  Just folded, Just own -> elem own folded
  _, _ -> false

-- | Whether the period read runs over more than one month; an unreadable
-- | one does not.
spansMonths :: forall r. Nullable { months :: Int | r } -> Boolean
spansMonths period = maybe false (_.months >>> (_ > 1)) (toMaybe period)

-- | Reads the period from its props and the year it is rendered under, and
-- | wires it to whatever the surrounding timeline provides.
setup :: PeriodArgs -> Effect PeriodBindings
setup args = do
  yearOf <- inject "timeline-year" (null :: Nullable (Computed Int))
  focusOf <- inject "timeline-focus" (null :: Nullable (Computed (Nullable Spot)))
  hotOf <- inject "timeline-hot" (null :: Nullable (Ref (Nullable Spot)))
  heat <- toMaybe <$> inject "timeline-heat" (null :: Nullable Heat)
  pickOf <- toMaybe <$> inject "timeline-pick" (null :: Nullable (EffectFn1 Spot Unit))
  foldOf <- toMaybe <$> inject "timeline-fold" (null :: Nullable Folding)

  info <- computed do
    home <- maybe (pure 0) read (toMaybe yearOf)
    from <- writtenImpl <$> args.from
    to <- map writtenImpl <<< toMaybe <$> args.to
    pure (toMaybe (periodInfo home from (toNullable to)))

  let
    spotOf :: forall box. Readable box => Nullable (box (Nullable Spot)) -> Effect (Maybe Spot)
    spotOf provided = case toMaybe provided of
      Just cell -> toMaybe <$> read cell
      Nothing -> pure Nothing

    matches :: Maybe Spot -> Maybe PeriodInfo -> Boolean
    matches wanted period = isPeriodAt (toNullable wanted) (toNullable period)

    isSpot :: forall box. Readable box => Nullable (box (Nullable Spot)) -> Effect Boolean
    isSpot provided = matches <$> spotOf provided <*> read info

    orWritten field = do
      period <- read info
      case period of
        Just found -> pure (field found)
        Nothing -> writtenImpl <$> args.from

    cool = traverse_ _.cool heat

  range <- computed (spansMonths <<< toNullable <$> read info)
  lit <- computed (isSpot focusOf)
  hot <- computed (isSpot hotOf)

  shown <- computed do
    spotlit <- isSpot focusOf
    if not spotlit then pure false
    else do
      other <- spotOf hotOf
      case other of
        Nothing -> pure true
        Just _ -> isSpot hotOf

  key <- computed (toNullable <<< map (Timeline.spotKey <<< Timeline.spotOf) <$> read info)
  folds <- computed do
    keys <- traverse (read <<< _.folded) foldOf
    folding (toNullable keys) <$> read key

  open <- computed do
    folded <- read folds
    spotlit <- isSpot focusOf
    resting <- traverse (read <<< _.rested) foldOf
    own <- read key
    let held = maybe false (\open -> isJust (toMaybe open) && open == own) resting
    pure (folded && (spotlit || held))

  unfolded <- ref =<< read open

  _ <- watchGetter (read open) \now _ -> do
    reduced <- prefersReducedMotionImpl
    element <- toMaybe <$> read args.body
    case element of
      Nothing -> write unfolded now
      Just body
        | now -> runEffectFn3 unfoldImpl body reduced (write unfolded true)
        | otherwise -> runEffectFn3 foldImpl body reduced (write unfolded false)
  year <- computed (toNullable <<< map _.year <$> read info)
  month <- computed (toNullable <<< map _.month <$> read info)
  label <- computed (orWritten _.label)
  spoken <- computed (orWritten _.spoken)

  let
    warm = do
      period <- read info
      case heat, period of
        Just rail, Just found -> runEffectFn1 rail.warm (Timeline.spotOf found)
        _, _ -> pure unit

    -- A finger never leaves the way a pointer does, so a second tap must also cool the heat.
    pick = mkEffectFn1 \event -> do
      period <- read info
      letting <- isSpot focusOf
      folded <- read folds
      selecting <- selectingImpl
      let reading = folded && letting && onDetailImpl event
      case pickOf, period of
        Just choose, Just found | not (onLinkImpl event || selecting || reading) -> do
          runEffectFn1 choose (Timeline.spotOf found)
          when letting cool
        _, _ -> pure unit

  let
    hover = mkEffectFn1 \event -> do
      period <- read info
      case foldOf, period of
        Just rail, Just found | isMouseImpl event ->
          runEffectFn2 rail.peek (Timeline.spotOf found) (pointerAtImpl event)
        _, _ -> pure unit

  pure
    { range
    , pickable: isJust pickOf
    , folds
    , open
    , unfolded
    , hover
    , lit
    , hot
    , shown
    , key
    , year
    , month
    , label
    , spoken
    , warm
    , cool
    , pick
    }
