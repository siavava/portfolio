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
  , useDreamItem
  ) where

import Prelude

import Data.Foldable (foldl)
import Data.Nullable (Nullable, notNull, null)
import Data.String.CodeUnits (drop, length, slice)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, mkEffectFn1)
import Vue (Computed, computed)

foreign import linkMatchesImpl
  :: String -> Array { index :: Int, length :: Int, text :: String, href :: String }

type LabelPart = { text :: String, href :: Nullable String }

type DreamArgs = { label :: Effect String }

type DreamBindings = { parts :: Computed (Array LabelPart) }

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

useDreamItem :: EffectFn1 DreamArgs DreamBindings
useDreamItem = mkEffectFn1 \args -> do
  parts <- computed (partsOf <$> args.label)
  pure { parts }
