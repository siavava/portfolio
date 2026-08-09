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

foreign import useColorModeImpl :: Effect ColorModeApi
foreign import colorModeValueImpl :: EffectFn1 ColorModeApi String
foreign import setPreferenceImpl :: EffectFn2 ColorModeApi String Unit

type ColorToggleBindings =
  { isDark :: Computed Boolean
  , toggle :: Effect Unit
  }

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
