/**
 * Minimal typing for opentype.js (the package ships no declarations):
 * just the surface `tikz/svg.ts` touches for text outlining.
 */
declare module "opentype.js" {
  namespace opentype {
    interface Font {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      [key: string]: any
    }
    function parse(buffer: ArrayBuffer): Font
  }
  export default opentype
}
