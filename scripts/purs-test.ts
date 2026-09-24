/**
 * Runs the PureScript unit tests through bun, which transparently compiles
 * the typed FFI (`app/ffi/**.ts`) that the compiled modules re-export —
 * `spago test` shells out to node, which cannot import the .ts files.
 * `purs:check` chains `purs:build` first, so the compiled output exists.
 *
 * Nuxt's `#imports` virtual module only exists inside a Nuxt build, so an
 * FFI file that imports from it could not even be loaded here. The tests
 * exercise pure policy only, never those composables, so `#imports`
 * resolves to a stub whose every export throws if it is ever called.
 */
import { plugin } from "bun"

// Must list every name an FFI file imports from `#imports`: a missing named export fails at load.
const NUXT_ONLY = [
  "queryCollection",
  "useAsyncData",
  "useColorMode",
  "useConnections",
  "useInterestLayout",
  "useMapReveal",
  "useRouter",
]

const nuxtOnly = (name: string) => (): never => {
  throw new Error(`#imports.${name} is Nuxt-only — unavailable under the unit tests`)
}

plugin({
  name: "nuxt-imports-stub",
  setup(build) {
    // A virtual module: bun's runtime `onResolve` never sees `#` specifiers.
    build.module("#imports", () => ({
      loader: "object",
      exports: Object.fromEntries(NUXT_ONLY.map(name => [name, nuxtOnly(name)])),
    }))
  },
})

// Imported after the plugin is registered, so the FFI's `#imports` resolves.
const { main } = await import("../.purs/output/Test.Main/index.js")

main()
