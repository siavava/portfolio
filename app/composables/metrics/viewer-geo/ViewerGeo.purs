-- | ## ViewerGeo
-- |
-- | Resolves the viewer's location once and caches it — in module state
-- | for the session (the FFI memoizes the promise) and in localStorage
-- | for an hour — so every `watch` message can attribute views to a
-- | place without re-hitting the geolocation service. Resolves `null`
-- | when the lookup fails (views simply go unattributed).
module App.Composables.Metrics.ViewerGeo
  ( GeoApi
  , GeoData
  , GeoPromise
  , useViewerGeo
  ) where

import Prelude

import Data.Function.Uncurried (Fn4, runFn4)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, notNull, null, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, mkEffectFn1, runEffectFn1)

-- | The viewer's resolved location (a `ViewerGeo`), lat/lon optional.
foreign import data GeoData :: Type

-- | The memoized `Promise<ViewerGeo | null>` lookup.
foreign import data GeoPromise :: Type

-- | A localStorage cache entry: the location plus its write timestamp.
type CacheEntry = { geo :: GeoData, ts :: Number }

-- | The `ipapi.co` response, normalized at the FFI edge: absent fields
-- | (and non-numeric coordinates) become null.
type RawGeoFields =
  { city :: Nullable String
  , regionCode :: Nullable String
  , countryCode :: Nullable String
  , latitude :: Nullable Number
  , longitude :: Nullable Number
  }

foreign import devModeImpl :: Effect Boolean
foreign import nowImpl :: Effect Number
foreign import readCacheImpl :: Effect (Nullable CacheEntry)
foreign import writeCacheImpl :: EffectFn1 GeoData Unit
foreign import fetchGeoImpl :: EffectFn1 (EffectFn1 (Nullable RawGeoFields) Unit) Unit
foreign import mkGeoImpl :: Fn4 String String (Nullable Number) (Nullable Number) GeoData
foreign import memoLookupImpl
  :: EffectFn1 (EffectFn1 (EffectFn1 (Nullable GeoData) Unit) Unit) GeoPromise

type GeoApi =
  { readCachedGeo :: Effect (Nullable GeoData)
  , resolveViewerGeo :: Effect GeoPromise
  }

cacheTtlMs :: Number
cacheTtlMs = 3600.0 * 1000.0

-- | Development default: Frankfurt, DE — no geolocation call.
devGeo :: GeoData
devGeo = runFn4 mkGeoImpl "Frankfurt" "DE" (notNull 50.11) (notNull 8.68)

-- | The cached location, read synchronously — so the first `watch` of a
-- | returning visitor's session already carries attribution instead of
-- | waiting on the network lookup.
readCachedGeo :: Effect (Nullable GeoData)
readCachedGeo = do
  dev <- devModeImpl
  if dev then pure (notNull devGeo)
  else do
    cached <- readCacheImpl
    now <- nowImpl
    pure
      ( case toMaybe cached of
          Just entry | now - entry.ts < cacheTtlMs -> notNull entry.geo
          _ -> null
      )

-- | Build the location record from a lookup response. Region codes are
-- | only canonically recognized in the US; "UK" over ISO's "GB".
buildGeo :: Nullable RawGeoFields -> Maybe GeoData
buildGeo rawN = do
  raw <- toMaybe rawN
  let
    countryCode = toMaybe raw.countryCode
    country = if countryCode == Just "GB" then Just "UK" else countryCode
    state =
      if countryCode == Just "US" then case toMaybe raw.regionCode of
        Just region | region /= "" -> Just region
        _ -> countryCode
      else country
  city <- toMaybe raw.city
  stateCode <- state
  if city == "" || stateCode == "" then Nothing
  else Just (runFn4 mkGeoImpl city stateCode raw.latitude raw.longitude)

-- | The network path: cache check, `ipapi.co` lookup, best-effort cache
-- | write — resolving the callback with the location or null.
lookupGeo :: (Nullable GeoData -> Effect Unit) -> Effect Unit
lookupGeo done = do
  dev <- devModeImpl
  if dev then done (notNull devGeo)
  else do
    cached <- readCacheImpl
    now <- nowImpl
    case toMaybe cached of
      Just entry | now - entry.ts < cacheTtlMs -> done (notNull entry.geo)
      _ -> runEffectFn1 fetchGeoImpl $ mkEffectFn1 \raw -> case buildGeo raw of
        Nothing -> done null
        Just geo -> do
          runEffectFn1 writeCacheImpl geo
          done (notNull geo)

resolveViewerGeo :: Effect GeoPromise
resolveViewerGeo = runEffectFn1 memoLookupImpl (mkEffectFn1 \done -> lookupGeo (runEffectFn1 done))

-- | ## useViewerGeo
-- |
-- | ### Returns
-- |
-- | | Field | Type | Description |
-- | | --- | --- | --- |
-- | | `readCachedGeo` | `() => ViewerGeo \| null` | The cached location, synchronously |
-- | | `resolveViewerGeo` | `() => Promise<ViewerGeo \| null>` | Resolve (and memoize) the location |
useViewerGeo :: Effect GeoApi
useViewerGeo = pure { readCachedGeo, resolveViewerGeo }
