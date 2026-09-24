-- | Checks for the connections store core, run against Vue's real
-- | reactivity: map nodes register and unregister by name, hovering a bio
-- | target lights only the names the map knows (in the order the target
-- | lists them), a hover that knows none of its names leaves the previous
-- | lineage lit, and deactivating clears it.
module Test.Stores.Connections (suite) where

import Prelude

import App.Stores.Connections (useConnectionsCore)
import Effect (Effect)
import Effect.Uncurried (runEffectFn1)
import Test.Harness (Tally, expect)
import Vue (read, setHas)

suite :: Tally -> Effect Unit
suite t = do
  store <- useConnectionsCore
  let
    register = runEffectFn1 store.registerNode
    unregister = runEffectFn1 store.unregisterNode
    activate = runEffectFn1 store.activate
    lit = read store.activeNames

  lit >>= expect t "a fresh store lights nothing" []
  setHas store.nodes "rust" >>= expect t "a fresh store knows no nodes" false

  register "rust"
  register "graphics"
  register "compilers"
  setHas store.nodes "graphics" >>= expect t "a registered node is known" true

  activate [ "compilers", "cooking", "rust" ]
  lit >>= expect t "a hover lights only the known names, in the target's order"
    [ "compilers", "rust" ]

  activate [ "cooking", "gardening" ]
  lit >>= expect t "a hover that knows none of its names leaves the previous set lit"
    [ "compilers", "rust" ]

  activate []
  lit >>= expect t "a hover naming nothing leaves the previous set lit" [ "compilers", "rust" ]

  activate [ "graphics" ]
  lit >>= expect t "a new hover replaces the lit set" [ "graphics" ]

  store.deactivate
  lit >>= expect t "deactivating clears the lit names" []

  register "rust"
  unregister "rust"
  setHas store.nodes "rust" >>= expect t "an unregistered node is forgotten" false
  activate [ "rust" ]
  lit >>= expect t "an unregistered name no longer lights" []
  activate [ "rust", "graphics" ]
  lit >>= expect t "the remaining registered names still light" [ "graphics" ]

  other <- useConnectionsCore
  setHas other.nodes "graphics" >>= expect t "each store instance keeps its own registry" false
