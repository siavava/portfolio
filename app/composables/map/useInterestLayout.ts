const BASE_WIDTH = 936
const BASE_HEIGHT = 792
const RING_RADII = [117, 234, 351, 468]

const BRANCH_RADII = [168, 150, 205, 130, 100, 175, 190, 162]

const MIN_ANGLE = 6
const MAX_ANGLE = 174

const SLICE_GUTTER = 3.5

const BAND_BASES = [258, 314, 364]
const BAND_STEPS = [28, 26, 22]
const OUTER_CAP = 408

const EDGE_BIAS = 0.12

const toRadians = (degrees: number) => degrees * Math.PI / 180

const childRadius = (
  band: number,
  bandIndex: number,
  branchIndex: number,
) => {
  const radius = BAND_BASES[band]! + bandIndex * BAND_STEPS[band]! + branchIndex * 5 % 9
  return band === 2 ? Math.min(radius, OUTER_CAP) : radius
}

/** ## useInterestLayout — polar layout for the interest map on a 928×792 canvas. */
export const useInterestLayout = (
  branches: InterestBranch[],
  scale = 1,
): MapLayout => {
  const nodes: MapNode[] = []
  const links: MapLink[] = []

  const cx = BASE_WIDTH * scale / 2
  const cy = 520 * scale

  const place = (radius: number, angle: number) => ({
    x: radius * scale * Math.cos(toRadians(angle)),
    y: -radius * scale * Math.sin(toRadians(angle)),
  })

  const sliceWidth = (MAX_ANGLE - MIN_ANGLE) / branches.length

  branches.forEach((branch, b) => {
    const sliceEnd = MAX_ANGLE - b * sliceWidth
    const sliceStart = sliceEnd - sliceWidth
    const center = sliceStart + sliceWidth / 2
    const angle = center + (center - 90) * EDGE_BIAS
    const radius = BRANCH_RADII[b % BRANCH_RADII.length]!
    const origin = place(radius, angle)

    nodes.push({
      id: branch.label,
      label: branch.label,
      level: 1,
      branch: branch.label,
      color: branch.color,
      labelSide: "below",
      ...origin,
    })
    links.push({
      id: `root:${branch.label}`,
      source: null,
      target: branch.label,
      branch: branch.label,
      color: branch.color,
      x1: 0,
      y1: 0,
      x2: origin.x,
      y2: origin.y,
    })

    const count = branch.children.length
    const fanStart = sliceStart + SLICE_GUTTER
    const fanWidth = sliceWidth - 2 * SLICE_GUTTER
    const step = count > 1 ? fanWidth / (count - 1) : 0
    const bandCounts = [0, 0, 0]

    branch.children.forEach((child, c) => {
      const childAngle = count > 1 ? fanStart + c * step : angle
      const band = c % 3
      const childR = childRadius(band, bandCounts[band]!++, b)
      const point = place(childR, childAngle)

      nodes.push({
        id: child.label,
        label: child.label,
        level: 2,
        branch: branch.label,
        color: branch.color,
        ...point,
      })
      links.push({
        id: `${branch.label}:${child.label}`,
        source: branch.label,
        target: child.label,
        branch: branch.label,
        color: branch.color,
        x1: origin.x,
        y1: origin.y,
        x2: point.x,
        y2: point.y,
      })

      child.children?.forEach((grandchild, g) => {
        const drift = (childAngle >= angle ? 1 : -1) * (g + 1) * 3.5
        const leaf = place(childR + 84, childAngle + drift)

        nodes.push({
          id: grandchild.label,
          label: grandchild.label,
          level: 3,
          branch: branch.label,
          color: branch.color,
          ...leaf,
        })
        links.push({
          id: `${child.label}:${grandchild.label}`,
          source: child.label,
          target: grandchild.label,
          branch: branch.label,
          color: branch.color,
          x1: point.x,
          y1: point.y,
          x2: leaf.x,
          y2: leaf.y,
        })

        grandchild.children?.forEach((leafChild, l) => {
          const leafDrift = drift + (childAngle >= angle ? 1 : -1) * (l + 1) * 5
          const tip = place(childR + 132, childAngle + leafDrift)

          nodes.push({
            id: leafChild.label,
            label: leafChild.label,
            level: 4,
            branch: branch.label,
            color: branch.color,
            ...tip,
          })
          links.push({
            id: `${grandchild.label}:${leafChild.label}`,
            source: grandchild.label,
            target: leafChild.label,
            branch: branch.label,
            color: branch.color,
            x1: leaf.x,
            y1: leaf.y,
            x2: tip.x,
            y2: tip.y,
          })
        })
      })
    })
  })

  const positionOf = new Map(nodes.map(node => [node.id, node]))
  const addPrereqs = (node: { label: string, requires?: string[] }) => {
    for (const required of node.requires ?? []) {
      const from = positionOf.get(required)
      const to = positionOf.get(node.label)
      if (!from || !to) continue
      links.push({
        id: `req:${required}:${node.label}`,
        source: required,
        target: node.label,
        prereq: from.branch !== to.branch,
        branch: to.branch,
        color: to.color,
        x1: from.x,
        y1: from.y,
        x2: to.x,
        y2: to.y,
      })
    }
  }
  for (const branch of branches) {
    for (const child of branch.children) {
      addPrereqs(child)
      for (const grandchild of child.children ?? []) {
        addPrereqs(grandchild)
        grandchild.children?.forEach(addPrereqs)
      }
    }
  }

  return {
    width: BASE_WIDTH * scale,
    height: BASE_HEIGHT * scale,
    cx,
    cy,
    rings: RING_RADII.map(radius => radius * scale),
    nodes,
    links,
  }
}
