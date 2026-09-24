-- | ## SideNoteLayout
-- |
-- | Places margin notes beside the words that trigger them. Notes group
-- | by their positioning parent and sort by desired offset; a visible
-- | note sits at its desired offset or below the previous visible
-- | note's floor, whichever is lower, so stacked notes never overlap.
-- | The module-level note registry and every DOM measurement live
-- | behind the FFI edge; the placement math lives here.
module App.Composables.SideNoteLayout
  ( DomElement
  , SideNoteLayoutBindings
  , groupsOf
  , stackNote
  , useSideNoteLayout
  ) where

import Prelude

import Data.Array (filter, foldM, nub, sortWith)
import Data.Foldable (for_)
import Data.Number (infinity)
import Data.Number.Format (toString)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn1, runEffectFn1, runEffectFn2)

-- | An `HTMLElement` — opaque here; only the FFI touches it. @ts HTMLElement
foreign import data DomElement :: Type

foreign import registerImpl :: EffectFn2 String DomElement Unit

foreign import unregisterImpl :: EffectFn1 String Unit

foreign import measureImpl :: Effect (Array Measured)

foreign import setTopImpl :: EffectFn2 DomElement String Unit

type Measured =
  { name :: String
  , el :: DomElement
  , group :: Int
  , desired :: Number
  , height :: Number
  }

type SideNoteLayoutBindings =
  { -- | Register a note element under its name as it mounts.
    register :: EffectFn2 String DomElement Unit
  , -- | Remove a note by name on teardown.
    unregister :: EffectFn1 String Unit
  , -- | Re-place every note, given a visibility predicate by name.
    relayout :: EffectFn1 (EffectFn1 String Boolean) Unit
  }

gap :: Number
gap = 16.0

-- | The margin-note layout surface: register notes as they mount,
-- | unregister them on teardown, and `relayout` whenever visibility or
-- | geometry changes.
useSideNoteLayout :: Effect SideNoteLayoutBindings
useSideNoteLayout = pure
  { register: registerImpl
  , unregister: unregisterImpl
  , relayout: mkEffectFn1 relayout
  }

relayout :: EffectFn1 String Boolean -> Effect Unit
relayout isVisible = do
  measured <- measureImpl
  for_ (groupsOf measured) \group ->
    void $ foldM place (negate infinity) (sortWith _.desired group)
  where
  place floor note = do
    visible <- runEffectFn1 isVisible note.name
    let placed = stackNote floor { visible, desired: note.desired, height: note.height }
    runEffectFn2 setTopImpl note.el (toString placed.top <> "px")
    pure placed.floor

-- | Place one note under the running `floor` (the lowest offset the next
-- | visible note may take): a visible note sits at its desired offset or
-- | the floor, whichever is lower, and lifts the floor past itself plus
-- | the gap; a hidden note keeps its desired offset and leaves the floor
-- | where it was.
stackNote
  :: Number
  -> { visible :: Boolean, desired :: Number, height :: Number }
  -> { top :: Number, floor :: Number }
stackNote floor note =
  { top
  , floor: if note.visible then top + note.height + gap else floor
  }
  where
  top = if note.visible then max note.desired floor else note.desired

-- | Split the measurements into per-parent groups, preserving both the
-- | first-seen order of parents and the registration order within each.
groupsOf :: forall r. Array { group :: Int | r } -> Array (Array { group :: Int | r })
groupsOf measured = nub (map _.group measured) <#> \key ->
  filter (\note -> note.group == key) measured
