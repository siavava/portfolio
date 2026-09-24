-- | Checks for the viewer-location rules: a lookup names a place only
-- | when it has both a city and a state, the state is the region code in
-- | the US and the country everywhere else ("UK" rather than ISO's "GB"),
-- | and a cached location is trusted for under an hour.
module Test.Composables.Metrics.ViewerGeo (suite) where

import Prelude

import App.Composables.Metrics.ViewerGeo (RawGeoFields, geoPlace, isFreshCache)
import Data.Maybe (Maybe(..))
import Data.Nullable (notNull, null)
import Effect (Effect)
import Test.Harness (Tally, expect)

response :: String -> String -> String -> RawGeoFields
response city region country =
  { city: field city
  , regionCode: field region
  , countryCode: field country
  , latitude: notNull 43.7
  , longitude: notNull (-72.29)
  }
  where
  field = case _ of
    "" -> null
    value -> notNull value

place :: String -> String -> Maybe { city :: String, state :: String }
place city state = Just { city, state }

hour :: Number
hour = 3600.0 * 1000.0

now :: Number
now = 1.7e12

suite :: Tally -> Effect Unit
suite t = do
  expect t "place: a US city takes its region code as the state"
    (place "Hanover" "NH")
    (geoPlace (response "Hanover" "NH" "US"))
  expect t "place: a US city without a region falls back to the country"
    (place "Hanover" "US")
    (geoPlace (response "Hanover" "" "US"))
  expect t "place: a US city with an empty region falls back to the country"
    (place "Hanover" "US")
    (geoPlace ((response "Hanover" "" "US") { regionCode = notNull "" }))
  expect t "place: outside the US the country stands in for the state"
    (place "Frankfurt" "DE")
    (geoPlace (response "Frankfurt" "HE" "DE"))
  expect t "place: Great Britain reads as UK"
    (place "London" "UK")
    (geoPlace (response "London" "ENG" "GB"))
  expect t "place: Great Britain reads as UK without a region too"
    (place "London" "UK")
    (geoPlace (response "London" "" "GB"))
  expect t "place: no city, no place" Nothing (geoPlace (response "" "NH" "US"))
  expect t "place: an empty city, no place" Nothing
    (geoPlace ((response "" "NH" "US") { city = notNull "" }))
  expect t "place: no country, no place" Nothing (geoPlace (response "Hanover" "NH" ""))
  expect t "place: an empty country, no place" Nothing
    (geoPlace ((response "Hanover" "NH" "") { countryCode = notNull "" }))
  expect t "place: coordinates play no part in naming the place"
    (place "Nairobi" "KE")
    (geoPlace ((response "Nairobi" "30" "KE") { latitude = null, longitude = null }))

  expect t "cache: an entry written just now is fresh" true (isFreshCache now now)
  expect t "cache: an entry 59 minutes old is fresh" true
    (isFreshCache now (now - 59.0 * 60.0 * 1000.0))
  expect t "cache: an entry exactly an hour old is stale" false (isFreshCache now (now - hour))
  expect t "cache: an entry a day old is stale" false (isFreshCache now (now - 24.0 * hour))
