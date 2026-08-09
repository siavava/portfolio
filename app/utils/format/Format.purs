-- | ## Format
-- |
-- | Pure text-formatting helpers behind `app/utils/format.ts`. The TypeScript
-- | module is a thin typed shim over this compiled output.
module App.Utils.Format
  ( titleCase
  , formatMonthYear
  ) where

import Prelude

import Data.Array (index, mapWithIndex)
import Data.Foldable (elem)
import Data.Maybe (fromMaybe)
import Data.Nullable (Nullable, toMaybe)
import Data.String (Pattern(..), joinWith, split, toUpper)
import Data.String.CodeUnits (drop, take)

minorWords :: Array String
minorWords = [ "and", "or", "of", "the", "a", "an", "to", "for", "with", "in", "on" ]

-- | Title-case a phrase, keeping minor words lowercase past the first.
titleCase :: String -> String
titleCase text = joinWith " " (mapWithIndex capitalize (split (Pattern " ") text))
  where
  capitalize position word
    | position > 0 && word `elem` minorWords = word
    | otherwise = toUpper (take 1 word) <> drop 1 word

-- | Render an ISO-ish date string as MM/YYYY. The date is `Nullable`
-- | because @nuxt/content returns SQL NULL for docs whose frontmatter
-- | omits it — the original rendered those as the empty string.
formatMonthYear :: Nullable String -> String
formatMonthYear nullableDate =
  let
    parts = split (Pattern "-") (fromMaybe "" (toMaybe nullableDate))
    year = fromMaybe "" (index parts 0)
    month = fromMaybe "" (index parts 1)
  in
    if year == "" then ""
    else if month == "" then year
    else month <> "/" <> year
