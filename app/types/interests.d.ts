/**
 * Shapes shared by the interest map, its layout composable,
 * and the bio-connections overlay.
 */

interface InterestLeaf {
  label: string
  /** Labels of prerequisite nodes, linked as extra ancestors. */
  requires?: string[]
}

interface InterestGrandchild {
  label: string
  /** Labels of prerequisite nodes, linked as extra ancestors. */
  requires?: string[]
  children?: InterestLeaf[]
}

interface InterestChild {
  label: string
  /** Labels of prerequisite nodes, linked as extra ancestors. */
  requires?: string[]
  children?: InterestGrandchild[]
}

interface InterestBranch {
  label: string
  color: string
  children: InterestChild[]
}

interface MapNode {
  id: string
  label: string
  level: 1 | 2 | 3 | 4
  branch: string
  color: string
  x: number
  y: number
  /** Inner-band children label below their dot to dodge outer-band labels. */
  labelSide?: "above" | "below"
}

interface MapLink {
  id: string
  /** Parent node id, or null when the link grows from the root. */
  source: string | null
  target: string
  /** Extra prerequisite edge, drawn dashed; not part of the tree. */
  prereq?: boolean
  branch: string
  color: string
  x1: number
  y1: number
  x2: number
  y2: number
}

interface MapLayout {
  width: number
  height: number
  cx: number
  cy: number
  rings: number[]
  nodes: MapNode[]
  links: MapLink[]
}

interface ConnectionAnchor {
  x: number
  y: number
}
