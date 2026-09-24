-- | ## TimelineTransition
-- |
-- | The page transition the timeline takes part in. `/timeline` is its own
-- | page, so the panel growing out of the name bar and docking back into it
-- | has to happen *across* a navigation: while the timeline enters, the
-- | page it grew from stays mounted and dims behind it; while it leaves,
-- | the page it docks into is already back underneath. This module decides
-- | which choreography a navigation gets — any other navigation, the wipe
-- | included, is left exactly alone. The transition specs themselves hold
-- | DOM hooks and live behind the FFI edge.
module App.Composables.TimelineTransition
  ( Phase(..)
  , TransitionArgs
  , TransitionBindings
  , TransitionSpec
  , phaseFor
  , setup
  ) where

import Prelude

import App.Stores.Timeline (Rect)
import Data.Maybe (Maybe(..))
import Data.Nullable (Nullable, toMaybe)
import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn3, mkEffectFn3, runEffectFn1, runEffectFn3)
import Vue (Computed, computed, onUnmounted, read, shallowRef, write)

-- | A Vue `<Transition>` props object. @ts import("vue").TransitionProps
foreign import data TransitionSpec :: Type

foreign import onNavigateImpl :: EffectFn1 (EffectFn3 String String Boolean Unit) (Effect Unit)

foreign import idleSpecImpl :: TransitionSpec

foreign import openSpecImpl :: TransitionSpec

foreign import dockSpecImpl
  :: EffectFn3 (Effect (Nullable Rect)) (Effect Number) (Effect Unit) TransitionSpec

foreign import fadeSpecImpl :: EffectFn1 (Effect Unit) TransitionSpec

-- | What one navigation does with the timeline.
data Phase
  = Open
  | Dock
  | Fade
  | Idle

derive instance Eq Phase

timelinePath :: String
timelinePath = "/timeline"

hasBar :: String -> Boolean
hasBar path = path == "/" || path == "/code"

-- | The phase for a navigation: opening over a bar page, docking back into
-- | the page the panel came from, fading out anywhere else, or nothing.
phaseFor :: Nullable String -> String -> String -> Phase
phaseFor origin from to
  | to == timelinePath && hasBar from = Open
  | from == timelinePath && toMaybe origin == Just to = Dock
  | from == timelinePath = Fade
  | otherwise = Idle

type TransitionArgs =
  { -- | Reads the name bar's rect the panel grew from, if any.
    origin :: Effect (Nullable Rect)
  -- | Reads the route that bar is on.
  , originPath :: Effect (Nullable String)
  -- | Reads how far that page was scrolled when the bar was clicked.
  , originScroll :: Effect Number
  -- | The panel docked: count the landing and release the origin.
  , land :: Effect Unit
  -- | The panel left without docking: release the origin.
  , clearOrigin :: Effect Unit
  }

type TransitionBindings =
  { -- | The transition props for the navigation under way — always a spec,
    -- | never absent, so `<NuxtPage>` keeps one stable `<Transition>`
    -- | wrapper instead of mounting and unmounting it around the pages.
    transition :: Computed TransitionSpec
  }

-- | Follows the router and picks the timeline's choreography for each
-- | navigation before the pages change hands.
setup :: TransitionArgs -> Effect TransitionBindings
setup args = do
  phase <- shallowRef Idle
  dock <- runEffectFn3 dockSpecImpl args.origin args.originScroll args.land
  fade <- runEffectFn1 fadeSpecImpl args.clearOrigin

  unbind <- runEffectFn1 onNavigateImpl $ mkEffectFn3 \from to initial ->
    if initial then write phase Idle
    else do
      origin <- args.originPath
      write phase (phaseFor origin from to)

  transition <- computed do
    current <- read phase
    pure case current of
      Open -> openSpecImpl
      Dock -> dock
      Fade -> fade
      Idle -> idleSpecImpl

  onUnmounted unbind

  pure { transition }
