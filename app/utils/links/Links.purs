-- | ## Links
-- |
-- | The site's one rule for telling an outbound link from an internal one.
-- | Prose links and the "now" list both open outbound links in a new tab
-- | while internal ones stay client-side navigations, so they share the
-- | judgement here rather than each carrying a copy of the prefix list.
module App.Utils.Links
  ( isExternalLink
  ) where

import Data.Foldable (any)
import Data.Maybe (isJust)
import Data.String (Pattern(..))
import Data.String.CodeUnits (stripPrefix)

externalPrefixes :: Array String
externalPrefixes = [ "http", "//", "mailto:" ]

-- | Whether the link leaves the site, and so opens in a new tab.
isExternalLink :: String -> Boolean
isExternalLink target = any startsWith externalPrefixes
  where
  startsWith prefix = isJust (stripPrefix (Pattern prefix) target)
