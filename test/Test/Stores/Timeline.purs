-- | Checks for the timeline store core, run against Vue's real
-- | reactivity: clicking the bar records the rect the panel grows from,
-- | the scroll it was clicked at and the route it sits on; clearing the
-- | origin makes the next open or close fade; each dock counts a landing
-- | and releases the origin; and a bio target's previewed year shows until
-- | that same year's preview closes, surviving the close of an older one.
module Test.Stores.Timeline (suite) where

import Prelude

import App.Stores.Timeline (Rect, useTimelineStoreCore)
import Data.Maybe (Maybe(..))
import Data.Nullable (toMaybe)
import Effect (Effect)
import Effect.Uncurried (runEffectFn1, runEffectFn3)
import Test.Harness (Tally, expect)
import Vue (read)

bar :: Rect
bar = { left: 24.0, top: 16.0, width: 320.0, height: 40.0 }

suite :: Tally -> Effect Unit
suite t = do
  store <- useTimelineStoreCore
  let
    begin = runEffectFn3 store.begin
    focus = runEffectFn1 store.focus
    blur = runEffectFn1 store.blur
    origin = toMaybe <$> read store.origin
    originPath = toMaybe <$> read store.originPath
    focusYear = toMaybe <$> read store.focusYear

  origin >>= expect t "a fresh store has no origin (an opening fades)" Nothing
  originPath >>= expect t "a fresh store has no origin route" Nothing
  read store.originScroll >>= expect t "a fresh store remembers no scroll" 0.0
  read store.landings >>= expect t "a fresh store has counted no landings" 0
  focusYear >>= expect t "a fresh store previews no year" Nothing

  begin bar 1280.0 "/"
  origin >>= expect t "a click records the bar's rect" (Just bar)
  read store.originScroll >>= expect t "a click records the scroll it happened at" 1280.0
  originPath >>= expect t "a click records the bar's route" (Just "/")

  store.clearOrigin
  origin >>= expect t "clearing drops the rect" Nothing
  originPath >>= expect t "clearing drops the route" Nothing

  begin bar 0.0 "/projects"
  store.land
  read store.landings >>= expect t "a dock counts one landing" 1
  origin >>= expect t "a dock releases the rect" Nothing
  originPath >>= expect t "a dock releases the route" Nothing

  store.land
  read store.landings >>= expect t "every dock counts, even without an origin" 2

  focus 2021
  focusYear >>= expect t "a target's preview shows its year" (Just 2021)
  focus 2024
  focusYear >>= expect t "a newer preview replaces the year" (Just 2024)
  blur 2021
  focusYear >>= expect t "closing an older preview keeps the newer year" (Just 2024)
  blur 2024
  focusYear >>= expect t "closing the shown preview clears the year" Nothing
  blur 2024
  focusYear >>= expect t "closing it again changes nothing" Nothing
