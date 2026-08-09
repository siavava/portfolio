# PureScript in the portfolio

This branch (`pure`) converts the portfolio's TypeScript to PureScript —
utils, composables (including the metrics network stack), all five pinia
store cores, the metrics plugin wiring, route middleware, the nitro route
cores, and the SFC script logic component by component. Behavior is pinned
by an 858-case golden diff (`bun run purs:check`), `nuxi typecheck`, and
byte-parity checks on the server routes.

## Layout — the Nuxt structure, operating in PureScript

PureScript sources live in `app/` beside the code they power (the new spago
hardcodes `src/`, so `src` is a symlink → `app`):

- Utils, composables, and stores group **one module per kebab-case
  subdirectory**: the `.purs` source, its generated companion stub, and —
  when one exists — the hand shim as an `index.ts` barrel
  (`app/utils/coder/{Coder.purs, index.ts}`,
  `app/stores/map-reveal/{MapReveal.purs, index.ts}`,
  `app/composables/metrics/socket/{Socket.purs, index.ts}`). The barrel
  keeps directory imports working (`~/utils/coder`) and auto-import pools
  scan the nested dirs via `imports.dirs` globs (`~/utils/**`,
  `~/stores/**`, `~/composables/**`). Middleware, server, and component
  modules sit beside their consumers as before.
- `app/ffi/**` — **typed** FFI implementations, mirroring module paths as
  subdirectories (`App.Composables.Metrics.Socket` →
  `app/ffi/composables/metrics/socket.ts`); shared helpers at the root
- `.purs-shims/` — build-generated auto-import shims (gitignored)
- `app/types/purs/` — build-generated TypeScript declarations (gitignored)

Two directories must never hold PS modules: `app/pages/` and `app/plugins/`
(their generated companion stubs would be scanned as routes/plugins) —
page-level setup composables live under `app/components/` instead.

Nuxt's `ignore` keeps `.purs` sources and the uppercase FFI companions out
of auto-import scans, and `make clean` removes every generated layer
(shims, declarations, stubs, output, `.nuxt`).

## The FFI is typed TypeScript, and the stubs are generated

`purs` mandates a same-basename `.js` companion per FFI module, but accepts
**named re-exports** — so each companion is one line pointing at a typed
implementation in `app/ffi/<kebab>.ts` (path relative to the compiled
`output/<Module>/foreign.js`, the only copy anything imports; a `#`-alias
cannot work there because spago writes its own `output/package.json`,
which resets the package boundary). Vite, bun, and Nuxt all compile the
`.ts` transparently.

