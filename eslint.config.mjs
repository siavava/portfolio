// @ts-check

import stylistic from "@stylistic/eslint-plugin"
import vuePug from "eslint-plugin-vue-pug"
import withNuxt from "./.nuxt/eslint.config.mjs"

export default withNuxt({
  ignores: [
    ".data",
    ".output",
    ".nuxt",
    "dist",
    "node_modules",
  ],
})
  .append({
    plugins: {
      "@stylistic": stylistic,
    },
    rules: {
      // @stylistic rules
      "@stylistic/semi": ["error", "never"],
      "@stylistic/indent": ["error", 2],
      "@stylistic/quotes": ["error", "double"],
      "@stylistic/max-len": ["off", { code: 80, ignoreUrls: true }],
      "@stylistic/comma-dangle": ["error", "always-multiline"],
      "@stylistic/object-curly-spacing": ["error", "always"],
      "@stylistic/object-property-newline": [
        "error", { allowAllPropertiesOnSameLine: true },
      ],
      "@stylistic/block-spacing": ["error", "always"],
      "@stylistic/brace-style": ["error", "1tbs", { "allowSingleLine": true }],
      "@stylistic/function-call-spacing": ["error", "never"],
      "@stylistic/key-spacing": ["error"],
      "@stylistic/keyword-spacing": ["error", {}],
      "@stylistic/lines-between-class-members": ["error", "always"],
      "@stylistic/member-delimiter-style": ["error", {
        "multilineDetection": "brackets",
        multiline: { delimiter: "none" },
        singleline: { delimiter: "comma" },
      }],
      "@stylistic/no-extra-parens": ["error"],
      "@stylistic/space-infix-ops": ["error"],
      "@stylistic/no-multiple-empty-lines": ["error", {
        max: 2,
        maxBOF: 0,
        maxEOF: 0,
      }],
    },
  })
  .append({
    rules: {
      "@typescript-eslint/no-empty-object-type": "off",
    },
  })
  .append({
    rules: {
      // vue rules
      "vue/multi-word-component-names": "off",
      "vue/no-v-html": "off",
    },
  })
  .append({
    rules: {
      // nuxt
      "nuxt/prefer-import-meta": "error",
    },
  })
  .append(vuePug.configs["flat/recommended"])
  .append({
    // sort imports
    rules: {
      "sort-imports": ["error", {
        "ignoreCase": false,
        "ignoreDeclarationSort": false,
        "ignoreMemberSort": false,
        "memberSyntaxSortOrder": ["none", "all", "multiple", "single"],
        "allowSeparatedGroups": true,
      }],
    },
  })
