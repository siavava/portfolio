-- | ## FigmaSelect
-- |
-- | The setup composable behind `FigmaSelect.vue`: measures the selection
-- | box on hover and drives the linked side note's reveal/pin state. The
-- | SFC keeps only the prop macro, template ref, and store handle plus one
-- | call here.
module App.Components.FigmaSelect
  ( DomElement
  , FigmaArgs
  , FigmaBindings
  , SideNotesStore
  , useFigmaSelect
  ) where

import Prelude

import Data.Int (round)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn1, runEffectFn1, runEffectFn2)
import Vue (Ref, read, ref, write)

foreign import data SideNotesStore :: Type
foreign import data DomElement :: Type

foreign import rectSizeImpl
  :: EffectFn1 (Nullable DomElement) (Nullable { width :: Number, height :: Number })

foreign import sideNotesActivateImpl :: EffectFn2 SideNotesStore String Unit
foreign import sideNotesDeactivateImpl :: EffectFn1 SideNotesStore Unit
foreign import sideNotesTogglePinImpl :: EffectFn2 SideNotesStore String Unit

type FigmaArgs =
  { el :: Ref (Nullable DomElement)
  , note :: Effect (Nullable String)
  , sideNotes :: SideNotesStore
  }

type FigmaBindings =
  { size :: Ref String
  , measure :: Effect Unit
  , leave :: Effect Unit
  , toggle :: Effect Unit
  }

useFigmaSelect :: EffectFn1 FigmaArgs FigmaBindings
useFigmaSelect = mkEffectFn1 setup

setup :: FigmaArgs -> Effect FigmaBindings
setup args = do
  size <- ref "0×0"
  let
    -- The note name when present and non-empty — JS truthiness of
    -- `props.note`.
    presentNote = do
      note <- args.note
      pure case toMaybe note of
        Just name | name /= "" -> Just name
        _ -> Nothing

    measure = do
      rect <- runEffectFn1 rectSizeImpl =<< read args.el
      case toMaybe rect of
        Just box -> write size (show (round box.width) <> "×" <> show (round box.height))
        Nothing -> pure unit
      presentNote >>= case _ of
        Just note -> runEffectFn2 sideNotesActivateImpl args.sideNotes note
        Nothing -> pure unit

    leave = presentNote >>= case _ of
      Just _ -> runEffectFn1 sideNotesDeactivateImpl args.sideNotes
      Nothing -> pure unit

    toggle = presentNote >>= case _ of
      Just note -> runEffectFn2 sideNotesTogglePinImpl args.sideNotes note
      Nothing -> pure unit

  pure { size, measure, leave, toggle }
