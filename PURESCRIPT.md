# PureScript in the portfolio

This branch (`pure`) drafts the TypeScript → PureScript conversion. Two real
modules are ported and live in production paths: `app/utils/Format.purs` and
`app/utils/Coder.purs` (the `/code` transcoding engine), verified against the
original TypeScript with an 800-case golden diff.

## Can PureScript interface with TypeScript + Vue APIs?

Yes, in both directions.

- **PS → TS**: the compiler emits plain ES modules under `output/`. Bundlers
  resolve `#purs/<Module>` there via the package `imports` field; TypeScript
  resolves the same specifier to generated declarations via tsconfig `paths`.
  Design the exported boundary JS-friendly (uncurried record-arg entry points
  like `transcodeJs`) and the TS side needs no knowledge of PureScript
  conventions.
- **TS/JS → PS**: `foreign import` plus a sibling FFI file with the module's
  basename (`Coder.js` beside `Coder.purs`). That is how the port reaches
  `TextEncoder`/`TextDecoder` and base64. Vue APIs are reachable the same way
  (`ref`/`computed`/`watch` wrapped in `Effect`), it just isn't exercised in
  this draft.

## SFC and single-file support

- **Single-file modules** (utils, store/composable cores): fully convertible.
  The `.purs` file sits next to a thin `.ts` shim that keeps the original
  export names, so Nuxt auto-imports and every call site stay unchanged.
- **SFCs**: there is no `<script lang="purescript">` — Vite, Volar, and Nuxt's
  codegen are TS-bound, so `<script setup>` stays TypeScript and imports the
  PureScript modules. Templates, reactivity plumbing, and Nuxt config remain
  TS; logic moves to PureScript.

## Layout — no separate project directory

The Nuxt structure is preserved: PureScript sources live in `app/` beside the
code they power. The new spago hardcodes `src/`, so `src` is a symlink → `app`.
Nuxt is told to ignore `.purs` files and FFI companions in auto-import scans
(`ignore` in `nuxt.config.ts`) — otherwise FFI exports leak into auto-imports
and the `Coder.js` / `coder.ts` basenames collide on case-insensitive macOS.

## Are the shims hand-written?

Only the API-reshaping ones (`coder.ts` maps a flat result record back to the
original discriminated union). The **type declarations are generated**:
`scripts/purs-dts.mjs` reads the typed AST spago emits per module
(`output/<Module>/docs.json`) and writes `app/types/purs/<Module>.d.ts` as
part of `bun run purs:build`. A module whose boundary already matches its
desired TS API needs no shim at all — auto-imports could point straight at
`output/` via unimport entries.

## VS Code IntelliSense

`.vscode/extensions.json` recommends `nwolverson.ide-purescript` (language
server: completion, hover types, go-to-definition, rebuild-on-save) and
`nwolverson.language-purescript` (syntax). `.vscode/settings.json` points the
IDE at spago sources, `output/`, and the `purs-tidy` formatter (a dev
dependency, so `addNpmPath` finds it). Install the two extensions and open the
repo — the server indexes on first `.purs` open.

## Workflow

```sh
bun run purs:build   # spago build + regenerate .d.ts (runs before dev/build)
bun run purs:check   # 800-case golden diff against the recorded TS behavior
```

Editing `.purs` files during `nuxi dev` requires re-running `purs:build`
(or keep `spago build --watch` in a second terminal); Vite hot-reloads the
recompiled output automatically.
