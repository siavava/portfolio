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
  , setup
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import Vue
  ( Computed
  , Ref
  , computed
  , onMounted
  , onUnmounted
  , read
  , watchGetter
  )

-- | The `useSideNotes()` store handle — hover/pin visibility of named
-- | notes.
foreign import data SideNotesStore :: Type

-- | A DOM `HTMLElement`. @ts HTMLElement
foreign import data DomElement :: Type

-- | Whether the named note is currently hovered or pinned.
foreign import sideNotesIsVisibleImpl :: EffectFn2 SideNotesStore String Boolean

-- | The currently hovered note name, or null.
foreign import sideNotesHoveredImpl :: EffectFn1 SideNotesStore (Nullable String)

-- | How many notes are pinned.
foreign import sideNotesPinnedSizeImpl :: EffectFn1 SideNotesStore Int

-- | Vue's `nextTick` with a callback, result discarded.
foreign import nextTickImpl :: EffectFn1 (Effect Unit) Unit

-- | Adds a passive window resize listener; returns the remove thunk
-- | (manual cleanup — no-op stub during SSR).
foreign import onWindowResizeImpl :: EffectFn1 (Effect Unit) (Effect Unit)

type SideNoteArgs =
  { -- | Template ref to the rendered `<aside>`.
    el :: Ref (Nullable DomElement)
  -- | Reads the `name` prop; null/empty means an always-on note.
  , name :: Effect (Nullable String)
  -- | The side-notes store handle.
  , sideNotes :: SideNotesStore
  -- | Registers the note element with the layout under its trigger name.
  , register :: EffectFn2 String DomElement Unit
  -- | Drops the note from the layout.
  , unregister :: EffectFn1 String Unit
  -- | Repositions the currently visible notes (`useSideNoteLayout`).
  , relayoutVisible :: Effect Unit
  }

type SideNoteBindings =
  { -- | True while the note should show: always for unnamed notes,
    -- | otherwise while its trigger is hovered or pinned.
    visible :: Computed Boolean
  }

-- | Registers the note with the side-note layout for the component's
-- | lifetime, derives `visible` from the store, and re-lays out visible
-- | notes on store changes and window resizes.
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
