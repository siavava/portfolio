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

foreign import useProfileImpl :: Effect ProfileAsync

useProfile :: Effect ProfileAsync
useProfile = useProfileImpl
