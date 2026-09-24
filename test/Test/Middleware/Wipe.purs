-- | Cases for the `wipe.global` decision core: which navigations cross the
-- | index↔projects boundary (nested project routes included, look-alike
-- | and other routes not, a same-route "navigation" — the initial load —
-- | never), and which way the wipe sweeps: left→right leaving the index,
-- | right→left from anywhere else.
module Test.Middleware.Wipe (suite) where

import Prelude

import App.Middleware.Wipe (RouteLoc, WipeDecision, runWipeMiddleware, wipeDecision)
import Data.Foldable (for_)
import Data.Function.Uncurried (runFn2)
import Effect (Effect)
import Effect.Uncurried (runEffectFn2)
import Record.Unsafe (unsafeGet)
import Test.Harness (Tally, expect)

type Case = { from :: String, to :: String, out :: WipeDecision }

cases :: Array Case
cases =
  [ { from: "/", to: "/projects", out: { crossing: true, direction: "ltr" } }
  , { from: "/", to: "/projects/x", out: { crossing: true, direction: "ltr" } }
  , { from: "/projects/x", to: "/", out: { crossing: true, direction: "rtl" } }
  , { from: "/projects", to: "/", out: { crossing: true, direction: "rtl" } }
  , { from: "/projects", to: "/projects/y", out: { crossing: false, direction: "rtl" } }
  , { from: "/projects/x", to: "/projects/y", out: { crossing: false, direction: "rtl" } }
  , { from: "/", to: "/timeline", out: { crossing: false, direction: "ltr" } }
  , { from: "/", to: "/", out: { crossing: false, direction: "ltr" } }
  , { from: "/", to: "/projectsx", out: { crossing: false, direction: "ltr" } }
  , { from: "/projectsx", to: "/", out: { crossing: false, direction: "rtl" } }
  , { from: "/timeline", to: "/", out: { crossing: false, direction: "rtl" } }
  , { from: "/timeline", to: "/projects", out: { crossing: false, direction: "rtl" } }
  , { from: "/", to: "/projects/", out: { crossing: true, direction: "ltr" } }
  , { from: "/projects/a/b", to: "/", out: { crossing: true, direction: "rtl" } }
  , { from: "/projects", to: "/projects", out: { crossing: false, direction: "rtl" } }
  , { from: "/", to: "/Projects", out: { crossing: false, direction: "ltr" } }
  , { from: "/code", to: "/projects/x", out: { crossing: false, direction: "rtl" } }
  , { from: "/projects/x", to: "/code", out: { crossing: false, direction: "rtl" } }
  ]

type FakeRoute = { path :: String, meta :: { viewTransition :: Boolean } }

fakeRoute :: String -> Boolean -> FakeRoute
fakeRoute path viewTransition = { path, meta: { viewTransition } }

asRouteLoc :: FakeRoute -> RouteLoc
asRouteLoc route = unsafeGet "it" { it: route }

viewTransitionOf :: FakeRoute -> Effect Boolean
viewTransitionOf route = pure (unsafeGet "viewTransition" route.meta)

navigate :: FakeRoute -> FakeRoute -> Effect Unit
navigate to from = runEffectFn2 runWipeMiddleware (asRouteLoc to) (asRouteLoc from)

suite :: Tally -> Effect Unit
suite t = do
  for_ cases \c ->
    expect t ("wipeDecision " <> show c.from <> " → " <> show c.to) c.out
      (runFn2 wipeDecision c.from c.to)

  let
    index = fakeRoute "/" false
    project = fakeRoute "/projects/x" false
  navigate project index
  viewTransitionOf project >>= expect t "a crossing navigation turns the view transition on" true
  viewTransitionOf index >>= expect t "the route being left is not touched" false

  let
    first = fakeRoute "/projects/x" true
    second = fakeRoute "/projects/y" true
  navigate second first
  viewTransitionOf second >>= expect t "a navigation between projects turns it off" false
