/**
 * ## coder
 *
 * Re-exports the PureScript conversion engine (`Coder.purs`) behind
 * `/code` into the auto-import pool. `codeFormats` goes out as
 * `CODE_FORMATS`, the name the `/code` template iterates; the transcoder
 * itself (`transcodeJs`) is consumed by `CodePage.purs` directly.
 */
export { codeFormats as CODE_FORMATS, decodeShareText, encodeShareText } from "#purs/App.Utils.Coder"
