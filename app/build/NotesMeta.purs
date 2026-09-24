-- | ## NotesMeta
-- |
-- | Pure core behind `scripts/build-notes-meta.ts`, the build step that prunes
-- | the notes site's full metadata snapshot down to the notes the project
-- | pages actually link: harvest every `https://notes.amittai.studio/…` URL
-- | from the markdown, reduce each to its WHATWG pathname without trailing
-- | slashes, dedupe and sort the paths, split them into kept (the snapshot has
-- | an entry) and missing, and word the summary line the script logs. The
-- | file system, JSON, and the write stay in the bun shell; URL parsing is the
-- | one FFI edge (`app/ffi/build/notes-meta.ts`). It sits outside
-- | `app/server/` because every module there becomes a nitro alias. Only the
-- | script consumes it. @ts-internal
module App.Build.NotesMeta
  ( PruneArgs
  , Pruned
  , SummaryCounts
  , notePaths
  , pruneNotes
  , referencedPaths
  , summaryLine
  ) where

import Prelude

import Data.Array (catMaybes, concatMap, elem, length, nub, partition, sort)
import Data.Array.NonEmpty as NEA
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), stripSuffix)
import Data.String.Regex (Regex, match)
import Data.String.Regex.Flags (global)
import Data.String.Regex.Unsafe (unsafeRegex)

foreign import urlPathnameImpl :: String -> String

-- | What `pruneNotes` splits.
type PruneArgs =
  { -- | The referenced paths, deduped and sorted (`referencedPaths`).
    referenced :: Array String
  , -- | The snapshot keys whose entry is truthy.
    available :: Array String
  }

-- | The kept/missing split of the referenced paths.
type Pruned =
  { -- | Referenced paths the snapshot has an entry for, in referenced order.
    kept :: Array String
  , -- | How many referenced paths it lacks (they fall back to the bare path).
    missing :: Int
  }

-- | The counts the summary line reports.
type SummaryCounts =
  { referenced :: Int
  , kept :: Int
  , missing :: Int
  , -- | Every entry in the full snapshot.
    total :: Int
  }

noteUrl :: Regex
noteUrl = unsafeRegex "https://notes\\.amittai\\.studio/[^\\s\"')\\]}>,]+" global

-- | Every notes-site path one markdown text links, in match order,
-- | duplicates included.
notePaths :: String -> Array String
notePaths text = case match noteUrl text of
  Nothing -> []
  Just urls -> map (stripTrailingSlashes <<< urlPathnameImpl) (catMaybes (NEA.toArray urls))

stripTrailingSlashes :: String -> String
stripTrailingSlashes path = case stripSuffix (Pattern "/") path of
  Just rest -> stripTrailingSlashes rest
  Nothing -> path

-- | The distinct paths across all texts, sorted by UTF-16 code units — the
-- | order `[...new Set(paths)].sort()` gives.
referencedPaths :: Array String -> Array String
referencedPaths = sort <<< nub <<< concatMap notePaths

-- | Keep the referenced paths the snapshot has, in order, and count the rest.
pruneNotes :: PruneArgs -> Pruned
pruneNotes { referenced, available } =
  let
    { yes, no } = partition (\path -> elem path available) referenced
  in
    { kept: yes, missing: length no }

-- | The line the script logs, byte for byte: the missing clause appears only
-- | when some referenced note is absent from the snapshot.
summaryLine :: SummaryCounts -> String
summaryLine { referenced, kept, missing, total } =
  "notes-meta: "
    <> show referenced
    <> " referenced → "
    <> show kept
    <> " kept"
    <> missingClause
    <> " (from "
    <> show total
    <> " in full snapshot)"
  where
  missingClause
    | missing /= 0 = ", " <> show missing <> " not in snapshot (path fallback)"
    | otherwise = ""
