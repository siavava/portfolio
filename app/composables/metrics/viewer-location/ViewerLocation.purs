-- | ## ViewerLocation
-- |
-- | Resolves the viewer's geographic location and records the visit on
-- | the shared backend — the blog's exact mechanism. The backend keeps a
-- | single "last known" location plus a per-city history log, and
-- | returns the **previous** visitor's location when recording a new
-- | one.
-- |
-- | ### Details
-- |
-- | - **Dev mode**: defaults to Frankfurt, DE without calling the
-- |   geolocation service.
-- | - **Production**: queries `ipapi.co` for the viewer's IP-based
-- |   location, then reports city/state to the backend.
-- | - Falls back to a read-only fetch of the last known location when
-- |   the lookup fails.
module App.Composables.Metrics.ViewerLocation
  ( LocPromise
  , LocationApi
  , useViewerLocation
  ) where

import Prelude

import App.Composables.Metrics.ApiRoute (useApiRoute)
import App.Composables.Metrics.ViewerGeo (GeoData, GeoPromise, useViewerGeo)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn3
  , mkEffectFn1
  , mkEffectFn2
  , runEffectFn1
  , runEffectFn2
  , runEffectFn3
  )

-- | A `Promise<LocationData | null>`.
foreign import data LocPromise :: Type

-- | A `LocationData` record from the backend.
foreign import data LocData :: Type

foreign import newLocPromiseImpl
  :: EffectFn1 (EffectFn1 (EffectFn1 (Nullable LocData) Unit) Unit) LocPromise

foreign import fetchLocationImpl :: EffectFn2 String (EffectFn1 (Nullable LocData) Unit) Unit
foreign import recordLocationImpl
  :: EffectFn3 String GeoData (EffectFn2 Boolean (Nullable LocData) Unit) Unit

foreign import awaitGeoImpl :: EffectFn2 GeoPromise (EffectFn1 (Nullable GeoData) Unit) Unit

type LocationApi = { getLocation :: Effect LocPromise }

-- | Record this visit; resolves the previous visitor's location — or
-- | falls back to the read-only fetch when the geo lookup or the
-- | recording request fails.
getLocation :: Effect LocPromise
getLocation = do
  baseRoute <- useApiRoute
  let url = baseRoute <> "/location/"
  runEffectFn1 newLocPromiseImpl $ mkEffectFn1 \done -> do
    let readOnly = runEffectFn2 fetchLocationImpl url done
    geoApi <- useViewerGeo
    pending <- geoApi.resolveViewerGeo
    runEffectFn2 awaitGeoImpl pending $ mkEffectFn1 \current -> case toMaybe current of
      Nothing -> readOnly
      Just geo -> runEffectFn3 recordLocationImpl url geo $ mkEffectFn2 \ok result ->
        if ok then runEffectFn1 done result else readOnly

-- | ## useViewerLocation
-- |
-- | ### Returns
-- |
-- | | Field | Type | Description |
-- | | --- | --- | --- |
-- | | `getLocation` | `() => Promise<LocationData \| null>` | Record this visit; resolves the previous visitor's location |
useViewerLocation :: Effect LocationApi
useViewerLocation = pure { getLocation }
