-- | Checks for the map-reveal store core, run against Vue's real
-- | reactivity: the page starts unsettled with no offset, each spring frame
-- | drives the offset it should sit at, landing the spring settles the page
-- | and releases the offset, and a spring that starts again unsettles it.
module Test.Stores.MapReveal (suite) where

import Prelude

import App.Stores.MapReveal (useMapRevealCore)
import Data.Maybe (Maybe(..))
import Data.Nullable (toMaybe)
import Effect (Effect)
import Effect.Uncurried (runEffectFn1)
import Test.Harness (Tally, expect)
import Vue (read)

suite :: Tally -> Effect Unit
suite t = do
  store <- useMapRevealCore
  let
    drive = runEffectFn1 store.drive
    offset = toMaybe <$> read store.offset
    settled = read store.settled

  offset >>= expect t "a fresh reveal holds no offset" Nothing
  settled >>= expect t "a fresh reveal has not settled" false

  drive 240.0
  offset >>= expect t "a spring frame writes its offset" (Just 240.0)
  settled >>= expect t "a driven page is not settled" false

  drive 12.5
  offset >>= expect t "each frame replaces the offset" (Just 12.5)

  drive 0.0
  offset >>= expect t "an offset of 0 is still an offset, not idle" (Just 0.0)

  store.settle
  offset >>= expect t "settling releases the offset" Nothing
  settled >>= expect t "settling hands the layout back to the page" true

  drive (-8.0)
  offset >>= expect t "a spring driven again writes its offset" (Just (-8.0))
  settled >>= expect t "a spring driven again unsettles the page" false
