-- | ## AlgorithmBlock
-- |
-- | The setup composable behind `AlgorithmBlock.vue`, and the parser it
-- | runs: algorithm2e-style pseudocode from a fenced code block becomes
-- | numbered lines with a nesting depth, a trailing comment, bolded
-- | keywords, and `$…$` math rendered by KaTeX. `caption:` and `number:`
-- | lines in the body name the algorithm, and the fence's `meta`
-- | (`caption="…" number=N`) overrides them. Indentation — two spaces a
-- | level — draws the guides, and every guide that closes on a line ends
-- | in a bracket "foot"; a line closing several blocks at once is pushed
-- | down so its feet stack instead of overlapping. The SFC keeps the prop
-- | macro plus one call here.
module App.Components.AlgorithmBlock
  ( AlgorithmArgs
  , AlgorithmBindings
  , Line
  , Parsed
  , SourceRow
  , StyleMap
  , digitsFor
  , footAt
  , footDepth
  , footPushFor
  , headingFor
  , parse
  , readRows
  , renderCode
  , renderComment
  , setup
  , splitComment
  ) where

import Prelude

import App.Utils.Katex (renderTex)
import Data.Array (dropWhile, length, mapWithIndex, range, reverse, snoc, (!!))
import Data.Array as Array
import Data.Array.NonEmpty as NonEmptyArray
import Data.Foldable (elem, foldl, maximum, minimum)
import Data.Function.Uncurried (Fn2, mkFn2)
import Data.Int (toNumber)
import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Data.String (Pattern(..), Replacement(..), joinWith, replaceAll, split, toLower, trim)
import Data.String.CodeUnits as CU
import Data.String.Regex (Regex, match, replace, test)
import Data.String.Regex as Regex
import Data.String.Regex.Flags (global, ignoreCase, noFlags)
import Data.String.Regex.Unsafe (unsafeRegex)
import Effect (Effect)
import Vue (Computed, computed, read)

-- | An assembled `:style` object. @ts Record<string, number>
foreign import data StyleMap :: Type

foreign import footDepthVarsImpl :: Int -> StyleMap

-- | One source line after the directive and indentation pass: its depth,
-- | its code, and its comment, both still raw text.
type SourceRow =
  { level :: Int
  , content :: String
  , comment :: String
  }

-- | One rendered line, as the template draws it.
type Line =
  { -- | Nesting depth — the number of guides before the code.
    level :: Int
  -- | The code, rendered to HTML.
  , html :: String
  -- | The trailing comment, rendered to HTML; empty when there is none.
  , comment :: String
  -- | The depths whose guides close on this line and end in a foot.
  , feet :: Array Int
  -- | How far, in em, the next line is pushed down to make room for the
  -- | feet stacked under this one.
  , footPush :: Number
  }

-- | A parsed block: its caption and number, raw, and its lines.
type Parsed =
  { caption :: String
  , number :: String
  , lines :: Array Line
  }

type AlgorithmArgs =
  { -- | Reads the `code` prop: the fenced block's body.
    code :: Effect String
  -- | Reads the `meta` prop: the fence's `caption="…" number=N`.
  , meta :: Effect String
  }

type AlgorithmBindings =
  { -- | The rendered lines.
    lines :: Computed (Array Line)
  -- | The algorithm's number; empty for an unnumbered one.
  , number :: Computed String
  -- | The caption's lead-in: `Algorithm 3:`, or `Algorithm:` unnumbered.
  , heading :: Computed String
  -- | The caption, rendered the way code is.
  , captionHtml :: Computed String
  -- | Digits in the last line number, which sizes the number gutter.
  , maxDigits :: Computed Int
  -- | The foot style for a line's guide at a 1-based depth, or null when
  -- | that guide runs on past the line.
  , footDepthStyle :: Fn2 Line Int (Nullable StyleMap)
  -- | Whether a line's guide at a 1-based depth closes there in a foot.
  , isFoot :: Fn2 Line Int Boolean
  }

