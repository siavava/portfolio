-- | Cases for the metrics namespace helpers and the socket's wire scope:
-- | the portfolio's `<p>:` prefix going on and coming off backend routes,
-- | and the `scope` value the store's watch messages carry.
module Test.Utils.Metrics (suite) where

import Prelude

import App.Composables.Metrics.Socket (Scope(..), scopeKey)
import App.Utils.Metrics
  ( inNamespace
  , metricsNamespace
  , metricsNamespaceId
  , withNamespace
  , withoutNamespace
  )
import Data.Foldable (for_)
import Effect (Effect)
import Test.Harness (Tally, expect)

type StripCase = { input :: String, out :: String }

stripCases :: Array StripCase
stripCases =
  [ { input: "<p>:/x", out: "/x" }
  , { input: "<p>:/projects/portfolio", out: "/projects/portfolio" }
  , { input: "<p>:", out: "" }
  , { input: "/x", out: "/x" }
  , { input: "<b>:/x", out: "<b>:/x" }
  , { input: "<n>:/notes/a", out: "<n>:/notes/a" }
  , { input: "x<p>:/y", out: "x<p>:/y" }
  , { input: "", out: "" }
  ]

type MemberCase = { input :: String, out :: Boolean }

memberCases :: Array MemberCase
memberCases =
  [ { input: "<p>:/x", out: true }
  , { input: "<p>:", out: true }
  , { input: "<b>:/x", out: false }
  , { input: "<n>:/x", out: false }
  , { input: "/x", out: false }
  , { input: "<p>/x", out: false }
  , { input: "", out: false }
  ]

suite :: Tally -> Effect Unit
suite t = do
  expect t "metricsNamespaceId" "<p>" metricsNamespaceId
  expect t "metricsNamespace" "<p>:" metricsNamespace

  expect t "withNamespace \"/x\"" "<p>:/x" (withNamespace "/x")
  expect t "withNamespace \"/\"" "<p>:/" (withNamespace "/")
  expect t "withNamespace \"\"" "<p>:" (withNamespace "")

  for_ stripCases \c ->
    expect t ("withoutNamespace " <> show c.input) c.out (withoutNamespace c.input)

  for_ memberCases \c ->
    expect t ("inNamespace " <> show c.input) c.out (inNamespace c.input)

  for_ [ "/", "/x", "/projects/portfolio" ] \path -> do
    let label = "withoutNamespace (withNamespace " <> show path <> ")"
    expect t label path (withoutNamespace (withNamespace path))

  expect t "scopeKey Watch" "watch" (scopeKey Watch)
