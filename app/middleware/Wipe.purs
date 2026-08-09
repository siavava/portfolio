-- | ## Wipe
-- |
-- | The decision core of the `wipe.global` route middleware: the root
-- | view-transition wipe runs only when crossing between the index and a
-- | projects route — never between two projects, never on initial load —
-- | and sweeps left→right leaving the index, right→left leaving a project.
module App.Middleware.Wipe
  ( WipeDecision
  , wipeDecision
  ) where

import Prelude

import Data.Function.Uncurried (Fn2, mkFn2)
import Data.String as String

type WipeDecision = { crossing :: Boolean, direction :: String }

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
