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
  , selectNoteOf
  , setup
  , sizeLabel
  ) where

import Prelude

import Data.Int (round)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import Vue (Ref, read, ref, write)

-- | The `useSideNotes()` store handle — hover/pin reveal of named notes.
foreign import data SideNotesStore :: Type

-- | A DOM `HTMLElement`. @ts HTMLElement
foreign import data DomElement :: Type

foreign import rectSizeImpl
  :: EffectFn1 (Nullable DomElement) (Nullable { width :: Number, height :: Number })

foreign import sideNotesActivateImpl :: EffectFn2 SideNotesStore String Unit

foreign import sideNotesDeactivateImpl :: EffectFn1 SideNotesStore Unit

foreign import sideNotesTogglePinImpl :: EffectFn2 SideNotesStore String Unit

type FigmaArgs =
  { -- | Template ref to the rendered selection `<span>`.
    el :: Ref (Nullable DomElement)
  -- | Reads the `note` prop: side-note name to reveal, if any.
  , note :: Effect (Nullable String)
  -- | The side-notes store handle.
  , sideNotes :: SideNotesStore
  }

type FigmaBindings =
  { -- | The "W×H" label text, rounded to whole pixels.
    size :: Ref String
  -- | Mouseenter handler: measures the box and reveals the side note.
  , measure :: Effect Unit
  -- | Mouseleave handler: clears the side-note hover.
  , leave :: Effect Unit
  -- | Click handler: pins/unpins the side note.
  , toggle :: Effect Unit
  }

-- | The note when present and non-empty — JS truthiness of
-- | `props.note`; null otherwise.
selectNoteOf :: Nullable String -> Nullable String
selectNoteOf value = case toMaybe value of
  Just text | text /= "" -> notNull text
  _ -> null

-- | The "W×H" label for a measured box, each side rounded to whole pixels.
sizeLabel :: Number -> Number -> String
sizeLabel width height = show (round width) <> "×" <> show (round height)

-- | Wires the Figma-style selection box: `measure` refreshes the "W×H"
-- | size label on hover, and the handlers drive the linked side note's
-- | reveal/pin state.
setup :: FigmaArgs -> Effect FigmaBindings
setup args = do
  size <- ref "0×0"
  let
    presentNote = toMaybe <<< selectNoteOf <$> args.note

    measure = do
      rect <- runEffectFn1 rectSizeImpl =<< read args.el
      case toMaybe rect of
        Just box -> write size (sizeLabel box.width box.height)
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
