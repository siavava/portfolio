-- | ## NowItem
-- |
-- | The setup composable behind `NowItem.vue`, one line of the "now" list:
-- | judges whether the item's link leaves the site, so outbound links
-- | open in a new tab. The SFC keeps only the prop macro plus one call
-- | here.
module App.Components.NowItem
  ( NowItemArgs
  , NowItemBindings
  , setup
  ) where

import Prelude

import App.Utils.Links (isExternalLink)
import Effect (Effect)
import Vue (Computed, computed)

type NowItemArgs =
  { -- | Reads the item's `url` frontmatter.
    url :: Effect String
  }

type NowItemBindings =
  { -- | Whether the item's link leaves the site, and so opens in a new tab.
    external :: Computed Boolean
  }

-- | Judges the item's link by the site's shared outbound-link rule.
setup :: NowItemArgs -> Effect NowItemBindings
setup args = do
  external <- computed (isExternalLink <$> args.url)
  pure { external }
