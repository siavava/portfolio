/**
 * Typed FFI implementations for `App.Stores.Cues` — the shallow-reactive
 * `Map` primitive the cue store keys by element, plus element identity.
 * Reads made through these ops inside a `computed`'s effect track the
 * map's reactivity exactly like direct property access would.
 */
import { shallowReactive } from "vue"

export const newReactiveMapImpl = <K, V>(): Map<K, V> => shallowReactive(new Map<K, V>())
export const mapSetImpl = <K, V>(map: Map<K, V>, key: K, value: V): void => { map.set(key, value) }
export const mapDeleteImpl = <K, V>(map: Map<K, V>, key: K): void => { map.delete(key) }
export const mapHasImpl = <K, V>(map: Map<K, V>, key: K): boolean => map.has(key)
export const mapClearImpl = <K, V>(map: Map<K, V>): void => { map.clear() }
export const mapEntriesImpl = <K, V>(map: Map<K, V>): { key: K, value: V }[] =>
  [...map].map(([key, value]) => ({ key, value }))

export const sameElementImpl = (a: Element, b: Element): boolean => a === b
