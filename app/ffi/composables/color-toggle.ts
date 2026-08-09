/**
 * Typed FFI implementations for `App.Composables.ColorToggle` — the
 * `@nuxtjs/color-mode` edge.
 */
import { useColorMode } from "#imports"

type ColorModeApi = ReturnType<typeof useColorMode>

export const useColorModeImpl = (): ColorModeApi => useColorMode()

export const colorModeValueImpl = (colorMode: ColorModeApi): string => colorMode.value

export const setPreferenceImpl = (colorMode: ColorModeApi, preference: string): void => {
  colorMode.preference = preference
}
