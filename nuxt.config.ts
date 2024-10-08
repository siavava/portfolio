// https://v3.nuxtjs.org/api/configuration/nuxt.config

export default defineNuxtConfig({
  experimental: {
    viewTransition: true,
    // payloadExtraction: true,
  },
  routeRules: {
    "/**": {
      prerender: true,
    },
  },
  app: {
    pageTransition: { name: "page", mode: "out-in" },
    layoutTransition: { name: "layout", mode: "out-in" },

    head: {
      title: "whatever",
      htmlAttrs: {
        lang: "en",
      },
      meta: [
        { charset: "utf-8" },
        { name: "viewport", content: "width=device-width, initial-scale=1" },
        { name: "theme-color", content: "#0A0A0A" },
        { property: "og:type", content: "article" },
        { property: "og:site_name", content: "alt." },
        { property: "og:locale", content: "en_US" },
        { name: "robots", content: "index, follow" },
        // {
        //   hid: "description",
        //   name: "description",
        //   content: "Amittai's portfolio. A summary of his work, thoughts, and interests.",
        // },
      ],
      link: [
        { rel: "icon", type: "image/svg", href: "/favicon.svg" },
        {
          rel: "mask-icon", type: "image/svg", href: "/favicon.svg", color: "#f42e4f",
        },
        {
          rel: "apple-touch-icon", type: "image/svg", href: "/favicon.svg",
        },
        // {
        //   rel: "manifest", href: "/manifest.json",
        // },
      ],
    },
  },
  typescript: {
    shim: false,
    strict: false,
  },
  modules: [
    "@nuxt/content",
    // "@nuxt/ui",
    "@nuxt/image",
    "@nuxt/devtools",
    "@nuxtjs/color-mode",
    ["@nuxtjs/robots", {
      UserAgent: "*",
      Disallow: "",
    }],
  ],
  colorMode: {
    preference: "one", // default value of $colorMode.preference
    fallback: "one", // fallback value if not system preference found
  },
  
  router: { },
  devtools: {
    // Enable devtools (default: true)
    enabled: true,
    // VS Code Server options
    vscode: {},
    // ...other options
    timeline: {
      enabled: true,
    },
  },
  content: {
    documentDriven: {
      // Will fetch navigation, page and surround.
      navigation: true,
      page: true,
      surround: true,

      // Will inject `[...slug].vue` as the root page.
      injectPage: true,
      trailingSlash: true,
    },
    markdown: { },
    highlight: {
      theme: "github-dark",
      preload: [
        "bash",
        "c",
        "cpp",
        "java",
        "julia",
        "python",
        "haskell",
        "f#",
        "vue",
      ],
    },
  },

  ssr: true,

  css: [
    "@/styles/colors.scss",
    "@/styles/default.sass",
    "@/styles/footer.sass",
    "@/styles/geometry.scss",
    "@/styles/mixins.sass",
    "@/styles/palettes.sass",
    "@/styles/raw-fonts.scss",
    "@/styles/theme.sass",
    "@/styles/transitions.sass",
    "@/styles/typography.scss",
  ],
  components: {
    dirs: [
      "~/components/icons",
      "~/components/molecules",
      "~/components",
    ],
  },
  image: {
    // The screen sizes predefined by `@nuxt/image-edge`:
    screens: {
      xs: 320,
      sm: 640,
      md: 768,
      lg: 1024,
      xl: 1280,
      xxl: 1536,
      "2xl": 1536,
    },
    // format: ["avif", "webp"],
    provider: "ipx",
    // ipx: {},
    dir: "static",
  },
})
