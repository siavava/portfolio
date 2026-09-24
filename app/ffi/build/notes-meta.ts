/**
 * Typed FFI implementation for `App.Build.NotesMeta` — the WHATWG URL
 * parsing PureScript reaches through `foreign import`. The generated
 * companion `app/build/NotesMeta.js` re-exports from here. Deliberately
 * uncaught: an unparsable URL still crashes the build script.
 */

export const urlPathnameImpl = (url: string): string => new URL(url).pathname
