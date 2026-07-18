/**
 * ## useColorToggle
 *
 * Light/dark switch over `@nuxtjs/color-mode`. Flipping
 * `preference` persists the choice and stamps the class
 * before first paint, so there is no flash.
 *
 * ### Returns
 *
 * | Name | Type | Description |
 * | --- | --- | --- |
 * | `isDark` | `ComputedRef<boolean>` | Whether dark mode is active |
 * | `toggle` | `() => void` | Switch between light and dark |
 */
export function useColorToggle() {
  const colorMode = useColorMode()
  const isDark = computed(() => colorMode.value === "dark")

  const toggle = () => {
    colorMode.preference = colorMode.value === "dark" ? "light" : "dark"
  }

  return { isDark, toggle }
}
