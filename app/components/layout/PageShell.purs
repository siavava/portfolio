-- | ## PageShell
-- |
-- | The setup composable behind the default layout: whether the page shell
-- | offers its skip-to-content link. The timeline carries its own, first
-- | in its own tab order, so the shell's would only be a second stop in
-- | front of it there. The SFC keeps the route handle and one call here.
module App.Components.PageShell
  ( ShellArgs
  , ShellBindings
  , setup
  ) where

import Prelude

import Effect (Effect)
import Vue (Computed, computed)

timelinePath :: String
timelinePath = "/timeline"

type ShellArgs =
  { -- | Reads the current route path.
    path :: Effect String
  }

type ShellBindings =
  { -- | Whether the shell renders its skip-to-content link.
    skipLink :: Computed Boolean
  }

-- | Derives the skip link's presence from the route.
setup :: ShellArgs -> Effect ShellBindings
setup args = do
  skipLink <- computed ((_ /= timelinePath) <$> args.path)
  pure { skipLink }
