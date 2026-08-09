-- | ## MarkdownMath
-- |
-- | Markdown-to-HTML rendering with inline and block KaTeX math. The
-- | `marked` pipeline lives behind typed FFI; the inline-math segmenter,
-- | HTML escaping, and emphasis rules are pure PureScript.
module App.Utils.MarkdownMath
  ( renderInlineMath
  , renderMarkdownMath
  ) where

import Prelude

import Data.String (joinWith)
import Data.String.CodeUnits as CU
import Data.String.Regex (Regex, replace, split)
import Data.String.Regex.Flags (global)
import Data.String.Regex.Unsafe (unsafeRegex)

foreign import parseMarkdownImpl :: String -> String
foreign import katexInlineImpl :: String -> String

-- | Parses a full markdown string to HTML, rendering `$…$` and `$$…$$`
-- | math via KaTeX along the way. Soft line breaks become `<br>`.
-- | Returns an empty string for empty input.
renderMarkdownMath :: String -> String
renderMarkdownMath src = if src == "" then "" else parseMarkdownImpl src

mathSegment :: Regex
mathSegment = unsafeRegex "(\\$[^$]+\\$)" global

ampersands :: Regex
ampersands = unsafeRegex "&" global

lessThans :: Regex
lessThans = unsafeRegex "<" global

greaterThans :: Regex
greaterThans = unsafeRegex ">" global

boldSpans :: Regex
boldSpans = unsafeRegex "\\*\\*([^*]+)\\*\\*" global

starEmSpans :: Regex
starEmSpans = unsafeRegex "\\*([^*]+)\\*" global

underEmSpans :: Regex
underEmSpans = unsafeRegex "(?<!\\w)_([^_]+?)_(?!\\w)" global

escapeHtml :: String -> String
escapeHtml =
  replace ampersands "&amp;"
    >>> replace lessThans "&lt;"
    >>> replace greaterThans "&gt;"

emphasize :: String -> String
emphasize =
  replace boldSpans "<strong>$1</strong>"
    >>> replace starEmSpans "<em>$1</em>"
    >>> replace underEmSpans "<em>$1</em>"

-- | Renders a single line of text containing inline `$…$` math (plus
-- | `**bold**` and both `_italic_` and `*italic*`) to HTML. Non-math
-- | segments are HTML-escaped before emphasis is applied.
renderInlineMath :: String -> String
renderInlineMath src =
  if src == "" then ""
  else joinWith "" (map renderPart (split mathSegment src))
  where
  renderPart part
    | isMath part = katexInlineImpl (CU.dropRight 1 (CU.drop 1 part))
    | otherwise = emphasize (escapeHtml part)

  isMath part =
    CU.take 1 part == "$"
      && CU.takeRight 1 part == "$"
      && CU.length part > 1
