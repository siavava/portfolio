-- | ## ProseA
-- |
-- | The setup composable behind `ProseA.vue`, the override for Nuxt
-- | Content's `<a>`: resolves where the link points and whether it leaves
-- | the site. Internal links stay client-side navigations; external ones
-- | open in a new tab, matching the blog. Inside a timeline year — the
-- | timeline and the bio's previews of it — internal links prefetch only on
-- | hover or focus: a column scrolls every project link into view, and each
-- | would otherwise fetch its project's payload. The SFC keeps only the
-- | prop macro plus one call here.
module App.Components.ProseA
  ( ProseAArgs
  , ProseABindings
  , linkTarget
  , setup
  ) where

import Prelude

import App.Utils.Links (isExternalLink)
import Data.Maybe (isJust)
import Data.Nullable (Nullable, null, toMaybe)
import Effect (Effect)
import Vue (Computed, computed, inject, read)

type ProseAArgs =
  { -- | Reads the `href` prop Nuxt Content hands markdown links; empty
    -- | when absent.
    href :: Effect String
  -- | Reads the `to` prop, for links written as components; empty when
  -- | absent.
  , to :: Effect String
  }

type ProseABindings =
  { -- | Where the link points: `to` when given, otherwise `href`.
    target :: Computed String
  -- | Whether the target leaves the site, and so opens in a new tab.
  , external :: Computed Boolean
  -- | Whether it prefetches only on interaction: inside a timeline year.
  , quietPrefetch :: Boolean
  }

-- | Where a link with the given `to` and `href` points: `to` when given,
-- | otherwise `href`.
linkTarget :: String -> String -> String
linkTarget to href = if to == "" then href else to

-- | Resolves the link's target from its two props and judges it by the
-- | site's shared outbound-link rule.
setup :: ProseAArgs -> Effect ProseABindings
setup args = do
  target <- computed (linkTarget <$> args.to <*> args.href)
  external <- computed (isExternalLink <$> read target)
  quietPrefetch <- isJust <<< toMaybe <$> inject "timeline-year" (null :: Nullable (Computed Int))
  pure { target, external, quietPrefetch }
