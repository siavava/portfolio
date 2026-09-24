-- | Checks for the cue store core, run against Vue's real reactivity: a
-- | hovered root lights only the marks that are registered, a root naming
-- | no registered mark leaves the hover as it was, a click pins a root's
-- | marks and a second click unpins them, the overlay draws the pins first
-- | and the hover after them (never a pinned root twice), a root is active
-- | while it drives the hover or holds a pin, and a route change clears
-- | the hover and every pin.
module Test.Stores.Cues (suite) where

import Prelude

import App.Stores.Cues (CuesBindings, DomElement, useCuesCore)
import Data.Maybe (Maybe(..))
import Data.Nullable (notNull, null, toMaybe)
import Effect (Effect)
import Effect.Uncurried (runEffectFn1, runEffectFn2)
import Record.Unsafe (unsafeGet)
import Test.Harness (Tally, expect)
import Vue (read)

element :: String -> DomElement
element name = unsafeGet "it" { it: name }

nameOf :: DomElement -> String
nameOf el = unsafeGet "it" { it: el }

groupsOf :: CuesBindings -> Effect (Array { root :: String, targets :: Array String })
groupsOf store = map (\g -> { root: nameOf g.root, targets: g.targets }) <$> read store.groups

hoveredOf :: CuesBindings -> Effect (Maybe { root :: String, targets :: Array String })
hoveredOf store =
  map (\g -> { root: nameOf g.root, targets: g.targets }) <<< toMaybe <$> read store.hovered

suite :: Tally -> Effect Unit
suite t = do
  store <- useCuesCore
  let
    rootA = element "root-a"
    rootB = element "root-b"
    register name = runEffectFn2 store.registerMark name (element ("mark-" <> name))
    unregister = runEffectFn1 store.unregisterMark
    activate = runEffectFn2 store.activate
    togglePin = runEffectFn2 store.togglePin
    isActive root = runEffectFn1 store.isActive (notNull root)
    targets = read store.activeTargets

  groupsOf store >>= expect t "a fresh store draws no groups" []
  targets >>= expect t "a fresh store has no active targets" []
  runEffectFn1 store.isActive null >>= expect t "a null root is never active" false
  isActive rootA >>= expect t "a fresh store has no active root" false

  register "alpha"
  activate rootA [ "alpha", "ghost" ]
  hoveredOf store >>= expect t "a hover keeps only the registered targets"
    (Just { root: "root-a", targets: [ "alpha" ] })
  targets >>= expect t "the hovered group's marks are active" [ "alpha" ]
  isActive rootA >>= expect t "the hovered root is active" true
  isActive rootB >>= expect t "another root is not active" false

  activate rootB [ "ghost" ]
  hoveredOf store >>= expect t "a root with no registered targets leaves the hover as it was"
    (Just { root: "root-a", targets: [ "alpha" ] })

  register "beta"
  togglePin rootB [ "beta", "alpha", "ghost" ]
  isActive rootB >>= expect t "a pinned root is active" true
  groupsOf store >>= expect t "pins are drawn first, then the unpinned hover"
    [ { root: "root-b", targets: [ "beta", "alpha" ] }
    , { root: "root-a", targets: [ "alpha" ] }
    ]
  targets >>= expect t "active targets concatenate every group's marks"
    [ "beta", "alpha", "alpha" ]

  activate rootB [ "beta" ]
  groupsOf store >>= expect t "hovering a pinned root does not draw it twice"
    [ { root: "root-b", targets: [ "beta", "alpha" ] } ]

  store.deactivate
  hoveredOf store >>= expect t "deactivating clears the hover" Nothing
  groupsOf store >>= expect t "deactivating leaves the pins drawn"
    [ { root: "root-b", targets: [ "beta", "alpha" ] } ]
  isActive rootA >>= expect t "an unhovered, unpinned root is not active" false

  togglePin rootB [ "beta" ]
  groupsOf store >>= expect t "a second click unpins the root" []
  isActive rootB >>= expect t "an unpinned root is no longer active" false

  togglePin rootA [ "ghost" ]
  isActive rootA >>= expect t "a click naming no registered mark pins nothing" false

  unregister "alpha"
  activate rootA [ "alpha" ]
  hoveredOf store >>= expect t "an unregistered mark no longer lights" Nothing
  activate rootA [ "alpha", "beta" ]
  targets >>= expect t "the remaining registered marks still light" [ "beta" ]

  togglePin rootB [ "beta" ]
  store.reset
  hoveredOf store >>= expect t "a reset clears the hover" Nothing
  groupsOf store >>= expect t "a reset clears every pin" []
  isActive rootB >>= expect t "a reset deactivates pinned roots" false
