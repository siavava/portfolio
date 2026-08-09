-- | ## ColorToggle
-- |
-- | Light/dark switch over `@nuxtjs/color-mode`. Flipping `preference`
-- | persists the choice and stamps the class before first paint, so
-- | there is no flash. The color-mode instance stays behind the FFI
-- | edge; the toggle logic lives here.
module App.Composables.ColorToggle
  ( ColorToggleBindings
  , useColorToggle
  ) where

import Prelude

import Effect (Effect)
import Effect.Uncurried (EffectFn1, EffectFn2, runEffectFn1, runEffectFn2)
import Vue (Computed, computed)

-- | The `@nuxtjs/color-mode` instance — opaque; read and written in
-- | the FFI.
foreign import data ColorModeApi :: Type

-- | The app's color-mode instance (Nuxt `useColorMode`).
foreign import useColorModeImpl :: Effect ColorModeApi

-- | The applied mode — `"dark"` or `"light"`, with `system` resolved.
-- | A reactive read, so computeds re-run when the mode flips.
foreign import colorModeValueImpl :: EffectFn1 ColorModeApi String

-- | Set the persisted preference; color-mode stores the choice and
-- | restamps the root class.
foreign import setPreferenceImpl :: EffectFn2 ColorModeApi String Unit

type ColorToggleBindings =
  { -- | Whether the applied mode is dark.
    isDark :: Computed Boolean
  , -- | Flip the persisted preference between light and dark.
    toggle :: Effect Unit
  }

-- | The color-mode toggle: `isDark` tracks the applied mode, `toggle`
-- | flips the persisted preference between light and dark.
useColorToggle :: Effect ColorToggleBindings
useColorToggle = do
  colorMode <- useColorModeImpl
  isDark <- computed ((_ == "dark") <$> runEffectFn1 colorModeValueImpl colorMode)
  pure
    { isDark
    , toggle: do
        value <- runEffectFn1 colorModeValueImpl colorMode
        runEffectFn2 setPreferenceImpl colorMode (if value == "dark" then "light" else "dark")
    }
