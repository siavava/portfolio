-- | ## Site
-- |
-- | The setup composable behind `app.vue`: the bookkeeping that belongs to
-- | the site rather than to any one page. Cue threads and side notes are
-- | raised by the page on show, so every route change clears both stores
-- | before the next page raises its own. And once the app mounts on the
-- | client, the share image nuxt-og-image rendered into the server's head
-- | is handed back to the head manager, with `twitter:image` falling back
-- | to `og:image` when the page carried none of its own. It also words the
-- | site's share card from the profile and the project count, which the
-- | SFC only has once its queries resolve — so the card comes back as a
-- | function for the SFC to hand those to. The SFC keeps the SEO
-- | constants, the head and OG-image calls, the timeline transition
-- | wiring, the store handles, and one call here. The module lives under
-- | `app/components/` like every other page-level setup module.
module App.Components.Site
  ( ShelfCard
  , ShelfProfile
  , ShelfSource
  , SiteArgs
  , SiteBindings
  , setup
  , shelfCard
  ) where

import Prelude

import Data.Maybe (Maybe(..), fromMaybe, maybe)
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import Vue (onMounted, watchGetter)

foreign import metaContentImpl :: EffectFn1 String (Nullable String)

ogImageSelector :: String
ogImageSelector = "meta[property=\"og:image\"]"

twitterImageSelector :: String
twitterImageSelector = "meta[name=\"twitter:image\"]"

type SiteArgs =
  { -- | Reads the current route path.
    path :: Effect String
  -- | Clears the cue threads the last page raised.
  , resetCues :: Effect Unit
  -- | Clears the side notes the last page pinned.
  , resetSideNotes :: Effect Unit
  -- | Sets the head's share images — `og:image`, then `twitter:image` —
  -- | through `useSeoMeta`.
  , shareImage :: EffectFn2 String String Unit
  }

-- | The profile fields the share card is worded from.
type ShelfProfile =
  { name :: String
  , og :: { kicker :: String, description :: String }
  }

type ShelfSource =
  { -- | Reads the profile document; null until it has loaded.
    profile :: Effect (Nullable ShelfProfile)
  -- | Reads how many projects there are; null until the count has loaded.
  , projectCount :: Effect (Nullable Int)
  }

-- | The `Shelf` share card's props, each a getter so the card follows the
-- | queries it is worded from.
type ShelfCard =
  { kicker :: Effect String
  , title :: Effect String
  , description :: Effect String
  -- | `12 Projects`, under the shelf.
  , footer :: Effect String
  -- | How many books the shelf holds.
  , total :: Effect Int
  }

type SiteBindings =
  { -- | Words the site's share card, for `defineOgImage`.
    shelfCard :: ShelfSource -> ShelfCard
  }

-- | The site's share card: the profile's kicker, name and description over
-- | a shelf of every project. Until the profile loads the text is blank,
-- | and until the count loads the shelf is empty.
shelfCard :: ShelfSource -> ShelfCard
shelfCard source =
  { kicker: fromProfile _.og.kicker
  , title: fromProfile _.name
  , description: fromProfile _.og.description
  , footer: (\count -> show count <> " Projects") <$> total
  , total
  }
  where
  fromProfile field = maybe "" field <<< toMaybe <$> source.profile
  total = fromMaybe 0 <<< toMaybe <$> source.projectCount

-- | Clears the page-scoped stores on every route change and, once mounted,
-- | re-asserts the server-rendered share image through the head manager.
-- | Hands back the share card's wording for the SFC to feed its queries to.
setup :: SiteArgs -> Effect SiteBindings
setup args = do
  _ <- watchGetter args.path \_ _ -> args.resetCues *> args.resetSideNotes

  onMounted do
    ogImage <- toMaybe <$> runEffectFn1 metaContentImpl ogImageSelector
    case ogImage of
      Just image | image /= "" -> do
        twitterImage <- toMaybe <$> runEffectFn1 metaContentImpl twitterImageSelector
        runEffectFn2 args.shareImage image (fromMaybe image twitterImage)
      _ -> pure unit

  pure { shelfCard }
