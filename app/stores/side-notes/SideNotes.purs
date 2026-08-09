-- | ## SideNotes
-- |
-- | Store core revealing margin side-notes while their trigger word is
-- | hovered (or pinned). The pinia shell is
-- | `defineStore("side-notes", useSideNotesCore)`.
module App.Stores.SideNotes
  ( SideNotesBindings
  , useSideNotesCore
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, mkEffectFn1)
import Vue
  ( ReactiveSet
  , Ref
  , reactiveSet
  , read
  , setAdd
  , setClear
  , setDelete
  , setHas
  , shallowRef
  , write
  )

type SideNotesBindings =
  { hovered :: Ref (Nullable String)
  , pinned :: ReactiveSet String
  , isVisible :: EffectFn1 String Boolean
  , activate :: EffectFn1 String Unit
  , deactivate :: Effect Unit
  , reset :: Effect Unit
  , togglePin :: EffectFn1 String Unit
  }

useSideNotesCore :: Effect SideNotesBindings
useSideNotesCore = do
  hovered <- shallowRef (null :: Nullable String)
  pinned <- reactiveSet
  let
    togglePin name = setHas pinned name >>= case _ of
      true -> setDelete pinned name
      false -> setAdd pinned name

    isVisible name = do
      current <- read hovered
      case toMaybe current of
        Just active | active == name -> pure true
        _ -> setHas pinned name

  pure
    { hovered
    , pinned
    , isVisible: mkEffectFn1 isVisible
    , activate: mkEffectFn1 \name -> write hovered (notNull name)
    , deactivate: write hovered null
    , reset: write hovered null *> setClear pinned
    , togglePin: mkEffectFn1 togglePin
    }
