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
-- |
-- | Only PureScript consumes it (the metrics store core). @ts-internal
module App.Composables.Metrics.ViewerLocation
  ( LocPromise
  , LocationApi
  , useViewerLocation
  ) where

import Prelude

import App.Composables.Metrics.ApiRoute (useApiRoute)
import App.Composables.Metrics.ViewerGeo (GeoData, GeoPromise, useViewerGeo)
import App.Utils.Metrics (metricsNamespaceId)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried
  ( EffectFn1
  , EffectFn2
  , EffectFn4
  , mkEffectFn1
  , mkEffectFn2
  , runEffectFn1
  , runEffectFn2
  , runEffectFn4
  )

-- | A `Promise<LocationData | null>`.
foreign import data LocPromise :: Type

foreign import data LocData :: Type

foreign import newLocPromiseImpl
  :: EffectFn1 (EffectFn1 (EffectFn1 (Nullable LocData) Unit) Unit) LocPromise

foreign import fetchLocationImpl :: EffectFn2 String (EffectFn1 (Nullable LocData) Unit) Unit

foreign import recordLocationImpl
  :: EffectFn4 String String GeoData (EffectFn2 Boolean (Nullable LocData) Unit) Unit

foreign import awaitGeoImpl :: EffectFn2 GeoPromise (EffectFn1 (Nullable GeoData) Unit) Unit

type LocationApi =
  { -- | Record this visit; resolves the previous visitor's location.
    getLocation :: Effect LocPromise
  }

getLocation :: Effect LocPromise
getLocation = do
  baseRoute <- useApiRoute
  let
    url = baseRoute <> "/location/"
    record = runEffectFn4 recordLocationImpl url metricsNamespaceId
  runEffectFn1 newLocPromiseImpl $ mkEffectFn1 \done -> do
    let readOnly = runEffectFn2 fetchLocationImpl url done
    geoApi <- useViewerGeo
    pending <- geoApi.resolveViewerGeo
    runEffectFn2 awaitGeoImpl pending $ mkEffectFn1 \current -> case toMaybe current of
      Nothing -> readOnly
      Just geo -> record geo $ mkEffectFn2 \ok result ->
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
