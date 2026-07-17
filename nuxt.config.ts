// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: "2025-04-17",

  devtools: { enabled: true },

  modules: ["@nuxt/content", "@nuxt/image", "@pinia/nuxt", "@nuxtjs/color-mode", "@nuxt/eslint", "@nuxt/icon", "@nuxt/fonts", "nuxt-og-image"],

  site: {
    url: "https://amittai.studio",
    name: "amittai.studio",
  },

  /**
   * Proxima Soft Medium — the single face the reference ships; every weight
   * resolves to it. Commercial font (Mark Simonson Studio): license via
   * MyFonts/Adobe Fonts before deploying publicly.
   *
   * public/fonts/ProximaSoft-Medium.ttf must stay the only Proxima file the
   * local provider can scan: a woff2 copy would take priority in the emitted
   * @font-face, and satori (nuxt-og-image) cannot decode woff2, so the OG
   * card would silently fall back to Inter.
   */
  fonts: {
    families: [
      { name: "Proxima Soft", provider: "local", weights: [500], global: true },
    ],
  },

  colorMode: {
    classSuffix: "-mode",
    preference: "light",
    fallback: "light",
  },

  css: [
    "@/styles/colors.scss",
    "@/styles/default.sass",
    "@/styles/typography.scss",
  ],

  components: [
    {
      path: "@/components",
      pathPrefix: false,
    },
  ],

  imports: {
    dirs: [
      "~/composables/**",
    ],
  },

  content: {
    experimental: {
      nativeSqlite: false,
    },
  },

  icon: {
    mode: "svg",
    clientBundle: {
      scan: true,
    },
  },

  // SEO/social metadata lives in app.vue (useSeoMeta/useHead); only
  // presentation hints that predate the app bundle stay here.
  app: {
    head: {
      meta: [
        { name: "theme-color", content: "#f5f5f5" },
      ],
    },
  },

  routeRules: {
    "/**": { prerender: true },
  },

  typescript: {
    strict: true,

    // customize tsconfig.app.json
    tsConfig: tsConfig(),
    // customize tsconfig.shared.json
    sharedTsConfig: tsConfig(),
    // customize tsconfig.node.json
    nodeTsConfig: tsConfig(),
  },

  nitro: {
    typescript: {
      // customize tsconfig.server.json
      tsConfig: tsConfig(),
    },
  },
})

function tsConfig() {
  return {
    compilerOptions: {
      composite: true,
      noEmit: false,
      allowImportingTsExtensions: true,
      rewriteRelativeImportExtensions: true,
    },
    vueCompilerOptions: {
      plugins: [
        "@vue/language-plugin-pug",
      ],
    },
  }
}