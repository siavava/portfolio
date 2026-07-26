// @ts-check

import shared from "@siavava/eslint-config"
import withNuxt from "./.nuxt/eslint.config.mjs"

export default shared(withNuxt({
  // @ts-ignore
  ignores: [
    ".data",
    ".output",
    ".nuxt",
    "dist",
    "node_modules",
  ],
  rules: {
    "no-empty": ["error", { allowEmptyCatch: true }],
  },
}))
