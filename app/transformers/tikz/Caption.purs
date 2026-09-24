-- | ## Caption
-- |
-- | Figure captions for the build-time TikZ renderer. A caption is authored
-- | as leading `% caption:` comment lines on a tikz block; `extractCaption`
-- | joins them into one line and `renderCaptionWith` renders it as inline
-- | markdown with `$…$` math. The KaTeX and `marked` renderers stay in
-- | `transformers/tikz/caption.ts` and arrive as plain functions.
-- | @ts-internal
module App.Transformers.Tikz.Caption
  ( Renderers
  , extractCaption
  , renderCaptionWith
  ) where

import Prelude

import Data.Array (foldl, index, mapWithIndex, snoc)
import Data.Array.NonEmpty as NEA
import Data.Int as Int
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String (Pattern(..), joinWith, stripPrefix, trim)
import Data.String as String
import Data.String.Regex (Regex, match, replace, replace', split)
import Data.String.Regex.Flags (global, ignoreCase, noFlags)
import Data.String.Regex.Unsafe (unsafeRegex)

-- | The two renderers a caption goes through: `math` turns one bare TeX
-- | expression (delimiters stripped) into HTML, `inline` renders inline
-- | markdown.
type Renderers = { math :: String -> String, inline :: String -> String }

type Collected = { started :: Boolean, out :: Array String }

commentMarks :: Regex
commentMarks = unsafeRegex "^%+\\s*" noFlags

captionLead :: Regex
captionLead = unsafeRegex "^caption:\\s*(.*)$" ignoreCase

captionPrefix :: Regex
captionPrefix = unsafeRegex "^caption:\\s*" ignoreCase

whitespaceRuns :: Regex
whitespaceRuns = unsafeRegex "\\s+" global

-- | Joins the caption out of a block's leading comment lines. A caption
-- | may be wrapped across several consecutive `%` lines for readable
-- | source, so the `% caption:` line and every non-empty comment line
-- | after it (a repeated `caption:` prefix dropped) join into one flowing
-- | line, and `$…$` math reassembles cleanly across a wrap boundary.
-- | Lines that are not comments are skipped. `Nothing` when there is no
-- | `caption:` line or the joined caption is empty.
extractCaption :: String -> Maybe String
extractCaption block =
  if not collected.started then Nothing
  else case trim (replace whitespaceRuns " " (joinWith " " collected.out)) of
    "" -> Nothing
    caption -> Just caption
  where
  collected = foldl step { started: false, out: [] } (String.split (Pattern "\n") block)

  step :: Collected -> String -> Collected
  step acc raw = case stripPrefix (Pattern "%") trimmed of
    Nothing -> acc
    Just _
      | not acc.started -> case match captionLead text of
          Just groups ->
            let
              rest = trim (fromMaybe "" (join (NEA.index groups 1)))
            in
              { started: true, out: if rest == "" then acc.out else snoc acc.out rest }
          Nothing -> acc
      | text == "" -> acc
      | otherwise -> acc { out = snoc acc.out (replace captionPrefix "" text) }
    where
    trimmed = trim raw
    text = trim (replace commentMarks "" trimmed)

inlineMath :: Regex
inlineMath = unsafeRegex "\\$([^$]+)\\$" noFlags

mathPlaceholder :: Regex
mathPlaceholder = unsafeRegex "XMATHX(\\d+)XMATHX" global

newlineRuns :: Regex
newlineRuns = unsafeRegex "\\n+" global

-- | Renders a caption to inline HTML. Each `$…$` span is rendered by
-- | `math` in order and parked behind an `XMATHX<k>XMATHX` placeholder
-- | while `inline` renders the markdown around it, then restored; newlines
-- | are dropped. A placeholder with no rendered span behind it becomes
-- | empty — including one the caption spelled out literally, which is
-- | substituted like a real one, as in the original.
renderCaptionWith :: Renderers -> String -> String
renderCaptionWith { math, inline } caption =
  replace newlineRuns "" (replace' mathPlaceholder restore (inline withPlaceholders))
  where
  chunks = split inlineMath caption
  rendered = map math (oddChunks chunks)
  withPlaceholders = joinWith "" (mapWithIndex park chunks)
  park i chunk
    | Int.odd i = "XMATHX" <> show (i / 2) <> "XMATHX"
    | otherwise = chunk
  restore _ groups = fromMaybe "" do
    digits <- join (index groups 0)
    k <- Int.fromString digits
    index rendered k

oddChunks :: Array String -> Array String
oddChunks chunks = foldl keep [] (mapWithIndex { i: _, chunk: _ } chunks)
  where
  keep acc { i, chunk } = if Int.odd i then snoc acc chunk else acc
