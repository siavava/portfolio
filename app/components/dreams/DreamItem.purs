-- | ## DreamItem
-- |
-- | The setup composable behind `DreamItem.vue`: splits a checklist label
-- | into plain-text and markdown-style-link — `[text](url)` — segments.
-- | The matcher itself stays in JS (`linkMatchesImpl`) for exact
-- | `matchAll` regex semantics; the segmentation lives here.
module App.Components.DreamItem
  ( DreamArgs
  , DreamBindings
  , LabelPart
  , setup
  ) where

import Prelude

import Data.Foldable (foldl)
import Data.Nullable (Nullable, notNull, null)
import Data.String.CodeUnits (drop, length, slice)
import Effect (Effect)
import Vue (Computed, computed)

-- | Every `[text](url)` match in the label, with its code-unit index and
-- | matched length — `String#matchAll` under the hood.
foreign import linkMatchesImpl
  :: String -> Array { index :: Int, length :: Int, text :: String, href :: String }

type LabelPart =
  { -- | The segment's visible text.
    text :: String
  -- | Link target when the segment came from `[text](url)`; null for
  -- | plain text.
  , href :: Nullable String
  }

type DreamArgs =
  { -- | Reads the current dream's label text.
    label :: Effect String
  }

type DreamBindings =
  { -- | The label split into plain-text and link segments, in order.
    parts :: Computed (Array LabelPart)
  }

partsOf :: String -> Array LabelPart
partsOf label = scanned.segments <> trailing
  where
  step
    :: { last :: Int, segments :: Array LabelPart }
    -> { index :: Int, length :: Int, text :: String, href :: String }
    -> { last :: Int, segments :: Array LabelPart }
  step acc m =
    { last: m.index + m.length
    , segments: acc.segments
        <>
          ( if m.index > acc.last then [ { text: slice acc.last m.index label, href: null } ]
            else []
          )
        <> [ { text: m.text, href: notNull m.href } ]
    }

  scanned :: { last :: Int, segments :: Array LabelPart }
  scanned = foldl step { last: 0, segments: [] } (linkMatchesImpl label)

  trailing :: Array LabelPart
  trailing =
    if scanned.last < length label then [ { text: drop scanned.last label, href: null } ]
    else []

-- | Derives `parts` — the checklist label split into plain-text and
-- | `[text](url)` link segments the template renders as text nodes and
-- | external links.
setup :: DreamArgs -> Effect DreamBindings
setup args = do
  parts <- computed (partsOf <$> args.label)
  pure { parts }
