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
  , cueTargets
  , noteOf
  , setup
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.String (Pattern(..), split, trim)
import Effect (Effect)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  )
import Vue (Computed, Ref, computed, read)

-- | The `useCues()` store handle — hover activation and click pinning of
-- | cue groups.
foreign import data CuesStore :: Type

-- | The `useSideNotes()` store handle — hover/pin reveal of named notes.
foreign import data SideNotesStore :: Type

-- | A DOM `HTMLElement`. @ts HTMLElement
foreign import data DomElement :: Type

foreign import cuesIsActiveImpl :: EffectFn2 CuesStore (Nullable DomElement) Boolean

foreign import cuesActivateImpl :: EffectFn3 CuesStore DomElement (Array String) Unit

foreign import cuesDeactivateImpl :: EffectFn1 CuesStore Unit

foreign import cuesTogglePinImpl :: EffectFn3 CuesStore DomElement (Array String) Unit

foreign import sideNotesActivateImpl :: EffectFn2 SideNotesStore String Unit

foreign import sideNotesDeactivateImpl :: EffectFn1 SideNotesStore Unit

foreign import sideNotesTogglePinImpl :: EffectFn2 SideNotesStore String Unit

type CueRootArgs =
  { -- | Template ref to the rendered root `<span>`.
    el :: Ref (Nullable DomElement)
  -- | Reads the `to` prop: comma-separated cue mark names to light.
  , to :: Effect String
  -- | Reads the `note` prop: side-note name to reveal, if any.
  , note :: Effect (Nullable String)
  -- | The cues store handle.
  , cues :: CuesStore
  -- | The side-notes store handle.
  , sideNotes :: SideNotesStore
  }

type CueRootBindings =
  { -- | True while this root is hovered or pinned — the highlight class.
    isActive :: Computed Boolean
  -- | Mouseenter handler: activates the cue group and its side note.
  , enter :: Effect Unit
  -- | Mouseleave handler: clears hover state on both stores.
  , leave :: Effect Unit
  -- | Click handler: pins/unpins the cue group and its side note.
  , toggle :: Effect Unit
  }

-- | The note when present and non-empty — JS truthiness of
-- | `props.note`; null otherwise.
noteOf :: Nullable String -> Nullable String
noteOf value = case toMaybe value of
  Just text | text /= "" -> notNull text
  _ -> null

-- | The cue mark names a `to` prop lists: split on commas and trimmed.
cueTargets :: String -> Array String
cueTargets to = map trim (split (Pattern ",") to)

-- | Wires a cue root's hover/pin interactions: derives `isActive` from
-- | the cues store and returns the enter/leave/toggle handlers that
-- | activate or pin its marks and optional side note.
setup :: CueRootArgs -> Effect CueRootBindings
setup args = do
  isActive <- computed do
    el <- read args.el
    runEffectFn2 cuesIsActiveImpl args.cues el

  let
    presentNote = toMaybe <<< noteOf <$> args.note

    targets = cueTargets <$> args.to

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
