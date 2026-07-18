/** Stable pseudo-random hash for seeding spine geometry by title. */
export const hashLabel = (text: string) => {
  let hash = 0
  for (const char of text) hash = hash * 31 + char.charCodeAt(0) | 0
  return Math.abs(hash)
}

const spineWidth = (seed: number) => {
  const roll = seed % 20
  if (roll < 8) return 7 + seed % 3
  if (roll < 17) return 10 + (seed >> 3) % 5
  return 16 + (seed >> 5) % 6
}

/** Seeded spine geometry: width, height, lean, and edge arcs. */
export const spineStyle = (title: string) => {
  const seed = hashLabel(title)
  const tilted = seed % 13 === 0
  const lean = 4 + (seed >> 4) % 4
  const width = spineWidth(seed)
  const arc = Math.max(1.5, Math.round(width * 0.18 * 10) / 10)
  return {
    width: `${width}px`,
    height: `${50 + (seed >> 2) % 36}%`,
    marginLeft: `${(seed >> 6) % 2}px`,
    borderRadius: `50% / ${arc}px`,
    transform: tilted ? `rotate(${(seed >> 5) % 2 ? lean : -lean}deg)` : undefined,
  }
}