-- Longer phrases must precede their prefixes (`else if` before `else`) or the alternation stops short.
keywords :: Regex
keywords = unsafeRegex
  ( "\\b(while|do|for each|foreach|for|to|downto|if|then|else if|else|repeat|until"
      <> "|return|call|loop|break|continue|function|procedure|output|input|and|or|not"
      <> "|nil)\\b"
  )
  (global <> ignoreCase)

controlWord :: Regex
controlWord = unsafeRegex "^(start|stop|end|begin)$" ignoreCase

mathSpan :: Regex
mathSpan = unsafeRegex "(\\$[^$]+\\$)" global

strongSpan :: Regex
strongSpan = unsafeRegex "\\*\\*([^*]+)\\*\\*" global

captionLine :: Regex
captionLine = unsafeRegex "^\\s*caption:\\s*(.*)$" ignoreCase

numberLine :: Regex
numberLine = unsafeRegex "^\\s*number:\\s*(.*)$" ignoreCase

commentMarker :: Regex
commentMarker = unsafeRegex "^\\s*(?://|▷)\\s*" noFlags

metaCaption :: Regex
metaCaption = unsafeRegex "caption=\"([^\"]*)\"" noFlags

metaNumber :: Regex
metaNumber = unsafeRegex "number=(\\d+)" noFlags

ampersands :: Regex
ampersands = unsafeRegex "&" global

lessThans :: Regex
lessThans = unsafeRegex "<" global

greaterThans :: Regex
greaterThans = unsafeRegex ">" global

escapeHtml :: String -> String
escapeHtml =
  replace ampersands "&amp;"
    >>> replace lessThans "&lt;"
    >>> replace greaterThans "&gt;"

firstGroup :: Regex -> String -> Maybe String
firstGroup regex text = match regex text >>= \groups -> join (NonEmptyArray.index groups 1)

renderWith :: Boolean -> String -> String
renderWith isComment text = joinWith "" (map piece (Regex.split mathSpan text))
  where
  piece segment
    | isMath segment = renderTex (CU.dropRight 1 (CU.drop 1 segment)) false
    | otherwise =
        let
          escaped = replace strongSpan "<strong>$1</strong>" (escapeHtml segment)
        in
          if isComment then escaped else replace keywords "<b class=\"kw\">$&</b>" escaped

  isMath segment =
    CU.take 1 segment == "$"
      && CU.takeRight 1 segment == "$"
      && CU.length segment > 1

-- | Renders a line's code (or the caption) to HTML, keywords in bold.
renderCode :: String -> String
renderCode = renderWith false

-- | Renders a comment to HTML; comments are prose, so keywords stay plain.
renderComment :: String -> String
renderComment = renderWith true

-- | Splits a trimmed line at its comment: a ` // ` or a `▷`, whichever
-- | comes first. The marker is dropped; a `//` with no space before it
-- | (a URL, an operator) is code.
splitComment :: String -> { content :: String, comment :: String }
splitComment content = case cut of
  Nothing -> { content, comment: "" }
  Just at ->
    { content: trim (CU.take at content)
    , comment: replace commentMarker "" (CU.drop at content)
    }
  where
  cut = case CU.indexOf (Pattern " // ") content, CU.indexOf (Pattern "▷") content of
    Just slash, Just triangle -> Just (min slash triangle)
    Just slash, Nothing -> Just slash
    Nothing, triangle -> triangle

