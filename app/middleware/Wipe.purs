-- | ## Wipe
-- |
-- | The `wipe.global` route middleware: the root view-transition wipe runs
-- | only when crossing between the index and a projects route — never
-- | between two projects, never on initial load — and sweeps left→right
-- | leaving the index, right→left leaving a project. `wipeDecision` is
-- | the pure core; `runWipeMiddleware` applies it to the navigation,
-- | toggling the route's view transition and recording the sweep
-- | direction on `<html>` for the wipe CSS.
module App.Middleware.Wipe
  ( RouteLoc
  , WipeDecision
  , runWipeMiddleware
  , wipeDecision
  ) where

import Prelude

import Data.Function.Uncurried (Fn2, mkFn2, runFn2)
import Data.String as String
import Effect.Uncurried (EffectFn1, EffectFn2, mkEffectFn2, runEffectFn1, runEffectFn2)

-- | A normalized `vue-router` route location. @ts import("vue-router").RouteLocationNormalized
foreign import data RouteLoc :: Type

foreign import routePathImpl :: RouteLoc -> String

foreign import setViewTransitionImpl :: EffectFn2 RouteLoc Boolean Unit

foreign import markWipeDirectionImpl :: EffectFn1 String Unit

-- | What the middleware does with one navigation.
type WipeDecision =
  { -- | Whether this navigation crosses the index↔projects boundary at all.
    crossing :: Boolean
  , -- | `"ltr"` leaving the index, `"rtl"` leaving a project.
    direction :: String
  }

isIndex :: String -> Boolean
isIndex path = path == "/"

isProjects :: String -> Boolean
isProjects path = path == "/projects" || isJustPrefix
  where
  isJustPrefix = String.take 10 path == "/projects/"

-- | Decide the wipe for a navigation from `fromPath` to `toPath`.
wipeDecision :: Fn2 String String WipeDecision
wipeDecision = mkFn2 \fromPath toPath ->
  { crossing:
      (isIndex fromPath && isProjects toPath)
        || (isProjects fromPath && isIndex toPath)
  , direction: if isIndex fromPath then "ltr" else "rtl"
  }

-- | The middleware body, taking `(to, from)` in Nuxt's order: enable the
-- | view transition only for a crossing navigation, and mark the sweep
-- | direction when it is one.
runWipeMiddleware :: EffectFn2 RouteLoc RouteLoc Unit
runWipeMiddleware = mkEffectFn2 \to from -> do
  let decision = runFn2 wipeDecision (routePathImpl from) (routePathImpl to)
  runEffectFn2 setViewTransitionImpl to decision.crossing
  when decision.crossing (runEffectFn1 markWipeDirectionImpl decision.direction)
