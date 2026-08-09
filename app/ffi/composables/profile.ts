/**
 * Typed FFI implementations for `App.Composables.Profile` — the Nuxt
 * Content query and async-data wiring behind the profile singleton.
 */
import { queryCollection, useAsyncData } from "#imports"

const query = () => queryCollection("profile").first()

export const useProfileImpl = () => useAsyncData("profile", query)

/** The exact boundary type; referenced by the generated declarations. */
export type ProfileAsync = ReturnType<typeof useProfileImpl>
