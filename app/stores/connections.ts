/**
 * ## useConnections
 *
 * Links the bio copy to the interest map: bio targets announce one or
 * more node names on hover, map nodes register themselves, and the map
 * lights the lineage from the root to each named node.
 *
 * ### Returns
 *
 * | Member | Type | Description |
 * | --- | --- | --- |
 * | `nodes` | `Set<string>` | Registered map node names |
 * | `activeNames` | `string[]` | Names lit by the active hover |
 * | `registerNode` | `function` | Register a map node |
 * | `unregisterNode` | `function` | Drop a map node |
 * | `activate` | `function` | Light up the named nodes |
 * | `deactivate` | `function` | Clear the highlight |
 */
export const useConnections = defineStore("connections", () => {
  const nodes = shallowReactive(new Set<string>())
  const activeNames = shallowRef<string[]>([])

  const registerNode = (label: string) => {
    nodes.add(label)
  }

  const unregisterNode = (label: string) => {
    nodes.delete(label)
  }

  const activate = (names: string[]) => {
    const known = names.filter(name => nodes.has(name))
    if (known.length) {
      activeNames.value = known
    }
  }

  const deactivate = () => {
    activeNames.value = []
  }

  return {
    nodes,
    activeNames,
    registerNode,
    unregisterNode,
    activate,
    deactivate,
  }
})
