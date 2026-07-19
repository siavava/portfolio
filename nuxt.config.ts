import { applyTransforms } from "./transformers"
import { latex } from "./configs"

// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: "2025-04-17",

  devtools: { enabled: true },

  experimental: {
    viewTransition: true,
  },

  modules: ["@nuxt/content", "@nuxt/image", "@pinia/nuxt", "@nuxtjs/color-mode", "@nuxt/eslint", "@nuxt/icon", "@nuxt/fonts", "nuxt-og-image"],

  site: {
    url: "https://amittai.studio",
    name: "amittai.studio",
  },

  ogImage: {
    security: {
      renderTimeout: 60000,
    },
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
      { name: "Departure Mono", provider: "local", weights: [400], global: true },
      { name: "Arizona Text", provider: "local", weights: [400, 700], styles: ["normal", "italic"], global: true },
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
    "@/styles/study-bridge.scss",
    "@/styles/visualizer.scss",
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

  hooks: {
    // The study's build-time pipeline: TikZ blocks render to themed SVG
    // before @nuxt/content ever parses the markdown.
    async "content:file:beforeParse"(ctx) {
      const { file } = ctx
      if (!file.id.endsWith(".md")) return
      ctx.file = { ...file, body: await applyTransforms(file.body) }
    },
  },

  content: {
    experimental: {
      nativeSqlite: false,
    },
    build: {
      markdown: {
        remarkPlugins: {
          "remark-math": {},
        },
        rehypePlugins: {
          "rehype-katex": {
            errorColor: "#BD998F",
            globalGroup: true,
            options: {
              output: "html",
              macros: latex(),
              trust: true,
              strict: false,
            },
          },
        },
      },
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
      link: [
        { rel: "icon", type: "image/svg", href: "/favicon.svg" },
        {
          rel: "mask-icon",
          type: "image/svg",
          href: "/favicon.svg",
          color: "#111110",
        },
        {
          rel: "apple-touch-icon",
          type: "image/svg",
          href: "/favicon.svg",
          color: "#111110",
        },
        {
          rel: "preconnect",
          href: "https://cdn.jsdelivr.net",
          crossorigin: "anonymous",
        },
        {
          rel: "stylesheet",
          href: "https://cdn.jsdelivr.net/npm/katex@0.16.42/dist/katex.min.css",
          crossorigin: "anonymous",
        },
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
    prerender: {
      autoSubfolderIndex: false,
    },
    typescript: {
      // customize tsconfig.server.json
      tsConfig: tsConfig(),
    },
  },
})

function tsConfig() {
  return {
    include: [
      "../configs/**/*",
      "../transformers/**/*",
      "../app/types/*.d.ts",
    ],
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