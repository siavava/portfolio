/**
 * ## useCues
 *
 * Powers the bio cue threads linking root words to their marks. The core
 * lives in `Cues.purs`.
 */
export const useCues = defineStore("cues", useCuesCore)
