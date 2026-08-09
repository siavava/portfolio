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

-- | One note measured against its trigger: `group` numbers positioning
-- | parents in first-seen order, `desired` is the trigger's offset from
-- | that parent's top, `height` the note's rendered height.
type Measured =
  { name :: String
  , el :: DomElement
  , group :: Int
  , desired :: Number
  , height :: Number
  }

type SideNoteLayoutBindings =
  { register :: EffectFn2 String DomElement Unit
  , unregister :: EffectFn1 String Unit
  , relayout :: EffectFn1 (EffectFn1 String Boolean) Unit
  }

-- | Vertical breathing room between stacked visible notes.
gap :: Number
gap = 16.0

useSideNoteLayout :: Effect SideNoteLayoutBindings
useSideNoteLayout = pure
  { register: registerImpl
  , unregister: unregisterImpl
  , relayout: mkEffectFn1 relayout
  }

-- | Re-place every registered note. Hidden notes keep their desired
-- | offset; visible notes push the floor down past themselves plus the
-- | gap.
relayout :: EffectFn1 String Boolean -> Effect Unit
relayout isVisible = do
  measured <- measureImpl
  for_ (groupsOf measured) \group ->
    void $ foldM place (negate infinity) (sortWith _.desired group)
  where
  place floor note = do
    visible <- runEffectFn1 isVisible note.name
    let top = if visible then max note.desired floor else note.desired
    runEffectFn2 setTopImpl note.el (toString top <> "px")
    pure (if visible then top + note.height + gap else floor)

-- | Split the measurements into per-parent groups, preserving both the
-- | first-seen order of parents and the registration order within each.
groupsOf :: Array Measured -> Array (Array Measured)
groupsOf measured = nub (map _.group measured) <#> \key ->
  filter (\note -> note.group == key) measured