-- | The directive and indentation pass over a block's body. `caption:`
-- | and `number:` lines are taken out (the last of each wins), blank lines
-- | before the first row and after the last are dropped, and every other
-- | line becomes a row two spaces of indentation to the level.
readRows :: String -> { caption :: String, number :: String, rows :: Array SourceRow }
readRows code = trimTail (foldl step { caption: "", number: "", rows: [] } sourceLines)
  where
  sourceLines = split (Pattern "\n") (replaceAll (Pattern "\r") (Replacement "") code)

  step acc line = case firstGroup captionLine line, firstGroup numberLine line of
    Just caption, _ -> acc { caption = trim caption }
    _, Just number -> acc { number = trim number }
    _, _
      | trim line == "" && Array.null acc.rows -> acc
      | otherwise -> acc { rows = snoc acc.rows (readRow line) }

  readRow line =
    let
      indent = CU.length (CU.takeWhile (_ == ' ') line)
      parts = splitComment (trim line)
    in
      { level: indent / 2, content: parts.content, comment: parts.comment }

  trimTail acc = acc { rows = reverse (dropWhile blank (reverse acc.rows)) }

  blank row = row.content == "" && row.comment == ""

feetFor :: SourceRow -> Maybe SourceRow -> Array Int
feetFor row next
  | row.level <= 0 = []
  | otherwise = Array.filter closes (range 0 (row.level - 1))
      where
      closes depth = maybe true (\after -> after.level <= depth) next

-- | How far the next line is pushed down for a line's feet: a little for
-- | any, and more for each foot stacked under the shallowest.
footPushFor :: Array Int -> Number
footPushFor feet = case maximum feet, minimum feet of
  Just deepest, Just shallowest -> 0.1 + toNumber (deepest - shallowest) * 0.46
  _, _ -> 0.0

-- | Whether the guide at a 1-based depth closes on this line, ending in
-- | a foot.
footAt :: Line -> Int -> Boolean
footAt line depth = elem (depth - 1) line.feet

-- | For a guide at a 1-based depth, how many feet below the deepest one
-- | its own foot sits, when the guide closes on this line — the deepest
-- | foot is 0. Null when the guide runs on past the line.
footDepth :: Line -> Int -> Nullable Int
footDepth line depth
  | footAt line depth = notNull (fromMaybe 0 (maximum line.feet) - (depth - 1))
  | otherwise = null

renderLine :: SourceRow -> Maybe SourceRow -> Line
renderLine row next =
  { level: row.level
  , html:
      if test controlWord row.content then "<i class=\"ctrl\">" <> toLower row.content <> "</i>"
      else renderCode row.content
  , comment: renderComment row.comment
  , feet
  , footPush: footPushFor feet
  }
  where
  feet = feetFor row next

-- | Parses a block's body and its fence meta; the meta's caption and
-- | number win over the body's directives.
parse :: String -> String -> Parsed
parse code meta =
  { caption: fromMaybe body.caption (firstGroup metaCaption meta)
  , number: fromMaybe body.number (firstGroup metaNumber meta)
  , lines: mapWithIndex (\i row -> renderLine row (body.rows !! (i + 1))) body.rows
  }
  where
  body = readRows code

-- | The caption's lead-in for an algorithm number, which is left out when
-- | empty.
headingFor :: String -> String
headingFor n = "Algorithm" <> (if n == "" then "" else " " <> n) <> ":"

-- | The digits in a line count, and at least one.
digitsFor :: Int -> Int
digitsFor count = max 1 (CU.length (show count))

-- | Parses the block whenever its props change, and hands the template its
-- | lines, caption, number and heading, gutter width, and which guides end
-- | in a foot and how that foot is styled.
setup :: AlgorithmArgs -> Effect AlgorithmBindings
setup args = do
  parsed <- computed (parse <$> args.code <*> args.meta)
  lines <- computed (_.lines <$> read parsed)
  number <- computed (_.number <$> read parsed)
  heading <- computed (headingFor <$> read number)
  captionHtml <- computed (renderCode <<< _.caption <$> read parsed)
  maxDigits <- computed (digitsFor <<< length <$> read lines)
  let
    footDepthStyle line depth =
      maybe null (notNull <<< footDepthVarsImpl) (toMaybe (footDepth line depth))
  pure
    { lines
    , number
    , heading
    , captionHtml
    , maxDigits
    , footDepthStyle: mkFn2 footDepthStyle
    , isFoot: mkFn2 footAt
    }
