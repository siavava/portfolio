/**
 * FFI source for the `Vue` PureScript module. `tsc` emits the sibling
 * `Vue.js` that `purs` requires (and copies verbatim into each consumer's
 * output — hence only bare imports here) plus `Vue.d.ts` for TypeScript
 * consumers.
 *
 * Vue's composition API is context-bound: everything here must run
 * synchronously inside a component's `setup()` body, which holds for
 * Effect thunks invoked from one.
 */
import type { ComputedRef, Ref } from "vue"
import { computed, onBeforeUnmount, onMounted, onUnmounted, ref, shallowReactive, shallowRef, watch } from "vue"

export type { ComputedRef, Ref } from "vue"

/** The runtime representation of the PureScript `ReactiveSet` type. */
export type ReactiveSet<T> = Set<T>

export const refImpl = <T>(value: T): Ref<T> => ref(value) as Ref<T>
export const shallowRefImpl = <T>(value: T): Ref<T> => shallowRef(value) as Ref<T>

export const reactiveSetImpl = <T>(): ReactiveSet<T> => shallowReactive(new Set<T>())
export const setAddImpl = <T>(set: ReactiveSet<T>, value: T): void => { set.add(value) }
export const setDeleteImpl = <T>(set: ReactiveSet<T>, value: T): void => { set.delete(value) }
export const setHasImpl = <T>(set: ReactiveSet<T>, value: T): boolean => set.has(value)
export const setClearImpl = <T>(set: ReactiveSet<T>): void => { set.clear() }

export const readRefImpl = <T>(r: Ref<T>): T => r.value
export const writeRefImpl = <T>(r: Ref<T>, value: T): void => { r.value = value }

export const computedImpl = <T>(compute: () => T): ComputedRef<T> => computed(compute)
export const readComputedImpl = <T>(c: ComputedRef<T>): T => c.value

export const watchRefImpl = <T>(source: Ref<T>, callback: (value: T) => void): () => void =>
  watch(source, value => callback(value))

export const onMountedImpl = (fn: () => void): void => { onMounted(fn) }
export const onBeforeUnmountImpl = (fn: () => void): void => { onBeforeUnmount(fn) }
export const onUnmountedImpl = (fn: () => void): void => { onUnmounted(fn) }

export const watchGetterImpl = <T>(get: () => T, callback: (value: T, previous: T) => void): () => void =>
  watch(get, (value, previous) => callback(value, previous as T))

export const requestFrameImpl = (fn: () => void): number => requestAnimationFrame(fn)
export const cancelFrameImpl = (handle: number): void => { cancelAnimationFrame(handle) }
