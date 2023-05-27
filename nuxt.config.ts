// https://v3.nuxtjs.org/api/configuration/nuxt.config

import autoprefixer from "autoprefixer";

export default {
  publicRuntimeConfig: {
    apiKey: process.env.API_KEY,
    authDomain: process.env.AUTH_DOMAIN,
    projectId: process.env.PROJECT_ID,
    storageBucket: process.env.STORAGE_BUCKET,
    messagingSenderId: process.env.MESSAGING_SENDER_ID,
    appId: process.env.APP_ID,
    measurementId: process.env.MEASUREMENT_ID,
  },
  app: {
    pageTransition: { name: "page", mode: "out-in" },
    head: {
      title: "whatever",
      meta: [
        // meta: [
        { charset: "utf-8" },
        { name: "viewport", content: "width=device-width, initial-scale=1" },
        {
          hid: "description",
          name: "description",
          content: "Amittai's portfolio. A summary of his work, thoughts, and interests.",
        },
        // favicon
        { rel: "icon", type: "image/x-icon", href: "/favicons/favicon.ico" },
        {
          rel: "icon", type: "image/png", sizes: "32x32", href: "/favicons/favicon-32x32.png",
        },
        {
          rel: "icon", type: "image/png", sizes: "16x16", href: "/favicons/favicon-16x16.png",
        },
        {
          rel: "icon", type: "image/png", sizes: "96x96", href: "/favicons/favicon-96x96.png",
        },
        {
          rel: "icon", type: "image/png", sizes: "256x256", href: "/favicons/favicon-256x256.png",
        },
        { rel: "manifest", href: "/favicons/site.webmanifest" },
        { rel: "mask-icon", href: "/favicons/safari-pinned-tab.svg", color: "#5bbad5" },
        { rel: "shortcut icon", href: "/favicons/favicon.ico" },
        { rel: "apple-touch-icon", sizes: "180x180", href: "/favicons/apple-touch-icon.png" },
      ],
    },
  },
  typescript: {
    shim: false,
    strict: false,
  },
  modules: [
    "@nuxt/content",
    "@nuxt/ui",
    "@nuxt/image-edge",
    "@nuxt/devtools",
    "@pinia/nuxt",
  ],
  devtools: {
    // Enable devtools (default: true)
    enabled: true,
    // VS Code Server options
    vscode: {},
    // ...other options
  },
  content: {
    documentDriven: {
      // Will fetch navigation, page and surround.
      navigation: true,
      page: true,
      surround: true,

      // Will inject `[...slug].vue` as the root page.
      injectPage: true,
      ignores: [
        "content/jobs",
      ],
    },
    markdown: {
      remarkPlugins: [
        "remark-math",
      ],
      rehypePlugins: {
        "rehype-katex": {
          output: "html",
        },
      },
    },
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
    "~/styles/raw-fonts.scss",
    "~/styles/typography.scss",
    "~/styles/colors.scss",
    "~/styles/default.sass",
    "~/styles/footer.sass",
    "~/styles/geometry.scss",
    "~/styles/palettes.sass",
    "~/styles/theme.sass",
    "~/styles/transitions.sass",
  ],
  components: {
    dirs: [
      "~/components/icons",
      "~/components/atoms",
      "~/components/molecules",
      "~/components",
    ],
  },
  compilerOptions: {
    isCustomElement: [
      "vue-freezeframe",
    ],
  },
  plugins: [
    { src: "~/plugins/resize.ts", mode: "client" },
    // { src: "~/plugins/reveal.ts", mode: "client", ssr: false },
  ],
  vue: {
    compilerOptions: {
      directiveTransforms: {
        resizetrack: () => ({
          props: [],
          needRuntime: false,
        }),
        // reveal: () => ({
        //   props: [],
        //   needRuntime: false,
        // })
      },
    },
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
    provider: "ipx",
    ipx: {},
    dir: "static",
  },
  // serverMiddleware: {
  //   '/_ipx': '~/server/middleware/ipx.js'
  // },
  googleFonts: {
    families: {
      "DM+Sans": true, // [200, 300, 400, 500, 600, 700],
      "DM+Mono": true, // [200, 300, 400, 500, 600, 700],
      "Space+Mono": true, // [200, 300, 400, 500, 600, 700],
    },
    prefetch: true,
    preconnect: true,
    preload: true,
    display: "swap",
    useStyleSheet: true,
    // download: true,
    // base64: false,
    // inject: true,
    // fontsDir: "fonts",
    // base64: true,
    // inject: true,
    // fontsDir: "fonts",
    // fontsPath: "~assets/fonts",
    // stylePath: "styles/google-fonts.scss",
    // overwriting: false,
  },
  buildModules: [

    // Google Fonts
    "@nuxtjs/google-fonts",

    // Nuxt Image
    // "@nuxt/image-edge",

    // local

    "~/modules/users",
    "~/modules/utils",
  ],
  layouts: {
    default: "~/layouts/clean.vue",
  },
  build: {
    postcss: {
      postcssOptions: {
        preset: {
          autoprefixer: autoprefixer(),
        },
        // preset name
        // order: "cssnanoLast",
        // ordered plugin names
        // order: ["postcss-import", "postcss-preset-env", "cssnano"],
        // Function to calculate plugin order
        // order: (names, presets) => presets.cssnanoLast(names),
      },
    },
  },
  // imports: {
  //   dirs: [
  //     "modules/*.ts",
  //     "modules/*/index.ts",
  //     "composables",
  //   ],
  // },
};
