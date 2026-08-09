-- | ## SideNote
-- |
-- | The setup composable behind `SideNote.vue`: visibility against the
-- | side-notes store, layout registration, and the reflow triggers —
-- | store changes and window resizes. The SFC keeps only the prop macro,
-- | template ref, and store/layout glue plus one call here.
module App.Components.SideNote
  ( DomElement
  , SideNoteArgs
  , SideNoteBindings
  , SideNotesStore
  , useSideNote
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn1, runEffectFn1, runEffectFn2)
import Vue
  ( Computed
  , Ref
  , computed
  , onMounted
  , onUnmounted
  , read
  , watchGetter
  )

foreign import data SideNotesStore :: Type
-- | A DOM `HTMLElement`. @ts HTMLElement
foreign import data DomElement :: Type

foreign import sideNotesIsVisibleImpl :: EffectFn2 SideNotesStore String Boolean
foreign import sideNotesHoveredImpl :: EffectFn1 SideNotesStore (Nullable String)
foreign import sideNotesPinnedSizeImpl :: EffectFn1 SideNotesStore Int
foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit
foreign import onWindowResizeImpl :: EffectFn1 (Effect Unit) (Effect Unit)

type SideNoteArgs =
  { el :: Ref (Nullable DomElement)
  , name :: Effect (Nullable String)
  , sideNotes :: SideNotesStore
  , register :: EffectFn2 String DomElement Unit
  , unregister :: EffectFn1 String Unit
  , relayoutVisible :: Effect Unit
  }

type SideNoteBindings = { visible :: Computed Boolean }

useSideNote :: EffectFn1 SideNoteArgs SideNoteBindings
useSideNote = mkEffectFn1 setup

setup :: SideNoteArgs -> Effect SideNoteBindings
setup args = do
  let
    -- The note name when present and non-empty — JS truthiness of
    -- `props.name`.
    presentName = do
      name <- args.name
      pure case toMaybe name of
        Just value | value /= "" -> Just value
        _ -> Nothing

    reflow = runEffectFn1 nextTickImpl args.relayoutVisible

  visible <- computed do
    presentName >>= case _ of
      Nothing -> pure true
      Just name -> runEffectFn2 sideNotesIsVisibleImpl args.sideNotes name

  onMounted do
    name <- presentName
    el <- read args.el
    case name, toMaybe el of
      Just trigger, Just target -> do
        runEffectFn2 args.register trigger target
        reflow
      _, _ -> pure unit

  onUnmounted do
    presentName >>= case _ of
      Just trigger -> runEffectFn1 args.unregister trigger
      Nothing -> pure unit

  _ <- watchGetter
    ( do
        hovered <- runEffectFn1 sideNotesHoveredImpl args.sideNotes
        size <- runEffectFn1 sideNotesPinnedSizeImpl args.sideNotes
        pure { hovered, size }
    )
    (\_ _ -> reflow)

  stopResize <- runEffectFn1 onWindowResizeImpl reflow
  onUnmounted stopResize

  pure { visible }