The companions themselves are not written by hand:
`scripts/purs-ffi-stubs.mjs` (first step of `purs:build`) parses each
module declaration and its `foreign import`s and emits the stub next to
the `.purs` file — gitignored (`app/**/[A-Z]*.js`), like every other build
artifact. The convention it enforces: one FFI file per module at
`app/ffi/<module-path-as-subdirs>.ts` (full path, so same-basename modules
in different namespaces can never collide — a lesson learned when two
`FigureSpotlight` modules overwrote each other's FFI).

## Shims are build artifacts, not hand-written files

`scripts/purs-dts.mjs` (run by `bun run purs:build`) reads the typed AST
spago emits per module (`output/<Module>/docs.json`) and generates:

1. **Declarations** — `app/types/purs/<Module>.d.ts`. TypeScript resolves
   `#purs/<Module>` there via tsconfig `paths`; bundlers resolve the same
   specifier to `output/` via the package `imports` field. Argument names
   come from the PureScript defining equations (or FFI arrow parameters);
   `Effect`/`EffectFn*`/`Fn*`/`Nullable`/records/arrays all translate.
2. **Runtime shims** — `.purs-shims/<module>.ts`, bare typed re-exports
   that join Nuxt's auto-import pool (`imports.dirs`). A module qualifies
   by exporting its boundary pre-uncurried under the public name
   (`useAfterPaint :: EffectFn1 …`).

The few hand adapters that remain live as `index.ts` barrels beside their
module, each for a reason the generator cannot know: `utils/coder`
(reshapes to the original discriminated union), `utils/scroll` (default
`duration = 480`), `utils/katex` (default param + re-exports
`KATEX_MACROS` from the FFI layer).

## Interfacing with Vue: the `vue-bridge` package

The bridge is an externalized spago workspace package at
`packages/vue-bridge/` (module `Vue`), extractable to npm/the registry
later — self-contained, with `vue` as a peer dependency and its FFI
written in TypeScript: `src/Vue.ts` is the source of truth, and the
package's `tsc` build (run by `purs:build` before spago) emits the
`Vue.js` companion purs requires plus `Vue.d.ts` for TypeScript
consumers — both generated and gitignored. The API mirrors Vue's names: type `Ref`, functions `ref`,
`shallowRef`, `computed`, `onMounted`/`onBeforeUnmount`/`onUnmounted`,
`watchRef`/`watchGetter`, plus a `Readable` class giving one `read` for
refs and computeds while `write` stays `Ref`-only, so computed
immutability is enforced by types. Effects are thunks executed
synchronously, so PureScript composables satisfy Vue's setup-context
rules.

Renamed-module hygiene: spago leaves dead module dirs in `output/`; the
declaration generator skips any whose source file no longer exists (a
stale `App.Vue` once shimmed Vue's own `computed` out of the auto-import
pool).

## SFC components

`<script setup>` blocks cannot *be* PureScript — the SFC compiler derives
template bindings from that block and `defineProps`/`defineEmits` are
compiler macros — but everything inside them can leave. The pattern is a
**PureScript setup composable**: `ProjectShelf.purs` owns the hover state
machine, tooltip anchoring with edge-overflow shift, center-on-select
scrolling, and lifecycle; `ProjectShelf.vue`'s script is the two macros,
two template refs, and one `useProjectShelf({...})` call.

Two portability rules learned the hard way:

- **SSR runs setup on the server** — FFI touching `window` must guard
  (`typeof window === "undefined"`); the original code got this for free
  from VueUse.
- **Case-insensitive filesystems + extension probing** — an FFI stub
  `Scroll.js` shadows a shim `scroll.ts` when a bundler probes `.js`
  first. `vite.resolve.extensions` puts `.ts` first in nuxt.config.

## Converted — everything

- **Utils** (all seven): Format, Coder, Spines, Scroll, Katex,
  MarkdownMath, Metrics
- **Composables** (all): AfterPaint, CaptionTypewriter, ScrollReveal,
  SideNoteLayout, FigureSpotlight, ProjectReferences, ColorToggle,
  ScrollEdges, Profile, DraggableBubble, ReaderPeeks, the interest-map
  polar layout, and the metrics network stack (ApiRoute, Socket,
  ViewerGeo, ViewerLocation)
- **Stores** (all five): map-reveal, side-notes, connections, cues,
  metrics — cores in `app/stores/<name>/<Name>.purs`, shells are one-line
  `defineStore(id, use<Name>Core)` calls in each `index.ts`
- **Plugin/middleware**: metrics tracking wiring, `wipe.global` decision
  core
- **Server**: sitemap XML serialization (byte-identical to the `sitemap`
  npm package it replaced) and the tikz cache-response cores
- **Components** (every SFC with script logic, ~30): the setup-composable
  pattern from ProjectShelf, up through InterestMap's d3-spring
  orchestration, the reader page, `/code`, all eight canvas visualizers
  (solvers in PS via mutable-cell FFI primitives; the smoke grid kernel
  and particle-hash step documented as typed FFI kernels for frame rate),
  and the build-time satori OG shelf

What remains TypeScript, by design: compiler macros (`defineProps`/
`defineEmits`), content-query/`useAsyncData` glue, template refs, the
three hand-adapter shims, typed FFI implementations, and nitro/plugin
file shells that the framework must scan.

Verification: 858-case golden diff, `nuxi typecheck` at zero errors,
frame-level jsdom parity harnesses for the visualizers (seeded RNG,
manual rAF pump — e.g. the mass-spring integrator blow-up lands on the
same frame in both implementations), byte-parity on server routes, and
live browser checks. Note for headless verification: `useAfterPaint`
work waits on `requestAnimationFrame`, which never fires in a hidden
tab — sims look frozen in background panes for the original and the
port alike.

## Formatting

`purs-tidy` formats all PureScript (`.tidyrc.json`: 2-space indent,
arrow-first signatures, ide-sorted imports auto-wrapped at 100 columns —
long lines are style errors here). `bun run purs:format` rewrites in
place, `bun run purs:format-check` verifies; the VS Code LSP uses the same
config as its formatter.

## Ecosystem note

There is no maintained PureScript-Vue interface layer to adopt: the
registry has no Vue packages; ruicc/purescript-vue is Vue-1-era;
klarkc/pure-vue (closest in spirit — Effect-wrapped composition API) is
experimental, unpublished, and owns its own Vite pipeline. `App.Vue` is
deliberately small and could be extracted as a package later.

## VS Code IntelliSense

`.vscode/extensions.json` recommends `oxfordabstracts.purescript-fast-ide-vscode`
(the compiler's built-in `purs lsp`; needs `purs` on PATH — installed
globally via `bun add -g purescript`) plus `nwolverson.language-purescript`
for syntax. Settings point the server at `app/**/*.purs`, `output/`, and
`purs-tidy` (dev dependency) as formatter.

## Workflow

```sh
bun run purs:build   # spago build + regenerate d.ts and .purs-shims (runs before dev/build)
bun run purs:check   # 858-case golden diff against recorded behavior
```

Editing `.purs` files during `nuxi dev` requires re-running `purs:build`
(or keep `spago build --watch` in a second terminal). Note `purs` caches by
content hash: after renaming an FFI implementation file, the companion `.js`
must actually change (it does, since the path is in it) for the compiled
`foreign.js` to be recopied.

`purs:build` builds through `scripts/spago-build.mjs`, which runs
`spago build --pure`. The lockfile pins package resolution (after changing
dependencies in a `spago.yaml`, run `bunx spago install` once to refresh
`spago.lock`), but `--pure` does not prevent spago from cloning the two
purescript registry repos whenever its global cache is cold — and a CI
home directory always is, costing about a minute per build. On CI
(`VERCEL`/`CI`) the wrapper therefore points `XDG_CACHE_HOME` into
`node_modules/.cache`, which Vercel persists across deployments: the
clone happens once and warm builds skip it. (Local caches are untouched —
macOS spago caches under `~/Library/Caches/spago-nodejs` and ignores XDG.)

Two consumers resolve `#purs` differently in production: vite reads the
package `imports` field, but nitro's rollup does not — every
`App.Server.*` module a nitro route imports needs a matching entry in
`nitro.alias` (nuxt.config) pointing at its compiled `output/.../index.js`,
which inlines it into the server bundle. Without the entry, prerender and
the deployed function fail with "Package import specifier #purs/… is not
defined".
