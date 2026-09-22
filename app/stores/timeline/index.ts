/**
 * ## useTimelineStore
 *
 * Threads the timeline through the page: the morph origin the name bar
 * hands the panel, the landing the panel reports back, and the year a bio
 * target is previewing. The core lives in `Timeline.purs`.
 */
export const useTimelineStore = defineStore("timeline", useTimelineStoreCore)
