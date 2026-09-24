-- | ## AppFooter
-- |
-- | The setup composable behind `AppFooter.vue`: the light switch over the
-- | color toggle, with the words it shows and says; the client-mount flag
-- | that keeps those words color-mode agnostic until hydration; and the
-- | hover-delayed past-versions popover. The SFC keeps only the prop macro
-- | plus one call here, handing in the color toggle.
module App.Components.AppFooter
  ( FooterArgs
  , FooterBindings
  , footerAriaFor
  , footerLabelFor
  , setup
  , versionHost
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), Replacement(..), replace)
import Effect (Effect)
import Effect.Ref as Ref
import Effect.Timer (TimeoutId, clearTimeout, setTimeout)
import Vue (Computed, Ref, computed, onMounted, onUnmounted, read, ref, write)

type FooterArgs =
  { -- | The color toggle (`useColorToggle`) the light switch flips.
    -- | Handed in rather than called here: its FFI reaches Nuxt's
    -- | `#imports`, which would keep this module out of the bun-run unit
    -- | tests.
    colorToggle :: { isDark :: Computed Boolean, toggle :: Effect Unit }
  }

type FooterBindings =
  { -- | Whether the applied color mode is dark.
    isDark :: Computed Boolean
  -- | Click handler: flips the persisted preference between light and dark.
  , toggleColor :: Effect Unit
  -- | The light switch's text.
  , themeLabel :: Computed String
  -- | The light switch's accessible name: its state and what it does.
  , themeAria :: Computed String
  -- | A past version's address without its scheme, as the popover lists it.
  , versionHost :: String -> String
  -- | True once mounted on the client — gates the theme-label text so
  -- | SSR markup stays color-mode agnostic.
  , mounted :: Ref Boolean
  -- | Past-versions popover open state.
  , showVersions :: Ref Boolean
  -- | Mouseenter handler: opens the popover, cancelling a pending close.
  , openVersions :: Effect Unit
  -- | Mouseleave handler: closes the popover after a 300 ms grace delay.
  , closeVersions :: Effect Unit
  }

-- | The light switch's text, given whether the footer has mounted and
-- | whether the page is dark: until mount it always reads "lights off",
-- | the words the server rendered.
footerLabelFor :: Boolean -> Boolean -> String
footerLabelFor mounted dark = if mounted && dark then "lights on" else "lights off"

-- | The light switch's accessible name, gated on mount the same way.
footerAriaFor :: Boolean -> Boolean -> String
footerAriaFor mounted dark =
  if mounted && dark then "lights on — switch to light mode"
  else "lights off — switch to dark mode"

-- | An address without its leading `https://` — only the first one, the
-- | way `String.prototype.replace` strips it; any other scheme stays.
versionHost :: String -> String
versionHost = replace (Pattern "https://") (Replacement "")

-- | Wires the footer: the color toggle and the light switch's words, a
-- | client-mount flag for them, and the hover-delayed past-versions
-- | popover with its 300 ms close grace.
setup :: FooterArgs -> Effect FooterBindings
setup args = do
  let colorToggle = args.colorToggle

  mounted <- ref false
  onMounted (write mounted true)

  let
    switchWords pick = do
      isMounted <- read mounted
      dark <- if isMounted then read colorToggle.isDark else pure false
      pure (pick isMounted dark)

  themeLabel <- computed (switchWords footerLabelFor)
  themeAria <- computed (switchWords footerAriaFor)

  showVersions <- ref false
  closeTimer <- Ref.new (Nothing :: Maybe TimeoutId)

  let
    clearClose = Ref.read closeTimer >>= case _ of
      Just pending -> clearTimeout pending *> Ref.write Nothing closeTimer
      Nothing -> pure unit

    openVersions = clearClose *> write showVersions true

    closeVersions = do
      clearClose
      pending <- setTimeout 300 (write showVersions false)
      Ref.write (Just pending) closeTimer

  onUnmounted clearClose

  pure
    { isDark: colorToggle.isDark
    , toggleColor: colorToggle.toggle
    , themeLabel
    , themeAria
    , versionHost
    , mounted
    , showVersions
    , openVersions
    , closeVersions
    }
