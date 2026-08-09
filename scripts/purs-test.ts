/**
 * Runs the PureScript unit tests through bun, which transparently compiles
 * the typed FFI (`app/ffi/**.ts`) that the compiled modules re-export —
 * `spago test` shells out to node, which cannot import the .ts files.
 * `purs:check` chains `purs:build` first, so the compiled output exists.
 */
import { main } from "../.purs/output/Test.Main/index.js"

main()
