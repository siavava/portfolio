-- | Checks for the side-note store core, run against Vue's real
-- | reactivity: a note shows while its trigger is hovered or while it is
-- | pinned, one trigger is hovered at a time, a pin toggles, clearing the
-- | hover leaves pins alone, and a route change (reset) clears both.
module Test.Stores.SideNotes (suite) where

import Prelude

import App.Stores.SideNotes (useSideNotesCore)
import Data.Maybe (Maybe(..))
import Data.Nullable (toMaybe)
import Effect (Effect)
import Effect.Uncurried (runEffectFn1)
import Test.Harness (Tally, expect)
import Vue (read, setHas)

suite :: Tally -> Effect Unit
suite t = do
  store <- useSideNotesCore
  let
    visible = runEffectFn1 store.isVisible
    activate = runEffectFn1 store.activate
    togglePin = runEffectFn1 store.togglePin
    hovered = toMaybe <$> read store.hovered

  hovered >>= expect t "a fresh store hovers nothing" Nothing
  visible "entropy" >>= expect t "a fresh store shows no note" false

  activate "entropy"
  hovered >>= expect t "hovering a trigger records its note" (Just "entropy")
  visible "entropy" >>= expect t "the hovered trigger's note shows" true
  visible "gradient" >>= expect t "other notes stay hidden" false

  activate "gradient"
  visible "gradient" >>= expect t "hovering a second trigger shows its note" true
  visible "entropy" >>= expect t "only one trigger is hovered at a time" false

  store.deactivate
  hovered >>= expect t "deactivating clears the hover" Nothing
  visible "gradient" >>= expect t "an unhovered, unpinned note hides" false

  togglePin "entropy"
  setHas store.pinned "entropy" >>= expect t "a click pins the note" true
  visible "entropy" >>= expect t "a pinned note shows without a hover" true

  activate "gradient"
  visible "entropy" >>= expect t "a pinned note stays up while another is hovered" true
  visible "gradient" >>= expect t "the hovered note shows beside the pin" true

  store.deactivate
  visible "entropy" >>= expect t "clearing the hover leaves pins up" true

  togglePin "entropy"
  setHas store.pinned "entropy" >>= expect t "a second click unpins the note" false
  visible "entropy" >>= expect t "an unpinned, unhovered note hides" false

  togglePin "entropy"
  togglePin "gradient"
  activate "lagrangian"
  store.reset
  hovered >>= expect t "a reset clears the hover" Nothing
  visible "entropy" >>= expect t "a reset clears every pin (first)" false
  visible "gradient" >>= expect t "a reset clears every pin (second)" false
  visible "lagrangian" >>= expect t "a reset hides the hovered note" false
