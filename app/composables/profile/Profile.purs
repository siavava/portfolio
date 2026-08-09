-- | ## Profile
-- |
-- | The profile singleton shared by the name bar, subscribe panel, and
-- | footer — the "profile" collection's single document, fetched once
-- | per app under the `"profile"` async-data key. The Nuxt Content
-- | query and async-data wiring live behind the FFI edge.
module App.Composables.Profile
  ( ProfileAsync
  , useProfile
  ) where

import Effect (Effect)

-- | The awaited-able `AsyncData` handle Nuxt returns — opaque;
-- | consumers destructure `data` after awaiting.
foreign import data ProfileAsync :: Type

-- | `useAsyncData("profile", …)` over the collection's first document;
-- | Nuxt dedupes on the key, so every caller shares one fetch.
foreign import useProfileImpl :: Effect ProfileAsync

-- | The shared profile document handle — await it and destructure
-- | `data`. Every consumer gets the same instance via the `"profile"`
-- | async-data key.
useProfile :: Effect ProfileAsync
useProfile = useProfileImpl
