-- | ## CueRoot
-- |
-- | The setup composable behind `CueRoot.vue`: the hover/pin wiring that
-- | lights the root's cue marks and reveals its side note. The SFC keeps
-- | only the prop macro, template ref, and store handles plus one call
-- | here.
module App.Components.CueRoot
  ( CueRootArgs
  , CueRootBindings
  , CuesStore
  , DomElement
  , SideNotesStore
  , useCueRoot
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Data.String (Pattern(..), split, trim)
import Effect (Effect)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , mkEffectFn1
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  )
import Vue (Computed, Ref, computed, read)

foreign import data CuesStore :: Type
foreign import data SideNotesStore :: Type
foreign import data DomElement :: Type

foreign import cuesIsActiveImpl :: EffectFn2 CuesStore (Nullable DomElement) Boolean
foreign import cuesActivateImpl :: EffectFn3 CuesStore DomElement (Array String) Unit
foreign import cuesDeactivateImpl :: EffectFn1 CuesStore Unit
foreign import cuesTogglePinImpl :: EffectFn3 CuesStore DomElement (Array String) Unit
foreign import sideNotesActivateImpl :: EffectFn2 SideNotesStore String Unit
foreign import sideNotesDeactivateImpl :: EffectFn1 SideNotesStore Unit
foreign import sideNotesTogglePinImpl :: EffectFn2 SideNotesStore String Unit

type CueRootArgs =
  { el :: Ref (Nullable DomElement)
  , to :: Effect String
  , note :: Effect (Nullable String)
  , cues :: CuesStore
  , sideNotes :: SideNotesStore
  }

type CueRootBindings =
  { isActive :: Computed Boolean
  , enter :: Effect Unit
  , leave :: Effect Unit
  , toggle :: Effect Unit
  }

useCueRoot :: EffectFn1 CueRootArgs CueRootBindings
useCueRoot = mkEffectFn1 setup

setup :: CueRootArgs -> Effect CueRootBindings
setup args = do
  isActive <- computed do
    el <- read args.el
    runEffectFn2 cuesIsActiveImpl args.cues el

  let
    -- The note name when present and non-empty — JS truthiness of
    -- `props.note`.
    presentNote = do
      note <- args.note
      pure case toMaybe note of
        Just name | name /= "" -> Just name
        _ -> Nothing

    targets = do
      to <- args.to
      pure (map trim (split (Pattern ",") to))

    enter = do
      presentNote >>= case _ of
        Just note -> runEffectFn2 sideNotesActivateImpl args.sideNotes note
        Nothing -> pure unit
      el <- read args.el
      case toMaybe el of
        Just root -> do
          names <- targets
          runEffectFn3 cuesActivateImpl args.cues root names
        Nothing -> pure unit

    leave = do
      runEffectFn1 cuesDeactivateImpl args.cues
      presentNote >>= case _ of
        Just _ -> runEffectFn1 sideNotesDeactivateImpl args.sideNotes
        Nothing -> pure unit

    toggle = do
      el <- read args.el
      case toMaybe el of
        Just root -> do
          names <- targets
          runEffectFn3 cuesTogglePinImpl args.cues root names
        Nothing -> pure unit
      presentNote >>= case _ of
        Just note -> runEffectFn2 sideNotesTogglePinImpl args.sideNotes note
        Nothing -> pure unit

  pure { isActive, enter, leave, toggle }
