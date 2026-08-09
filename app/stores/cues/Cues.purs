-- | ## Cues
-- |
-- | Store core powering the bio cue threads linking root words to their
-- | marks: cue marks register their elements by name, roots activate (on
-- | hover) or pin (on click) the marks they point at, and the overlay
-- | draws a rope per active group. The pinia shell is
-- | `defineStore("cues", useCuesCore)`.
module App.Stores.Cues
  ( CueGroup
  , CuesBindings
  , DomElement
  , ReactiveMap
  , useCuesCore
  ) where

import Prelude

import Data.Array (concatMap, filterA, null, snoc) as Array
import Data.Function.Uncurried (Fn2, runFn2)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Effect (Effect)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , mkEffectFn1
  , mkEffectFn2
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  )
import Vue (Computed, Ref, computed, read, shallowRef, write)

-- | A `shallowReactive(new Map<k, v>())` from Vue.
foreign import data ReactiveMap :: Type -> Type -> Type

-- | A DOM `Element`. @ts Element
foreign import data DomElement :: Type

-- | A fresh shallow-reactive `Map`.
foreign import newReactiveMapImpl :: forall k v. Effect (ReactiveMap k v)

-- | `map.set(key, value)`.
foreign import mapSetImpl :: forall k v. EffectFn3 (ReactiveMap k v) k v Unit

-- | `map.delete(key)`.
foreign import mapDeleteImpl :: forall k v. EffectFn2 (ReactiveMap k v) k Unit

-- | `map.has(key)` — a tracked (reactive) read.
foreign import mapHasImpl :: forall k v. EffectFn2 (ReactiveMap k v) k Boolean

-- | `map.clear()`.
foreign import mapClearImpl :: forall k v. EffectFn1 (ReactiveMap k v) Unit

-- | The map's entries as `{ key, value }` pairs — a tracked read.
foreign import mapEntriesImpl
  :: forall k v. EffectFn1 (ReactiveMap k v) (Array { key :: k, value :: v })

-- | Reference equality (`===`) on DOM elements.
foreign import sameElementImpl :: Fn2 DomElement DomElement Boolean

-- | A root element together with the mark names it lights up.
type CueGroup = { root :: DomElement, targets :: Array String }

-- | The cue store's public surface.
type CuesBindings =
  { -- | Mark name → mounted element, registered by cue marks.
    marks :: ReactiveMap String DomElement
  , -- | The hovered root's group, or null while nothing is hovered.
    hovered :: Ref (Nullable CueGroup)
  , -- | Pinned root element → the mark names it holds lit.
    pinned :: ReactiveMap DomElement (Array String)
  , -- | Every active group: the pins, plus the hovered group if unpinned.
    groups :: Computed (Array CueGroup)
  , -- | Mark names across all active groups — the overlay's draw list.
    activeTargets :: Computed (Array String)
  , -- | Whether a root drives the hovered group or holds a pin.
    isActive :: EffectFn1 (Nullable DomElement) Boolean
  , -- | Register a mark element under its name (on mount).
    registerMark :: EffectFn2 String DomElement Unit
  , -- | Drop a mark by name (on unmount).
    unregisterMark :: EffectFn1 String Unit
  , -- | Hover a root, activating the registered subset of its targets.
    activate :: EffectFn2 DomElement (Array String) Unit
  , -- | Clear the hovered group.
    deactivate :: Effect Unit
  , -- | Clear the hover and every pin (route change).
    reset :: Effect Unit
  , -- | Pin or unpin a root's targets (on click).
    togglePin :: EffectFn2 DomElement (Array String) Unit
  }

-- | Assembles the cue store: the mark registry, hover and pin state, and
-- | the derived groups and targets the rope overlay draws from.
useCuesCore :: Effect CuesBindings
useCuesCore = do
  marks <- newReactiveMapImpl :: Effect (ReactiveMap String DomElement)
  hovered <- shallowRef (null :: Nullable CueGroup)
  pinned <- newReactiveMapImpl :: Effect (ReactiveMap DomElement (Array String))

  let
    knownTargets = Array.filterA (runEffectFn2 mapHasImpl marks)

    activate root targets = do
      known <- knownTargets targets
      unless (Array.null known) (write hovered (notNull { root, targets: known }))

    togglePin root targets = runEffectFn2 mapHasImpl pinned root >>= case _ of
      true -> runEffectFn2 mapDeleteImpl pinned root
      false -> do
        known <- knownTargets targets
        unless (Array.null known) (runEffectFn3 mapSetImpl pinned root known)

    -- Whether a root drives the hovered group or holds a pin; the
    -- pinned lookup only runs when the hover check misses, exactly
    -- like the original short-circuit.
    isActive rootN = case toMaybe rootN of
      Nothing -> pure false
      Just root -> do
        current <- read hovered
        case toMaybe current of
          Just group | runFn2 sameElementImpl group.root root -> pure true
          _ -> runEffectFn2 mapHasImpl pinned root

  groups <- computed do
    entries <- runEffectFn1 mapEntriesImpl pinned
    let out = map (\entry -> { root: entry.key, targets: entry.value }) entries
    current <- read hovered
    case toMaybe current of
      Just group -> runEffectFn2 mapHasImpl pinned group.root <#> case _ of
        true -> out
        false -> Array.snoc out group
      Nothing -> pure out

  activeTargets <- computed (read groups <#> Array.concatMap _.targets)

  pure
    { marks
    , hovered
    , pinned
    , groups
    , activeTargets
    , isActive: mkEffectFn1 isActive
    , registerMark: mkEffectFn2 (runEffectFn3 mapSetImpl marks)
    , unregisterMark: mkEffectFn1 (runEffectFn2 mapDeleteImpl marks)
    , activate: mkEffectFn2 activate
    , deactivate: write hovered null
    , reset: write hovered null *> runEffectFn1 mapClearImpl pinned
    , togglePin: mkEffectFn2 togglePin
    }
