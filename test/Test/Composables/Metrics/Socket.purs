-- | Checks for the shared socket's scope table: one handler per scope,
-- | a later registration replacing the earlier one, and incoming
-- | messages routed by exact scope key to whichever handler is current.
-- | The wire value of each scope is covered in `Test.Utils.Metrics`.
module Test.Composables.Metrics.Socket (suite) where

import Prelude

import App.Composables.Metrics.Socket (Scope(..), scopeHandlerFor, scopeKey, withScopeHandler)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Test.Harness (Tally, expect)

type Entry = { key :: String, handler :: String }

entry :: String -> String -> Entry
entry key handler = { key, handler }

both :: Array Entry
both = withScopeHandler "status" "onStatus" (withScopeHandler "watch" "onWatch" [])

suite :: Tally -> Effect Unit
suite t = do
  expect t "register: the first handler starts the table"
    [ entry "watch" "onWatch" ]
    (withScopeHandler "watch" "onWatch" [])
  expect t "register: a new scope joins the end"
    [ entry "watch" "onWatch", entry "status" "onStatus" ]
    both
  expect t "register: a second handler for a scope replaces the first"
    [ entry "status" "onStatus", entry "watch" "onWatch2" ]
    (withScopeHandler "watch" "onWatch2" both)
  expect t "register: re-registering the same handler keeps one entry"
    [ entry "status" "onStatus", entry "watch" "onWatch" ]
    (withScopeHandler "watch" "onWatch" both)

  expect t "route: a message reaches its scope's handler" (Just "onStatus")
    (scopeHandlerFor "status" both)
  expect t "route: an unknown scope is dropped" Nothing (scopeHandlerFor "presence" both)
  expect t "route: nothing registered, nothing routed" Nothing
    (scopeHandlerFor "watch" ([] :: Array Entry))
  expect t "route: the latest registration handles the scope" (Just "onWatch2")
    (scopeHandlerFor "watch" (withScopeHandler "watch" "onWatch2" both))
  expect t "route: scope keys match exactly" Nothing (scopeHandlerFor "Watch" both)
  expect t "route: a handler registered under the watch scope's wire key is found"
    (Just "onWatch")
    (scopeHandlerFor "watch" (withScopeHandler (scopeKey Watch) "onWatch" []))
