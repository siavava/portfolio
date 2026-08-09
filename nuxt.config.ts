import { fileURLToPath } from "node:url"
import { readdirSync } from "node:fs"

import { applyTransforms } from "./transformers"
import { latex } from "./configs"

const pursServerModule = (name: string) =>
  fileURLToPath(new URL(`./.purs/output/${name}/index.js`, import.meta.url))

// Every app/server/*.purs module, by basename. Safe to readdir at
// config-eval time: app/server is checked-in source, and the alias values
// are plain path strings rollup resolves later (after purs:build).
const pursServerModules = readdirSync(fileURLToPath(new URL("./app/server", import.meta.url)))
  .filter(file => file.endsWith(".purs"))
  .map(file => `App.Server.${file.replace(/\.purs$/, "")}`)

// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: "2025-04-17",

  devtools: { enabled: true },

  experimental: {
    viewTransition: true,
  },

  // PureScript FFI companions must sit beside their .purs modules with the
  // module's basename (uppercase); keep them and .purs sources out of
  // auto-import scans.
  ignore: [
    "app/**/*.purs",
    "app/**/[A-Z]*.js",
  ],

  modules: [
    "@nuxtjs/robots",
    "@nuxt/content",
    "@nuxt/image",
    "@pinia/nuxt",
    "@nuxtjs/color-mode",
    "@nuxt/eslint",
    "@nuxt/icon",
    "@nuxt/fonts",
    "@vercel/analytics",
    "@vercel/speed-insights",
    "nuxt-og-image",
  ],

  site: {
    url: "https://amittai.studio",
    name: "amittai.studio",
  },

  robots: {
    blockAiBots: false,
    blockNonSeoBots: false,
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
      "@/composables/**",
      "@/utils/**",
      "@/stores/**",
      // Build-time shims generated from the PureScript modules
      // (purs:build) join the auto-import pool.
      "~~/.purs-shims/**",
    ],
  },

  vite: {
    resolve: {
      // Probe .ts before .js: on this case-insensitive filesystem an
      // extensionless `~/utils/scroll` would otherwise resolve to the
      // PureScript FFI stub `Scroll.js` instead of the shim `scroll.ts`.
      extensions: [".mts", ".ts", ".mjs", ".js", ".json", ".vue"],
    },
    // Dependencies vite otherwise discovers mid-session (triggering a
    // dev-server page reload on first hit).
    optimizeDeps: {
      include: [
        "@vue/devtools-core",
        "@vue/devtools-kit",
        "@vueuse/core",
        "d3-force",
        "motion-v",
      ],
    },
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
    // Explicit rule so the pre-rendered output keeps the XML content-type.
    "/sitemap.xml": {
      prerender: true,
      headers: { "Content-Type": "application/xml; charset=utf-8" },
    },
    "/archive": { redirect: { to: "/projects", statusCode: 301 } },
    "/**": { prerender: true },
  },

  typescript: {
    strict: true,

    // Only the app project sees the PureScript layers; giving them to the
    // shared/node projects drags app-runtime files (ffi, stores) into
    // projects that lack the auto-import types.
    tsConfig: tsConfig({ purs: "app" }),
    sharedTsConfig: tsConfig({}),
    nodeTsConfig: tsConfig({}),
  },

  nitro: {
    prerender: {
      autoSubfolderIndex: false,
    },
    // Vite resolves #purs through the package `imports` field, but nitro's
    // rollup leaves it external and the built chunks can no longer resolve
    // it at runtime — alias the server modules (derived from app/server/*.purs
    // above) to their compiled entries so they inline into the server bundle.
    alias: Object.fromEntries(
      pursServerModules.map(name => [`#purs/${name}`, pursServerModule(name)]),
    ),
    typescript: {
      // The nitro shells import #purs/App.Server.* — they get the paths
      // mapping and only the server-module declarations.
      tsConfig: tsConfig({ purs: "server" }),
    },
  },
})

function tsConfig({ purs }: { purs?: "app" | "server" } = {}) {
  const include = [
    "../configs/**/*",
    "../transformers/**/*",
    "../app/types/*.d.ts",
  ]
  if (purs === "app") include.push("../app/types/purs/*.d.ts", "../.purs-shims/**/*.ts")
  if (purs === "server") include.push("../app/types/purs/App.Server.*.d.ts")

  return {
    include,
    compilerOptions: {
      composite: true,
      noEmit: false,
      allowImportingTsExtensions: true,
      rewriteRelativeImportExtensions: true,
      // TypeScript sees the PureScript modules through these typed
      // declarations; bundlers resolve #purs to .purs/output/ via package
      // imports. The server project needs EXACT per-module keys too: nuxt
      // injects the nitro aliases into tsconfig.server.json paths, and an
      // exact key beats the wildcard — without these overrides the alias
      // pulls the compiled .purs/output js into the type program (TS6307).
      ...purs
        ? {
          paths: {
            "#purs/*": ["../app/types/purs/*"],
            ...purs === "server"
              ? Object.fromEntries(pursServerModules.map(name =>
                [`#purs/${name}`, [`../app/types/purs/${name}.d.ts`]]))
              : {},
          },
        }
        : {},
    },
    vueCompilerOptions: {
      plugins: [
        "@vue/language-plugin-pug",
      ],
    },
  }
}
